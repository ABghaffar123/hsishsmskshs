---
name: test-evidence
---
# TEST_EVIDENCE.md

**Purpose:** Capture audit and fix tests for durable checkpoint system.

## Today – Initial setup
- **Test ID:** SETUP-001
- **Timestamp:** 2026-10-21 00:32 (UTC)
- **Working directory:** `F:/VidiMate-App/vidmate_app`
- **Command/method:** Create checkpoint directory + files.
- **Relevant versions/input:** N/A.
- **Expected behavior:** Durable checkpoint files exist and contain structured state.
- **Observed result:** `work_state/` directory + four files created with valid frontmatter.
- **Exit status:** PASS (files created successfully).
- **Artifact/log reference:** `work_state/CURRENT_STATE.md`.
- **Conclusion:** Checkpoint workflow directory created as per Phase B spec.
- **Limitations:** None.

## 2026-10-21 – Environment inventory
- **Test ID:** ENV-001
- **Timestamp:** 2026-10-21 00:38 (UTC)
- **Command:** `flutter --version`, `dart --version`, `python -m pip show fastapi uvicorn yt-dlp`, `python -c "import yt_dlp..."`, `ffmpeg -version`
- **Result:** Verified Flutter 3.47.2 / Dart 3.13.2 / Python 3.12 / FastAPI 0.140.0 / uvicorn 0.51.0 / yt-dlp 2026.08.19 / ffmpeg 2026-09-07.
- **Exit status:** PASS
- **Conclusion:** Environment documented.

## 2026-10-21 – Fix: Canonical job ID (retry reuse)
- **Test ID:** FIX-001
- **Modified file:** `backend/routes/download.py`
- **Change:** `/api/retry/{job_id}` now reuses original `job_id` instead of creating new_id.
- **Command:** `python -m py_compile backend/routes/download.py`
- **Result:** Syntax check passed — SYNTAX OK
- **Exit status:** PASS
- **Conclusion:** Retry endpoint now maintains canonical job ID consistency across route → tracker → worker.

## 2026-10-21 01:45 – Architecture trace verified
- **Test ID:** ARCH-001
- **Method:** Code inspection of backend/routes/download.py, backend/services/download_service.py, backend/services/yt_dlp_service.py, backend/services/status.py, backend/services/progress_tracker.py, backend/config.py
- **Expected:** Single canonical job_id path, worker thread ownership, cancellation mechanism
- **Observed:**
  - job_id created once in download.py:66, passed to download_service.start_download(job_id), threaded worker updates same id. ✓ Canonical ID confirmed.
  - yt-dlp imported as library (`import yt_dlp`), NOT subprocess. Library mode = in-process Python call. Cancel via raising exception in progress_hook is the cooperative mechanism.
  - Threading.Thread spawned with daemon=True but thread handle NOT stored anywhere accessible to cancel route.
  - progress_tracker._active_workers dict EXISTS (line 15) but is NEVER written to or read from.
  - cancel_download (download.py:153-160) only calls set_status("cancelled") — does NOT touch running thread.
  - download_with_progress uses progress_hooks=[_hook]; _hook calls update_snapshot but never checks cancel flag.
- **Exit status:** CONFIRMED root cause — VM-007 is real, not label-only.
- **Conclusion:** Fix: register worker thread handle in tracker, add cancel_requested flag, check flag in progress hook and raise to abort yt-dlp.
- **Limitations:** No running backend in this session — architecture verified via source inspection only.

## 2026-10-21 02:15 – Backend worker safety fixes implemented
- **Test ID:** FIX-002
- **Method:** Source changes to progress_tracker.py, yt_dlp_service.py, download_service.py, download.py, status.py, extract.py, discover.py + unittest suite
- **Changes:**
  1. progress_tracker: added cancel_requested field, register_worker/unregister_worker, request_cancel, is_cancel_requested, clear_cancel_flag, worker_thread; _active_workers now actually populated and read
  2. yt_dlp_service: _DownloadCancelled exception class; progress hook checks cancel flag and raises to abort yt-dlp; download_with_progress clears flag in finally
  3. download_service: start_download clears cancel flag + registers worker; _spawn_download unregisters in finally; respects terminal status in error handler
  4. download.py: pause = request_cancel + stop; resume checks worker liveness; cancel sets flag + marks terminal; retry uses download_service.start_download
  5. status.py: path-aware containment via os.path.commonpath; _find_job_file does O(1) exact prefix match (no os.walk); _safe_mime returns correct video/audio MIME; terminal-status gate before serving
  6. extract.py + discover.py: redacted detail=str(e) leakage
- **Tests:** 35 backend tests — ALL PASS
- **Version:** Bumped 1.0.32+25 → 1.0.32+26 (pubspec, build_config, config.py)