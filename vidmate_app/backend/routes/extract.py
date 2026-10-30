"""Extract route: paste-link URL → format/quality info."""
from fastapi import APIRouter, HTTPException, Depends

from backend.services import yt_dlp_service
from backend.dependencies import require_api_key

router = APIRouter(prefix="/api", tags=["extract"])


def _ok(data: dict) -> dict:
    return {"success": True, "data": data}


@router.post("/extract")
async def extract(
    payload: dict,
    _user: dict = Depends(require_api_key),
):
    url: str = payload.get("url", "")
    if not url:
        raise HTTPException(status_code=400, detail="url required")

    try:
        raw = yt_dlp_service.extract_info(url)
    except yt_dlp_service._DownloadCancelled:
        raise HTTPException(status_code=409, detail="download was cancelled")
    except Exception:
        # Redact internal yt-dlp / path / network details from the client.
        raise HTTPException(
            status_code=404,
            detail="cannot extract video metadata — URL may be unavailable or invalid",
        )

    extracted = yt_dlp_service.to_extracted_model(raw)
    return _ok(extracted)
