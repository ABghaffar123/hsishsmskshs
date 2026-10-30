"""Status / file-serving routes."""
import os
import mimetypes
from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import FileResponse

from backend import config
from backend.services import progress_tracker
from backend.services.yt_dlp_service import debug_print
from backend.dependencies import require_api_key

router = APIRouter(prefix="/api", tags=["status"])



def _ok(data: dict) -> dict:
    return {"success": True, "data": data}


# Canonical job states — anything else is treated as "no valid output".
_TERMINAL = {"completed", "failed", "cancelled"}


def _is_within_download_dir(path: str) -> bool:
    """Path-aware containment check.

    Uses ``os.path.commonpath`` which correctly handles sibling-prefix cases
    (e.g. ``/downloads/job123`` vs ``/downloads/job1234``) that a naive
    ``startswith`` string check would miss.  Resolves symlinks via
    ``os.path.realpath`` so symlink-escape attacks are caught at the final
    target level.
    """
    real_download_dir = os.path.realpath(str(config.DOWNLOAD_DIR))
    real_path = os.path.realpath(path)
    try:
        # commonpath raises ValueError if paths are on different drives
        # (Windows), which is exactly the "outside allowed roots" case.
        return os.path.commonpath([real_download_dir]) == os.path.commonpath(
            [real_download_dir, real_path]
        )
    except ValueError:
        return False


def _safe_mime(filename: str) -> str:
    """Return a safe MIME type for the served file based on extension.

    ``application/octet-stream`` is a valid fallback but does not prove
    media-type correctness.  We prefer video/audio types for known extensions.
    """
    ext = os.path.splitext(filename)[1].lower()
    _VIDEO_TYPES = {
        ".mp4": "video/mp4",
        ".mkv": "video/x-matroska",
        ".webm": "video/webm",
        ".m4v": "video/mp4",
        ".mov": "video/quicktime",
        ".avi": "video/x-msvideo",
        ".ts": "video/mp2t",
    }
    _AUDIO_TYPES = {
        ".mp3": "audio/mpeg",
        ".m4a": "audio/mp4",
        ".wav": "audio/wav",
        ".flac": "audio/flac",
        ".ogg": "audio/ogg",
        ".opus": "audio/ogg",
        ".aac": "audio/aac",
        ".wma": "audio/x-ms-wma",
    }
    if ext in _VIDEO_TYPES:
        return _VIDEO_TYPES[ext]
    if ext in _AUDIO_TYPES:
        return _AUDIO_TYPES[ext]
    # Fall back to mimetypes guess, then octet-stream as last resort
    guessed, _ = mimetypes.guess_type(filename)
    return guessed or "application/octet-stream"


def _find_job_file(job_id: str) -> str:
    """Locate the final output file for a job by its canonical ID.

    Looks for a file named ``{job_id}.<ext>`` directly in DOWNLOAD_DIR (no
    recursive ``os.walk`` scan of the entire downloads tree).  After yt-dlp
    post-processing the output is named ``{job_id}.mp4`` (or .mkv for
    video, .mp3 for audio), so an exact-prefix match with extension is safe
    and efficient — O(1) instead of O(n).
    """
    download_dir = str(config.DOWNLOAD_DIR)
    if not os.path.isdir(download_dir):
        return ""
    for f in os.listdir(download_dir):
        # Exact prefix match only: "job_id." prevents matching "job_id123"
        if f.startswith(job_id + ".") or f == job_id:
            candidate = os.path.join(download_dir, f)
            if _is_within_download_dir(candidate):
                try:
                    if os.path.isfile(candidate) and os.path.getsize(candidate) > 0:
                        return candidate
                except OSError:
                    continue
    return ""


@router.get("/file/{job_id}")
async def get_file(
    job_id: str,
    _user: dict = Depends(require_api_key),
):
    """Serve the completed download file for a job.

    Security: validates the file path is inside the configured DOWNLOAD_DIR
    using path-aware ``commonpath`` containment (not naive string prefix),
    rejects symlinks that escape the download root, and only serves the
    canonical ``{job_id}.<ext>`` file — no directory-wide scan.
    """
    job = progress_tracker.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")

    # Only serve files for terminal jobs that claim completion
    if job.get("status") not in _TERMINAL:
        raise HTTPException(status_code=404, detail="file not ready")

    # Try the stored file_path first (authoritative — set by the worker)
    path = job.get("file_path", "")
    if path:
        if _is_within_download_dir(path) and os.path.exists(path) and os.path.isfile(path):
            try:
                if os.path.getsize(path) > 0:
                    debug_print(f"FILE: serving tracked path {path} for job {job_id}")
                    return FileResponse(
                        path,
                        media_type=_safe_mime(path),
                        filename=os.path.basename(path),
                    )
            except OSError:
                pass  # fall through to scan

    # Fallback: locate the file by job_id in DOWNLOAD_DIR (O(1) prefix match)
    found = _find_job_file(job_id)
    if found:
        debug_print(f"FILE: served from job_id match {found} for job {job_id}")
        return FileResponse(
            found,
            media_type=_safe_mime(found),
            filename=os.path.basename(found),
        )

    raise HTTPException(status_code=404, detail="file not ready")