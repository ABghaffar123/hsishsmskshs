"""Service layer around ffmpeg for merging and conversion.

* ``merge_video_audio``  – mux separate video + audio streams into one file.
* ``convert_to_mp3``     – rip audio track to MP3.
* ``probe_duration``     – return media duration in seconds (fallback if
  yt-dlp metadata is missing).
"""
import subprocess
from typing import Optional


def _run(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True, timeout=600)


def merge_video_audio(
    video_path: str, audio_path: str, output_path: str
) -> bool:
    """Fastest lossless merge: ``-c copy`` (no re-encode)."""
    try:
        proc = _run([
            "ffmpeg", "-y",
            "-i", video_path,
            "-i", audio_path,
            "-c", "copy",
            "-movflags", "+faststart",
            output_path,
        ])
        return proc.returncode == 0
    except Exception:
        return False


def convert_to_mp3(
    input_path: str, output_path: str, bitrate_kbps: int = 192
) -> bool:
    """Re-encode audio stream to MP3 @ ``bitrate_kbps``."""
    try:
        proc = _run([
            "ffmpeg", "-y",
            "-i", input_path,
            "-vn",                      # no video
            "-ab", f"{bitrate_kbps}k",
            "-ar", "44100",
            "-ac", "2",
            output_path,
        ])
        return proc.returncode == 0
    except Exception:
        return False


def probe_duration(path: str) -> Optional[float]:
    """Return media duration in seconds, or None on failure."""
    try:
        proc = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=noprint_wrappers=1:nokey=1", path],
            capture_output=True, text=True, timeout=30,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            return float(proc.stdout.strip())
    except Exception:
        pass
    return None
