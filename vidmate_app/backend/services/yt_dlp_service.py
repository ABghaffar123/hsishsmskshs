"""Service layer around the yt-dlp **Python library**.

Using the in-process library avoids depending on the yt-dlp CLI binary being
on ``PATH`` (which the sandbox env lacks). Progress is relayed through
yt-dlp's ``progress_hooks``.
"""
import os
import re
import json
import threading
import time
import logging
import yt_dlp
from typing import Any

from backend.services.progress_tracker import (
    update_snapshot, set_status, get as get_job,
    is_cancel_requested, clear_cancel_flag,
)
from backend import config

# Lightweight module-level logger so we get debug lines in uvicorn output
logger = logging.getLogger("vidimate.yt_dlp_service")
if not logger.handlers:
    logging.basicConfig(level=logging.INFO)

def debug_print(msg: str) -> None:
    """Debug helper that never raises — safe to call from hot paths."""
    logger.info(msg)

# Piped (or any compatible) instance for public feeds — sourced from config.
# Multiple fallback instances since individual instances can go down or serve
# HTML instead of JSON.
PIPED_BASE = config.PIPED_INSTANCE

# Fallback Piped API instances
_PIPED_FALLBACKS = [
    "https://piped.mha.fi",
    "https://piped.hagure.pro",
    "https://piped.projectsegfault.co",
    "https://piped.silurian.dev",
    "https://piped.tarnkappe.info",
]


def _yt_dlp_trending(limit: int = 20, region: str = "US") -> list[dict]:
    """Fetch trending-like videos directly via yt-dlp library as a last-resort
    fallback when all Piped instances are unavailable.

    YouTube has deprecated the public /feed/trending endpoint, so this uses
    a popularity search (sorted by view count) which approximates trending
    content.  Returns a list of raw yt-dlp info dicts (same shape as
    ``extract_info`` output).
    """
    debug_print("PIPED: falling back to yt-dlp native trending extraction")
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "ignoreerrors": True,
        "extract_flat": True,
        "skip_download": True,
        "playlist_items": f"1-{limit}",
    }
    # Search sorted by view count to approximate trending/popular content
    url = "https://www.youtube.com/results?search_query=music&sp=CAM%3D"
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
    if isinstance(info, dict) and "entries" in info:
        return [e for e in (info.get("entries") or []) if isinstance(e, dict)]
    if isinstance(info, list):
        return [e for e in info if isinstance(e, dict)]
    return []


def _is_video_format(f: dict) -> bool:
    """Return True if the format entry has a video stream (real video, not
    storyboard/image-only/audio-only)."""
    vcodec = f.get("vcodec", "")
    if not vcodec or vcodec == "none":
        return False
    # Exclude storyboard / mhtml / image-only pseudo-formats
    ext = (f.get("ext") or "").lower()
    if ext in ("mhtml", "jpg", "jpeg", "png", "gif", "webp"):
        return False
    if f.get("acodec") == "none" and not f.get("height"):
        return False
    return True


def _numeric_quality_sort(qualities: list[str]) -> list[str]:
    """Sort quality labels like '1080p', '720p' numerically descending.

    Falls back to 'best' at the end if empty. Prevents lexicographic bugs
    where '720p' > '1080p' as strings.
    """
    def _num(q: str) -> int:
        m = re.match(r"(\d+)", q)
        return int(m.group(1)) if m else 0

    return sorted(set(qualities), key=_num, reverse=True)


def _pick_format_for_quality(formats: list[dict], quality: str) -> str:
    """Build a yt-dlp format selector string honoring the requested quality.

    ``quality`` may be 'best' or a height label like '1080p'/'720p'.
    Returns a yt-dlp format string that prefers the requested height and
    falls back to best available.
    """
    if not quality or quality == "best":
        return "bestvideo+bestaudio/best"
    try:
        h = int(quality.replace("p", ""))
    except (ValueError, AttributeError):
        return "bestvideo+bestaudio/best"
    return f"bestvideo[height={h}]+bestaudio/best[height={h}]/best"


def _new_ydl(download: bool = False, **overrides) -> yt_dlp.YoutubeDL:
    params = {
        "quiet": True,
        "no_warnings": True,
        "ignoreerrors": True,
        "skip_download": not download,
    }
    if download:
        params["format"] = "bestvideo+bestaudio/best"
        params["merge_format"] = "mkv"
        params["outtmpl"] = "%(id)s.%(ext)s"
    params.update(overrides)
    return yt_dlp.YoutubeDL(params)


def extract_info(url: str) -> dict[str, Any]:
    """Return the first yt-dlp --dump-json-equivalent object for ``url``."""
    with _new_ydl(download=False) as ydl:
        info = ydl.extract_info(url, download=False)
    if isinstance(info, list):
        return info[0] if info else {}
    return info or {}


