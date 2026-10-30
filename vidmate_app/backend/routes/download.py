"""Download routes: start / pause / resume / cancel / retry + job listing."""
from fastapi import APIRouter, HTTPException, Depends

import time
from backend.services import yt_dlp_service
from backend.services import download_service
from backend.services import progress_tracker
from backend.services.yt_dlp_service import debug_print
from backend.dependencies import require_api_key

router = APIRouter(prefix="/api", tags=["download"])


def _ok(data: dict) -> dict:
    return {"success": True, "data": data}
def _err(status_code: int, detail: str) -> dict:
    return {"success": False, "status_code": status_code, "detail": detail}


@router.post("/download")
async def start_download(
    payload: dict,
    _user: dict = Depends(require_api_key),
):
    url: str = payload.get("url", "")
    quality: str = payload.get("quality", "best")
    file_type: str = payload.get("file_type", "video")
    title: str = payload.get("title", "")
    wifi_only: bool = payload.get("wifi_only", False)
    auto_retry: bool = payload.get("auto_retry", True)

    # Validate required fields
    if not url:
        return _err(400, "Missing required field: url")

    # Pre-fetch the real source URL so the Flutter client can display it.
    vm = {}
    try:
        raw = yt_dlp_service.extract_info(url)
        vm = yt_dlp_service.to_video_model(raw) or {}
        source_url = vm.get("source_url", url)
        title = title or vm.get("title", url)
        qualities = vm.get("qualities", ["best"])
    except Exception as e:
        source_url = url
        qualities = ["best"]
        debug_print(f"DOWNLOAD: extract_info failed for {url}: {e}")

    # Honour user-selected quality; fall back to best if not available among
    # the formats yt-dlp reported for this video.
    selected_quality = quality if quality in qualities else "best"

    # Prevent duplicate jobs: if a non-terminal job exists for this URL, reuse it
    existing_job_id = None
    for jid, job in progress_tracker._jobs.items():
        if job.get("source_url") == source_url and job.get("status") not in (
            "completed", "failed", "cancelled"
        ):
            existing_job_id = jid
            break
    if existing_job_id:
        debug_print(f"DOWNLOAD: reusing existing job {existing_job_id} for {source_url}")
        # Update the job with the latest quality/file_type from the new request
        progress_tracker.update_snapshot(
            existing_job_id,
            quality=selected_quality,
            file_type=file_type,
        )
        job = progress_tracker.get(existing_job_id) or {}
        return _ok(job)

    job_id = progress_tracker.create_job(title=title)
    progress_tracker.update_snapshot(
        job_id,
        title=title,
        thumbnail=vm.get("thumbnail", ""),
        source_url=source_url,
        quality=selected_quality,
        file_type=file_type,
        size=0.0,
    )

    # Launch the async download — download_service.start_download spawns the
    # worker thread internally and registers it in _active_workers so cancel
    # can find and terminate it.  Pass the SAME canonical job_id so all
    # progress/completion updates land on the record the client polls.
    # Wi-Fi Only enforcement — BUG 3 fix: reject downloads over mobile data
    # when the client flags wifi_only=true.  We check the server-side network
    # interface type so users on metered connections are protected even if the
    # phone's reported connection type differs.
    if wifi_only and not download_service._is_wifi_connected():
        progress_tracker.set_status(job_id, "failed",
            error="Download blocked: Wi-Fi Only is enabled and the server is not on a Wi-Fi network.")
        debug_print(f"DOWNLOAD: wifi_only=true and server is on mobile/other network — rejecting job {job_id}")
        raise HTTPException(
            status_code=422,
            detail="Wi-Fi Only is enabled. Connect to Wi-Fi before downloading.",
        )

    download_service.start_download(
        source_url, selected_quality, file_type, title, job_id,
        wifi_only=wifi_only,
        auto_retry=auto_retry,
    )

    job = progress_tracker.get(job_id) or {}
    return _ok(job)


