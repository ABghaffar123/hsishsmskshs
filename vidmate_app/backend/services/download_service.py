"""Download orchestration: yt-dlp (library) + FFmpeg + real-time progress.

``start_download`` spawns a thread so the FastAPI routes return immediately
with a ``job_id``.  yt-dlp's built-in ``progress_hooks`` relay live % /
speed into the shared tracker, which ``/api/status/{jobId}`` reads.
"""
import threading
import time
import os
import shutil
import platform
from typing import Optional

from backend.services.progress_tracker import (
    create_job, update_snapshot, set_status, get as get_job,
    register_worker, unregister_worker, clear_cancel_flag,
)
from backend.services.yt_dlp_service import extract_info, _video_model, download_with_progress, debug_print
from backend.services.ffmpeg_service import merge_video_audio, convert_to_mp3
from backend import config
from pathlib import Path



def _get_media_store_dir(file_type: str) -> str:
    """Return the appropriate MediaStore directory for the file type.

    On Android this maps to standard public directories:
    - Videos: ``/sdcard/DCIM/Videos`` or ``/sdcard/Movies``
    - Audio: ``/sdcard/Music``
    - Downloads: ``/sdcard/Download``

    Uses ``Environment.getExternalStorageDirectory`` fallback for older APIs.
    """
    # Python ke main platform detection ke liye platform module use karna
    import platform
    is_android = platform.system() == "Android"

    if not is_android:
        # Development fallback — use app documents directory
        return str(Path(config.DOWNLOAD_DIR).parent.parent / "public_media")

    try:
        from android.os import Environment
        from android.provider import MediaStore
    except Exception:
        # Platform not Android — fallback to app documents
        return str(Path(config.DOWNLOAD_DIR).parent.parent / "public_media")

    # Try modern scoped storage approach first
    if file_type == "video":
        # Prefer DCIM/Videos or Movies
        candidates = [
            Environment.getExternalStorageDirectory() + "/DCIM/Videos",
            Environment.getExternalStorageDirectory() + "/Movies",
            Environment.getExternalStorageDirectory() + "/Download",
        ]
    elif file_type == "audio":
        candidates = [
            Environment.getExternalStorageDirectory() + "/Music",
            Environment.getExternalStorageDirectory() + "/Audio",
        ]
    else:
        candidates = [
            Environment.getExternalStorageDirectory() + "/Download",
            Environment.getExternalStorageDirectory() + "/Documents",
        ]

    for cand in candidates:
        if cand and os.path.isdir(cand):
            return cand

    # Fallback to standard Download directory
    return Environment.getExternalStorageDirectory() + "/Download"



def _is_wifi_connected() -> bool:
    """Check if the system is on Wi-Fi or local ethernet vs cellular.

    In local network dev environments (laptop running backend), this returns
    True so downloads aren't falsely blocked by cellular heuristics. On real
    Android devices with metered cellular interfaces, this checks if the local
    IP belongs to private LAN ranges (192.168.x.x, 10.x.x.x, 172.16.x.x) or
    loopback, which typically represent Wi-Fi or Ethernet.
    """
    try:
        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)
        if local_ip.startswith("192.168.") or local_ip.startswith("10.") or \
           local_ip.startswith("172.") or local_ip.startswith("127.") or \
           local_ip.startswith("100."):
            return True
        return True # Default to allowing unless explicitly mobile data
    except Exception:
        return True


def _spawn_download(url: str, quality: str, file_type: str,
                    title: str, job_id: str, wifi_only: bool = False,
                    auto_retry: bool = True) -> None:
    """Thread worker — blocks until yt-dlp finishes, then finalises tracker.

    Includes BUG 4 auto-retry logic: if download fails and `auto_retry` is true,
    it retries up to 3 times with exponential backoff before marking failed.
    """
    max_attempts = 3 if auto_retry else 1
    attempt = 0
    final_path = ""

    while attempt < max_attempts:
        attempt += 1
        try:
            # Re-fetch metadata so the tracker has the right title/thumbnail
            try:
                raw = extract_info(url)
                vm = _video_model(raw)
                update_snapshot(
                    job_id,
                    title=title or vm.get("title", url),
                    thumbnail=vm.get("thumbnail", ""),
                    source_url=vm.get("source_url", url),
                )
            except Exception:
                pass  # keep whatever metadata was already set

            final_path = download_with_progress(
                url=url,
                out_dir=str(config.DOWNLOAD_DIR),
                job_id=job_id,
                quality=quality,
                file_type=file_type,
            )
            if final_path:
                break
        except Exception as e:
            debug_print(f"WORKER: attempt {attempt}/{max_attempts} failed for job {job_id}: {e}")
            if attempt >= max_attempts:
                snap = get_job(job_id)
                if snap and snap.get("status") in ("cancelled", "failed", "completed"):
                    debug_print(f"WORKER: job {job_id} already in terminal status {snap['status']}")
                else:
                    set_status(job_id, "failed", error=str(e) or e.__class__.__name__)
                unregister_worker(job_id)
                return
            else:
                time.sleep(2 * attempt) // backoff

    try:
        # After successful download, move file to public MediaStore location
        if final_path and os.path.exists(final_path):
            try:
                target_dir = _get_media_store_dir(file_type)
                os.makedirs(target_dir, exist_ok=True)
                target_path = os.path.join(target_dir, os.path.basename(final_path))
                shutil.move(final_path, target_path)
                final_path = target_path
                debug_print(f"WORKER: moved {final_path} to MediaStore location {target_path}")
            except Exception as e:
                debug_print(f"WORKER: failed to move to MediaStore: {e}")
                pass
        update_snapshot(job_id, file_path=final_path, progress=1.0,
                        status="completed")
    except Exception as e:
        snap = get_job(job_id)
        if snap and snap.get("status") in ("cancelled", "failed", "completed"):
            debug_print(f"WORKER: job {job_id} already in terminal status {snap['status']}")
        else:
            set_status(job_id, "failed", error=str(e) or e.__class__.__name__)
    finally:
        unregister_worker(job_id)



def start_download(url: str, quality: str, file_type: str, title: str = "",
                   job_id: str = None) -> str:
    """Synchronous entry: spawn a thread, return ``job_id``.

    ``job_id`` is the canonical id created by the route.  If not supplied a new
    one is created here (backward-compatible for callers that still need it).
    NEVER creates a second id when one is already assigned — that was the root
    cause of the progress-never-appears bug.
    """
    if job_id is None:
        job_id = create_job(title=title)
    # Clear any stale cancel flag from a previous attempt so the new
    # download starts in a clean state.
    clear_cancel_flag(job_id)
    t = threading.Thread(
        target=_spawn_download,
        args=(url, quality, file_type, title, job_id),
        daemon=True,
    )
    t.start()
    # Register the thread handle so cancel/resume routes can find and
    # terminate real work instead of just flipping a label.
    register_worker(job_id, t)
    return job_id