def _get_stream_url(formats: list[dict]) -> str:
    """Pick the first directly-playable stream URL from yt-dlp formats.

    Prefers progressive/m3u8 formats that media_kit can open directly (i.e.
    not a YouTube *watch* URL). Falls back to the first video format.
    """
    for f in formats:
        if not _is_video_format(f):
            continue
        url = f.get("url", "")
        if not url:
            continue
        # Prefer m3u8 / direct media URLs over watch URLs
        if "m3u8" in url or "/videoplayback" in url:
            return url
    # fallback: first playable video URL
    for f in formats:
        if _is_video_format(f):
            return f.get("url", "")
    return ""


def _video_model(ydl_json: dict) -> dict:
    """Map raw yt-dlp JSON → VideoModel shape (Flutter)."""
    formats = ydl_json.get("formats", [])
    qualities: list[str] = []
    audio_url = ""
    for f in formats:
        if not _is_video_format(f):
            continue
        height = f.get("height")
        if height:
            qualities.append(f"{height}p")
    # Collect audio-only URL separately
    for f in formats:
        if f.get("vcodec") == "none" and f.get("acodec") != "none":
            audio_url = f.get("url", "")
            break
    stream_url = _get_stream_url(formats)  # prefer m3u8 / videoplayback
    dur = ydl_json.get("duration", 0)
    return {
        "id": ydl_json.get("id", ""),
        "title": ydl_json.get("title", ""),
        "channel": ydl_json.get("uploader", ydl_json.get("creator", "")),
        "thumbnail": ydl_json.get("thumbnail", ""),
        "duration": int(dur) if dur else 0,
        "view_count": int(ydl_json.get("view_count", 0) or 0),
        "category": (ydl_json.get("categories") or ["video"])[0]
            if isinstance(ydl_json.get("categories"), list) else "video",
        "qualities": _numeric_quality_sort(qualities) or ["best"],
        "source_url": ydl_json.get("webpage_url", ydl_json.get("url", "")),
        "video_url": ydl_json.get("url", "") or stream_url,
        "stream_url": stream_url,
        "audio_url": audio_url,
    }


def _extracted_model(ydl_json: dict) -> dict:
    """Map raw yt-dlp JSON → ExtractedVideoModel shape (Flutter)."""
    fmts = ydl_json.get("formats", [])
    qualities: list[str] = []
    audio_url = ""
    for f in fmts:
        if not _is_video_format(f):
            continue
        h = f.get("height")
        if h:
            qualities.append(f"{h}p")
    for f in fmts:
        if f.get("vcodec") == "none" and f.get("acodec") != "none":
            audio_url = f.get("url", "")
            break
    stream_url = _get_stream_url(fmts)  # prefer m3u8 / videoplayback
    dur = ydl_json.get("duration", 0)
    return {
        "id": ydl_json.get("id", ""),
        "title": ydl_json.get("title", ""),
        "thumbnail": ydl_json.get("thumbnail", ""),
        "duration": int(dur) if dur else 0,
        "qualities": _numeric_quality_sort(qualities) or ["best"],
        "audio_only_url": audio_url,
        "video_url": ydl_json.get("url", "") or stream_url,
        "stream_url": stream_url,
        "source_url": ydl_json.get("webpage_url", ydl_json.get("url", "")),
    }


def _piped_video(item: dict) -> dict:
    """Map a Piped API item → VideoModel shape."""
    return {
        "id": item.get("id", ""),
        "title": item.get("title", ""),
        "channel": item.get("uploader", item.get(" uploader", "")),
        "thumbnail": item.get("thumbnail", ""),
        "duration": item.get("duration", 0),
        "view_count": item.get("views", 0),
        "category": item.get("category", "video"),
        "qualities": [],
        "source_url": f"https://www.youtube.com/watch?v={item.get('id')}",
        "video_url": item.get("url", ""),
    }