@router.get("/downloads")
async def list_downloads(
    _user: dict = Depends(require_api_key),
):
    """Return all download jobs — fixes the DownloadsScreen bug where it
    called /api/discover/trending instead."""
    jobs = progress_tracker.list_jobs()
    return _ok(jobs)


@router.get("/status/{job_id}")
async def download_status(
    job_id: str,
    _user: dict = Depends(require_api_key),
):
    job = progress_tracker.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    return _ok(job)


@router.post("/pause/{job_id}")
async def pause_download(
    job_id: str,
    _user: dict = Depends(require_api_key),
):
    """Pause a running download.

    The yt-dlp **library** (in-process Python) does not support suspending a
    transfer mid-flight and resuming it later.  We therefore implement pause
    as *stop-and-resume*: request cooperative cancellation (the progress hook
    aborts yt-dlp), mark the job ``paused``.  ``/resume`` restarts the worker
    via ``download_service.start_download`` which clears the cancel flag and
    re-launches the download.
    """
    job = progress_tracker.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    # Signal the worker to stop via the cooperative cancellation flag.
    progress_tracker.request_cancel(job_id)
    progress_tracker.set_status(job_id, "paused")
    debug_print(f"DOWNLOAD: pause requested for job {job_id} (cooperative stop + restart on resume)")
    return _ok({"message": "pause requested (stop-and-resume on /resume)", "job": progress_tracker.get(job_id) or {}})


@router.post("/resume/{job_id}")
async def resume_download(
    job_id: str,
    _user: dict = Depends(require_api_key),
):
    job = progress_tracker.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    # Prevent duplicate workers: only resume if no worker is currently active
    # for this job (the old thread may still be winding down).
    existing = progress_tracker.worker_thread(job_id)
    if existing and existing.is_alive():
        debug_print(f"DOWNLOAD: resume for job {job_id} but worker still alive — ignoring")
        return _ok({"message": "already running", "job": progress_tracker.get(job_id) or {}})

    # download_service.start_download clears cancel flag + spawns+registers
    # a fresh worker thread.
    download_service.start_download(
        job["source_url"], job["quality"], job["file_type"], job["title"], job_id,
    )
    progress_tracker.set_status(job_id, "downloading")
    return _ok(progress_tracker.get(job_id) or {})


@router.post("/cancel/{job_id}")
async def cancel_download(
    job_id: str,
    _user: dict = Depends(require_api_key),
):
    """Cancel a running download.

    Sets the ``cancel_requested`` flag; the yt-dlp progress hook checks this
    on every progress callback and raises an exception to abort the library
    call immediately.  The worker's ``finally`` block then marks the job
    terminal.  Status is set to ``cancelled`` so UI reflects the final state.
    """
    job = progress_tracker.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    # Set flag — the worker thread's progress hook will abort yt-dlp.
    progress_tracker.request_cancel(job_id)
    # Mark terminal immediately so the client sees a stable state.
    progress_tracker.set_status(job_id, "cancelled")
    debug_print(f"DOWNLOAD: cancel requested for job {job_id} (flag set, worker will abort)")
    return _ok({"message": "cancel requested — worker will abort", "job": progress_tracker.get(job_id) or {}})


@router.post("/retry/{job_id}")
async def retry_download(
    job_id: str,
    _user: dict = Depends(require_api_key),
):
    job = progress_tracker.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    # FIX: Reuse original job ID to maintain canonical identifier
    # Update snapshot with fresh retry state
    progress_tracker.update_snapshot(
        job_id,
        status="downloading",
        progress=0.0,
        speed=0.0,
        file_path="",
        error="",
        dates={
            "created": job["dates"].get("created", time.time()),
            "started": time.time(),
            "finished": None,
        },
    )
    # download_service.start_download clears cancel flag + spawns worker
    download_service.start_download(
        job["source_url"], job["quality"], job["file_type"], job["title"], job_id,
    )
    return _ok(progress_tracker.get(job_id) or {})
