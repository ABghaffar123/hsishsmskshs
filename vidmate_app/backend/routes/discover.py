"""Discover routes: trending / search / category / video-by-id.

Feeds are sourced from a Piped public instance (no auth needed).
All responses conform to SearchResultModel / VideoModel JSON shapes
the Flutter app already deserialises.
"""
import logging

from fastapi import APIRouter, HTTPException, Query, Depends

from backend import config
from backend.services import yt_dlp_service
from backend.dependencies import require_api_key

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/discover", tags=["discover"])


def _ok(data: dict) -> dict:
    return {"success": True, "data": data}


@router.get("/trending")
async def trending(
    page: int = Query(1),
    limit: int = Query(20),
    _user: dict = Depends(require_api_key),
):
    try:
        videos = yt_dlp_service.discover_trending(limit=limit)
    except Exception as e:
        logger.warning("Piped trending fetch failed: %s", e)
        # Return structured error, not success-with-empty-data
        return {
            "success": False,
            "error": "provider_unavailable",
            "message": "Failed to load trending videos from Piped provider.",
            "videos": [],
            "total": 0,
            "page": page,
            "limit": limit,
        }
    return _ok({
        "videos": videos,
        "total": len(videos),
        "query": "trending",
        "page": page,
        "limit": limit,
    })


@router.get("/search")
async def search(
    q: str = Query(...),
    page: int = Query(1),
    limit: int = Query(20),
    _user: dict = Depends(require_api_key),
):
    try:
        videos = yt_dlp_service.discover_search(q, limit=limit, page=page)
    except Exception as e:
        logger.warning("Piped search fetch failed: %s", e)
        return {
            "success": False,
            "error": "provider_unavailable",
            "message": "Failed to search videos on Piped provider.",
            "videos": [],
            "total": 0,
            "query": q,
            "page": page,
            "limit": limit,
        }
    return _ok({
        "videos": videos,
        "total": len(videos),
        "query": q,
        "page": page,
        "limit": limit,
    })


@router.get("/category/{category}")
async def category(
    category: str,
    page: int = Query(1),
    limit: int = Query(20),
    _user: dict = Depends(require_api_key),
):
    # Piped does not have a direct category endpoint; search by category name
    try:
        videos = yt_dlp_service.discover_search(category, limit=limit, page=page)
    except Exception as e:
        logger.warning("Piped category fetch failed: %s", e)
        return {
            "success": False,
            "error": "provider_unavailable",
            "message": f"Failed to load category '{category}' from Piped provider.",
            "videos": [],
            "total": 0,
            "query": category,
            "page": page,
            "limit": limit,
        }
    return _ok({
        "videos": videos,
        "total": len(videos),
        "query": category,
        "page": page,
        "limit": limit,
    })


@router.get("/{video_id}")
async def video_detail(
    video_id: str,
    _user: dict = Depends(require_api_key),
):
    # yt-dlp --dump-json gives authoritative metadata incl. formats/qualities
    url = f"https://www.youtube.com/watch?v={video_id}"
    try:
        raw = yt_dlp_service.extract_info(url)
    except Exception as e:
        logger.warning("extract_info failed for %s: %s", video_id, e)
        # Redact internal details (yt-dlp error paths, network internals)
        raise HTTPException(
            status_code=404,
            detail="cannot extract video metadata — video may be unavailable",
        )
    return _ok(yt_dlp_service.to_video_model(raw))