def _fetch_piped(path: str, params: dict | None = None, timeout: int = 20) -> list[dict]:
    """Fetch and parse a Piped endpoint, distinguishing real failures from
    genuinely-empty results.

    Tries the configured ``PIPED_BASE`` first, then falls back to a list of
    known-good Piped instances. Raises ``ValueError`` on HTML / non-JSON
    responses, ``httpx.HTTPError`` on transport errors, and returns ``[]``
    only when the Piped API explicitly returns an empty list/array.
    """
    import httpx
    from urllib.parse import urlencode

    # Build a list of instance candidates — primary first, then fallbacks
    candidates = [PIPED_BASE] + [f for f in _PIPED_FALLBACKS if f != PIPED_BASE]

    last_error: Exception | None = None
    for instance in candidates:
        url = f"{instance}/{path}"
        if params:
            url = f"{url}?{urlencode(params)}"
        try:
            debug_print(f"PIPED: trying {url}")
            with httpx.Client(timeout=timeout, follow_redirects=True) as client:
                resp = client.get(url)
                resp.raise_for_status()
        except httpx.HTTPError as e:
            last_error = e
            debug_print(f"PIPED: transport error for {instance}: {e}")
            continue

        # If Piped serves an HTML frontend (200 OK but HTML body), that's a
        # misconfigured instance — try the next one.
        content_type = (resp.headers.get("content-type") or "").lower()
        if "html" in content_type or resp.text.lstrip().startswith(("<!DOCTYPE", "<html")):
            last_error = ValueError(f"Piped returned HTML at {url}")
            debug_print(f"PIPED: HTML response from {instance}, trying next")
            continue

        try:
            data = resp.json()
        except Exception:
            last_error = ValueError(f"Piped returned non-JSON at {url}: {resp.text[:200]}...")
            debug_print(f"PIPED: non-JSON from {instance}, trying next")
            continue

        # Success — return parsed data (handle non-list responses gracefully)
        debug_print(f"PIPED: success from {instance}, type={type(data).__name__}")
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            # Some endpoints return a dict with a "content" or "items" key
            if isinstance(data.get("content"), list):
                return data["content"]
            if isinstance(data.get("items"), list):
                return data["items"]
            if isinstance(data.get("data"), list):
                return data["data"]
        return []

    # All instances failed — raise the last error so the caller gets a real failure
    if last_error:
        raise last_error
    raise ValueError("All Piped instances unavailable")


def discover_trending(limit: int = 20, region: str = "US"):
    """Fetch trending from Piped. Falls back to yt-dlp native extraction
    if all Piped instances fail. Raises on failure."""
    try:
        items = _fetch_piped("trending", {"region": region, "limit": limit})
        if not items:
            # Piped returned empty list — try yt-dlp as fallback
            debug_print("PIPED: empty result from Piped, trying yt-dlp fallback")
            raw_items = _yt_dlp_trending(limit=limit, region=region)
            return [_video_model(ri) for ri in raw_items[:limit] if ri.get("id")]
        return [_piped_video(it) for it in items[:limit]]
    except Exception as e:
        debug_print(f"PIPED: trending failed with error: {e}, trying yt-dlp fallback")
        try:
            raw_items = _yt_dlp_trending(limit=limit, region=region)
            if raw_items:
                return [_video_model(ri) for ri in raw_items[:limit] if ri.get("id")]
        except Exception as e2:
            debug_print(f"PIPED: yt-dlp fallback also failed: {e2}")
        raise


def discover_search(query: str, limit: int = 20, page: int = 1):
    """Search via Piped. Falls back to yt-dlp native search if all Piped
    instances fail. Raises on failure."""
    try:
        items = _fetch_piped("search", {"q": query, "page": page})
        if not items:
            debug_print("PIPED: empty result from search, trying yt-dlp fallback")
            raw_items = _yt_dlp_search(query, limit=limit)
            return [_video_model(ri) for ri in raw_items[:limit] if ri.get("id")]
        return [_piped_video(it) for it in items[:limit]]
    except Exception as e:
        debug_print(f"PIPED: search failed with error: {e}, trying yt-dlp fallback")
        try:
            raw_items = _yt_dlp_search(query, limit=limit)
            if raw_items:
                return [_video_model(ri) for ri in raw_items[:limit] if ri.get("id")]
        except Exception as e2:
            debug_print(f"PIPED: yt-dlp search fallback also failed: {e2}")
        raise


def _yt_dlp_search(query: str, limit: int = 20) -> list[dict]:
    """Fetch search results directly via yt-dlp library as a last-resort
    fallback when all Piped instances are unavailable."""
    debug_print(f"PIPED: falling back to yt-dlp native search for '{query}'")
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "ignoreerrors": True,
        "extract_flat": True,
        "skip_download": True,
        "playlist_items": f"1-{limit}",
    }
    url = f"https://www.youtube.com/results?search_query={query}"
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
    if isinstance(info, dict) and "entries" in info:
        return [e for e in (info.get("entries") or []) if isinstance(e, dict)]
    if isinstance(info, list):
        return [e for e in info if isinstance(e, dict)]
    return []


# Re-export model converters with original names
to_video_model = _video_model
to_extracted_model = _extracted_model
to_video_model_from_piped = _piped_video


class _DownloadCancelled(Exception):
    """Raised inside a yt-dlp progress hook to abort a cancelled download."""


