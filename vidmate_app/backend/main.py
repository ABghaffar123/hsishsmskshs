"""VidiMate fresh backend — FastAPI + yt-dlp + FFmpeg.

Run:
    uvicorn main:app --host 0.0.0.0 --port 8000

Health check:
    curl -H "x-api-key: <secret>" http://127.0.0.1:8000/health

Debug marker returned in /health: ``backend: vidimate-v2``.
"""
import os
from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from backend import config
from backend.services import yt_dlp_service, ffmpeg_service, download_service, progress_tracker
from backend.dependencies import require_api_key
# route modules live one level down (same package)
from backend.routes import discover as discover_routes
from backend.routes import download as download_routes
from backend.routes import extract as extract_routes
from backend.routes import status as status_routes
from backend.routes import updates as updates_routes

__version__ = "2.0.0"

DESCRIPTION = """
VidiMate real backend.

* Discover / search / category  → Piped feed (public, no auth to Piped)
* Extract URL → yt-dlp metadata parsing
* Download    → yt-dlp download + FFmpeg merge / MP3 conversion
* Progress    → real-time via ``/api/status/{jobId}`` polling
"""


@asynccontextmanager
async def lifespan(app: FastAPI):
    # verify yt-dlp is reachable at startup
    import shutil
    if shutil.which(config.YT_DLP_BIN):
        import subprocess
        try:
            v = subprocess.run(
                [config.YT_DLP_BIN, "--version"],
                capture_output=True, text=True, timeout=30,
            )
            print(f"[vidimate-backend] yt-dlp version: {v.stdout.strip() or 'unknown'}")
        except Exception as e:
            print(f"[vidimate-backend] yt-dlp version check failed (non-fatal): {e}")
    else:
        print(f"[vidimate-backend] WARNING: {config.YT_DLP_BIN} NOT on PATH")

    import shutil as _sh
    if not _sh.which("ffmpeg"):
        print("[vidimate-backend] WARNING: ffmpeg NOT on PATH")
    else:
        print("[vidimate-backend] ffmpeg OK")
    yield
    print("[vidimate-backend] shutting down …")


app = FastAPI(
    title="VidiMate Backend",
    version=__version__,
    description=DESCRIPTION,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://192.168.100.9:8000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Global API-key gate ─────────────────────────────────────────────────
@app.middleware("http")
async def api_key_middleware(request: Request, call_next):
    if request.url.path == "/health":
        # health is open (but we still log attempts without key)
        return await call_next(request)
    key = request.headers.get("x-api-key", "")
    if key != config.API_KEY:
        return JSONResponse(
            {"success": False, "data": {"detail": "Invalid or missing x-api-key"}},
            status_code=401,
        )
    return await call_next(request)


# ─── Health ──────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    """Public health check incl. debug marker for phone visibility.

    Marker: ``"backend": "vidimate-v2"`` so the Flutter
    ``BackendApiClient.healthCheck()`` + phone UI can confirm the
    real (non-mock) backend is live.
    """
    return {"status": "ok", "backend": "vidimate-v2", "version": __version__}


# ─── Routes ─────────────────────────────────────────────────────────────
app.include_router(discover_routes.router)
app.include_router(download_routes.router)
app.include_router(extract_routes.router)
app.include_router(status_routes.router)
app.include_router(updates_routes.router)

# ─── Legacy route alias ─────────────────────────────────────────────────
# The Flutter client expects POST /api/download to start a job and
# GET  /api/download (list) is mapped to GET /api/downloads above.
# FastAPI distinguishes by method automatically.
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "backend.main:app",
        host=config.HOST,
        port=config.PORT,
        reload=os.getenv("VM_RELOAD", "0") == "1",
    )
