"""Backend configuration for VidiMate backend."""
import os
from pathlib import Path

# ─── Server ───────────────────────────────────────────────────────────────
HOST = os.getenv("VM_HOST", "0.0.0.0")
PORT = int(os.getenv("VM_PORT", "8000"))

# ─── Auth ─────────────────────────────────────────────────────────────────
# Shared secret sent from the Flutter app as the `x-api-key` header.
# The Flutter side hard-codes the same value (BuildConfig / main.dart).
API_KEY = os.getenv("VM_API_KEY", "vidimate-secret-2026")

# Application version — kept in sync with pubspec.yaml
APP_VERSION = "1.2.8+9"

# ─── Storage ──────────────────────────────────────────────────────────────
_BASE_DIR = Path(__file__).resolve().parent
DOWNLOAD_DIR = _BASE_DIR / "downloads"
TEMP_DIR = _BASE_DIR / "temp"

# yt-dlp binary / paths
YT_DLP_BIN = os.getenv("YT_DLP_BIN", "yt-dlp")

# ─── External data sources ────────────────────────────────────────────────
# Piped instance used for discover/search feeds (public, no auth needed).
PIPED_INSTANCE = os.getenv(
    "PIPED_INSTANCE", "https://piped.kavin.rocks"
)

# ─── Ensure dirs exist ───────────────────────────────────────────────────
DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
TEMP_DIR.mkdir(parents=True, exist_ok=True)

if __name__ == "__main__":
    import json
    print(json.dumps({
        "host": HOST, "port": PORT, "api_key": API_KEY,
        "download_dir": str(DOWNLOAD_DIR), "temp_dir": str(TEMP_DIR),
        "piped": PIPED_INSTANCE, "yt_dlp_bin": YT_DLP_BIN,
    }, indent=2))