def download_with_progress(url: str, out_dir: str, job_id: str,
                           quality: str = "best", file_type: str = "video") -> str:
    """Synchronous blocking download using the yt-dlp library.

    Updates the shared ``progress_tracker`` snapshot via callbacks.
    Returns the path to the final file.
    """
    from .ffmpeg_service import convert_to_mp3

    # progress_hooks callback regexes
    progress_re = re.compile(r"(\d+(?:\.\d+)?)%")
    speed_re = re.compile(r"(\d+(?:\.\d+)?)\s*([KM]?i?B/s)")

    def _hook(d):
        # Cooperative cancellation: if the route handler flagged this job for
        # cancellation, raise an exception inside the yt-dlp progress hook so
        # the library aborts the download immediately rather than continuing.
        if is_cancel_requested(job_id):
            debug_print(f"PLAYER: cancel requested for job {job_id}, aborting yt-dlp")
            raise _DownloadCancelled(f"Job {job_id} cancelled by user")
        if d.get("status") == "downloading":
            pct = d.get("_percent_str", "0%")
            m = progress_re.search(pct.replace("%", ""))
            if m:
                update_snapshot(job_id, progress=float(m.group(1)) / 100.0)
            spd = d.get("_speed_str", "")
            m2 = speed_re.search(spd)
            if m2:
                val = float(m2.group(1))
                unit = (m2.group(2) or "MiB/s").lower()
                # normalise to MB/s
                if unit.startswith("k"):
                    mb = val / 1024.0
                elif unit.startswith("g"):
                    mb = val * 1024.0
                else:  # MiB/s
                    mb = val
                update_snapshot(job_id, speed=round(mb, 2))
            # Update size if available
            tot = d.get("_total_bytes_str") or d.get("_total_bytes")
            if tot:
                try:
                    size_mb = float(tot) / (1024 * 1024)
                    update_snapshot(job_id, size=round(size_mb, 2))
                except (ValueError, TypeError):
                    pass

    if file_type == "audio":
        fmt = "bestaudio/best"
    else:
        # First extract info to get actual formats for quality selection
        try:
            raw = extract_info(url)
            fmts = raw.get("formats", []) if isinstance(raw, dict) else []
            fmt = _pick_format_for_quality(fmts, quality)
        except Exception:
            fmt = _pick_format_for_quality([], quality)

    os.makedirs(out_dir, exist_ok=True)
    outtmpl = os.path.join(out_dir, f"{job_id}.%(ext)s")

    ydl_opts = {
        "format": fmt,
        "outtmpl": outtmpl,
        "progress_hooks": [_hook],
        "quiet": True,
        "no_warnings": True,
        "merge_auto": True,
        "postprocessors": [],
    }
    if file_type == "audio":
        ydl_opts["postprocessors"] = [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": "mp3",
            "preferredquality": "192",
        }]
    else:
        # Ensure merged output is in an MP4 container for mobile compatibility
        ydl_opts["postprocessors"] = [{
            "key": "FFmpegVideoConvertor",
            "preferedformat": "mp4",
        }]

    set_status(job_id, "downloading")
    start = time.time()
    snap = get_job(job_id)
    created = snap["dates"]["created"] if snap and "dates" in snap else start
    update_snapshot(job_id, dates={
        "created": created,
        "started": start,
        "finished": None,
    })

    try:
        with _new_ydl(download=True, **ydl_opts) as ydl:
            ydl.download([url])
    except _DownloadCancelled:
        debug_print(f"PLAYER: download cancelled for job {job_id}")
        # Keep terminal status "cancelled" — don't overwrite with "failed"
        return ""
    except Exception as e:
        set_status(job_id, "failed", error=str(e))
        raise
    finally:
        clear_cancel_flag(job_id)

    # locate final file — exclude empty/partial files.
    # After merge/conversion the file may be renamed to job_id.mp4.
    final_path = ""
    for root, _dirs, files in os.walk(out_dir):
        for f in files:
            if f.startswith(job_id):
                candidate = os.path.join(root, f)
                try:
                    if os.path.getsize(candidate) > 0:
                        # Prefer non-empty .mp4 / .mkv files over partial downloads
                        if f.endswith(".mp4"):
                            final_path = candidate
                            break
                        if not final_path:
                            final_path = candidate
                except OSError:
                    continue
        if final_path:
            break
    if final_path and os.path.exists(final_path) and os.path.getsize(final_path) == 0:
        final_path = ""
    if not final_path:
        # yt-dlp reported success but we could not locate a non-empty output
        # file in out_dir. Do NOT silently return "" — that caused jobs to be
        # marked "completed" with empty file_path. Raise so the worker thread
        # flags the job as failed with a real error message.
        raise RuntimeError(
            f"yt-dlp download finished but no non-empty output file "
            f"starting with job_id={job_id} was found in {out_dir}"
        )
    return final_path
