"""Updates route: serve current app version for in-app update checks."""
from fastapi import APIRouter, Depends
from backend import config
from backend.dependencies import require_api_key

router = APIRouter(prefix="/api", tags=["updates"])


def _ok(data: dict) -> dict:
    return {"success": True, "data": data}


@router.get("/updates")
async def updates(_user: dict = Depends(require_api_key)):
    """Return the current app version + update metadata.

    The Flutter client (BackendApiClient.checkUpdates) calls GET /api/updates
    to compare its installed version against the backend's reported version.
    Previously this endpoint was missing → 404. Now implemented here.
    """
    return _ok({
        "current_version": config.APP_VERSION,
        "latest_version": config.APP_VERSION,
        "has_update": False,
        "backend_version": config.APP_VERSION,
    })
