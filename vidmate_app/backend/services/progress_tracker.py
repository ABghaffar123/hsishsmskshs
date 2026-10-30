"""In-memory download-job tracker with real-time progress.

Each download job lives in a single module-level dict keyed by ``job_id``.
The ``yt_dlp_service`` updates a job's snapshot every time yt-dlp emits a
``progress-2`` line.  ``progress_tracker.get(job_id)`` therefore always
reflects the latest values seen by the backend.
"""
import threading
import time
import uuid
from typing import Optional

_lock = threading.Lock()
_jobs: dict[str, dict] = {}
_active_workers: dict[str, threading.Thread] = {}  # job_id -> running thread


def _now() -> float:
    return time.time()


def create_job(title: str = "") -> str:
    """Create a new download job and return its id."""
    job_id = str(uuid.uuid4())
    with _lock:
        _jobs[job_id] = {
            "job_id": job_id,
            "title": title,
            "thumbnail": "",
            "source_url": "",
            "quality": "",
            "file_type": "video",
            "size": 0.0,            # MB
            "status": "pending",    # pending|downloading|paused|completed|failed
            "progress": 0.0,        # 0..1
            "speed": 0.0,           # MB/s
            "eta": "",              # human e.g. "2m 5s"
            "file_path": "",
            "cancel_requested": False,   # cooperative cancel flag
            "dates": {"created": _now(), "started": None, "finished": None},
            "error": "",
        }
    return job_id


def register_worker(job_id: str, thread: threading.Thread) -> None:
    """Register the running worker thread for a job so cancel can signal it.

    The tracker already kept an ``_active_workers`` dict but never populated
    it; this makes cancel/resum routes able to find and terminate real work.
    """
    with _lock:
        _active_workers[job_id] = thread


def unregister_worker(job_id: str) -> None:
    """Remove the worker thread reference when a job finishes."""
    with _lock:
        _active_workers.pop(job_id, None)


def request_cancel(job_id: str) -> bool:
    """Set the ``cancel_requested`` flag for a job.

    Returns True if the job exists, False otherwise.  The worker thread must
    poll this flag in its progress hook and abort — see ``is_cancel_requested``.
    """
    with _lock:
        job = _jobs.get(job_id)
        if job is None:
            return False
        job["cancel_requested"] = True
        return True


def is_cancel_requested(job_id: str) -> bool:
    """Check if cancellation was requested (worker polls this in progress hooks)."""
    with _lock:
        job = _jobs.get(job_id)
        if job is None:
            return False
        return bool(job.get("cancel_requested", False))


def clear_cancel_flag(job_id: str) -> None:
    """Reset ``cancel_requested`` so a fresh retry/start begins clean."""
    with _lock:
        job = _jobs.get(job_id)
        if job is not None:
            job["cancel_requested"] = False


def worker_thread(job_id: str) -> threading.Thread | None:
    """Return the currently running worker thread for a job, or None."""
    with _lock:
        return _active_workers.get(job_id)


def update_snapshot(job_id: str, **fields) -> Optional[dict]:
    """Atomically merge ``fields`` into the stored job snapshot.

    Only keys already present on the job dict are allowed, plus the
    internally-managed ``cancel_requested`` flag.
    """
    with _lock:
        job = _jobs.get(job_id)
        if job is None:
            return None
        allowed = set(job.keys()) | {"cancel_requested"}
        job.update({k: v for k, v in fields.items() if k in allowed})
        return dict(job)


def get(job_id: str) -> Optional[dict]:
    with _lock:
        job = _jobs.get(job_id)
        return dict(job) if job else None


def list_jobs() -> list[dict]:
    """Return all jobs, most-recent-first."""
    with _lock:
        return [dict(j) for j in sorted(
            _jobs.values(), key=lambda j: j["dates"].get("created", 0), reverse=True
        )]


def set_status(job_id: str, status: str, error: str = "") -> None:
    update_snapshot(job_id, status=status, error=error)
    if status == "downloading":
        update_snapshot(job_id, dates={
            "created": _jobs[job_id]["dates"].get("created", _now()),
            "started": _now(),
            "finished": None,
        })
    elif status in ("completed", "failed", "cancelled"):
        update_snapshot(job_id, dates={
            "created": _jobs[job_id]["dates"].get("created", _now()),
            "started": _jobs[job_id]["dates"].get("started"),
            "finished": _now(),
        })


# ─── yt-dlp --progress line parsing ──────────────────────────────────────
# Example lines:
#   [download]   12.3% of 4.23MiB at 1.23MiB/s ETA 0:00:03
#   [download] Destination: /tmp/foo.mp4
#   [download] 100% of 4.23MiB in 0:00:03 at 1.34MiB/s
import re
_PCT_RE = re.compile(r"(\d+(?:\.\d+)?)\s*%")
_SPEED_RE = re.compile(r"at\s+([\d.]+)\s*([KM]iB/s)")
_SIZE_RE = re.compile(r"of\s+([\d.]+)\s*([KM]iB)")


def parse_progress_line(line: str, job_id: str) -> None:
    """Feed a single yt-dlp stdout line into the tracker for ``job_id``."""
    if "of" not in line:
        return
    snap = {}
    pct_m = _PCT_RE.search(line)
    if pct_m:
        snap["progress"] = float(pct_m.group(1)) / 100.0
    speed_m = _SPEED_RE.search(line)
    if speed_m:
        val = float(speed_m.group(1))
        unit = speed_m.group(2)
        # normalise to MB/s
        mb = val / 1024.0 if unit.startswith("K") else val
        snap["speed"] = round(mb, 2)
    size_m = _SIZE_RE.search(line)
    if size_m:
        val = float(size_m.group(1))
        unit = size_m.group(2)
        mb = val / 1024.0 if unit.startswith("K") else val
        snap["size"] = round(mb, 2)
    if snap:
        update_snapshot(job_id, **snap)
    if "ETA 0:00:00" in line or "100%" in line:
        pass  # completion handled by caller when yt-dlp exits
