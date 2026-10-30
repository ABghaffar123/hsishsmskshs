---
name: activity-log
---
# ACTIVITY_LOG.md

## 2026-10-21 00:32 – Initial checkpoint
- Created durable checkpoint directory `work_state/` with CURRENT_STATE.md, TASK_CHECKLIST.md, TEST_EVIDENCE.md, ACTIVITY_LOG.md.
- Added checkpoint discipline to CLAUDE.md.

## 2026-10-21 00:38 – Environment inventory
- Verified: Flutter 3.47.2 / Dart 3.13.2
- Verified: Python 3.12, FastAPI 0.140.0, uvicorn 0.51.0
- Verified: yt-dlp (Python library) version 2026.08.19
- Verified: ffmpeg version 2026-09-07-git-ecc7eb519e (full_build)

## 2026-10-21 00:45 – First fix: Canonical job ID
- Modified `backend/routes/download.py`: retry endpoint now reuses original job_id instead of creating new one.
- Added validation (_err helper) and error logging for extract_info failures.
- pause/cancel endpoints now return full job snapshot.
- Verified worker `download_service.start_download` already honors passed job_id and does NOT create a second one (download_service.py:54-71).
- Fix consistent: route → tracker → worker all share canonical job_id.
- Note:** 2_report.md (line 33) previously claimed this fix was already present — but retry endpoint still created new_id. Fix was missing; now confirmed applied and consistent across retry/resume/pause/cancel endpoints.

## 2026-10-21 01:00 – Phase C Audit data collection
- Inventory completed across backend (routes, services, config) and frontend (all features, services, core).
- Verified versions: pubspec 1.0.32+24, build_config 1.0.32+24, backend config.APP_VERSION 1.0.32+24.
- Verified environment: Flutter 3.47.2 / Dart 3.13.2 / Python 3.12 / FastAPI 0.140.0 / yt-dlp 2026.08.19 / ffmpeg 2026-09-07.
- Checked existing test files: test/widget_test.dart (1 trivial test), tests/widget_tests.dart (static asserts only — not runnable via `flutter test`).
- Verified download artifact: 2897492e-...mp4 (640x360, 360p, H.264, 18.9MB, 3m33s).
- Started composing new_report.md at project root.

## 2026-10-21 01:15 – Full audit report written
- Created `new_report.md` at project root with all 15 sections:
  - Executive summary
  - Audit boundaries & evidence inventory
  - Recovered work before shutdown
  - Checkpoint system installed
  - Full feature matrix (A–M)
  - Prioritized findings register (VM-001–VM-020)
  - Backend & provider evidence
  - Download evidence (ffprobe-verified 360p artifact)
  - Version/build/install comparison
  - Tests/analyze/build outcomes
  - Security/performance/accessibility review
  - Files changed
  - Remaining work + priority order
  - Report review handoff
  - Fresh-session resume instructions
- Findings: 20 prioritized issues (2 high-severity security/functional, 5 medium, rest low/informational).
- No product features modified beyond retry job-ID fix.

## 2026-10-21 01:30 – Fix VM-002 + VM-015 + version bump
- Fixed GoRouter `/player` route (router.dart:33-40) to pass `streamUrl` + `sourceUrl` query params.
- Fixed deprecated `textScaleFactor` → `textScaler: TextScaler.linear(1.0)` in main.dart:65.
- Updated version 1.0.32+24 → 1.0.32+25 across: pubspec.yaml, build_config.dart, config.py.
- `flutter analyze lib` → 83 issues, 0 errors (one fewer than before).
- `python -m py_compile backend/routes/download.py backend/config.py` → SYNTAX OK.
- Started `flutter build apk --release` in background.

## 2026-10-21 01:45 – Phase 1 start: Architecture trace
- Read all backend files: download.py, download_service.py, yt_dlp_service.py, status.py, config.py, dependencies.py, progress_tracker.py.
- Confirmed: yt-dlp library (in-process), threading.Thread workers, canonical job_id consistent across route→tracker→worker.
- Root cause of VM-007 confirmed: cancel/pause only set status label, do not stop worker thread/yt-dlp.
- `_active_workers` registry exists in progress_tracker but is unused (registered but never registered TO).
- Fix plan: (1) add cancel_requested field + register_worker/unregister_worker in progress_tracker; (2) cooperative cancellation via progress hook exception; (3) real cancel/resume in download.py.
- Checkpoint saved before implementing fixes.

## 2026-10-21 02:30 – Phase 1 fixes implemented
- **Section 1 Architecture:** yt-dlp library (in-process, not subprocess). Thread workers. Canonical job_id. Documented in TEST_EVIDENCE ARCH-001.
- **Section 2 Cancellation:** progress_tracker now has cancel_requested flag + register_worker/unregister_worker + request_cancel/is_cancel_requested/clear_cancel_flag. yt_dlp_service progress hook checks flag and raises _DownloadCancelled to abort. download_service registers worker + clears flag on start + unregisters in finally. download.py cancel/pause/routes set flag + mark terminal.
- **Section 3 Pause/Resume:** Implemented as cooperative stop-and-resume (yt-dlp library cannot suspend mid-flight). Pause = request_cancel + mark paused. Resume checks worker liveness, then re-launches via download_service.start_download.
- **Section 4 Job lifecycle:** _TERMINAL set in status.py gates file serving. set_status transitions: pending→downloading→completed/failed/cancelled. Dates (created/started/finished) tracked.
- **Section 5 File resolution/security:** status.py rewritten — _is_within_download_dir uses os.path.commonpath (not string startswith), _find_job_file does exact {job_id}.ext match (no os.walk), _safe_mime returns correct video/audio types.
- **Section 6 Security:** extract.py + discover.py redact detail=str(e) — client gets generic message, server logs full error. API key via env var (already present).
- **Section 7 Tests:** 35 tests (test_progress_tracker.py + test_file_serving.py). ALL PASS via `python -m unittest discover -s backend/tests`.
- **Version:** 1.0.32+25 → 1.0.32+26 in pubspec.yaml, build_config.dart, config.py.
- **Frontend preserved:** discover_screen.dart, home_screen.dart, library_screen.dart, downloads_screen.dart, video_player_screen.dart, router.dart — UNCHANGED. Discover/Library/history safe.
- **flutter analyze lib**: running in background (timed out at 180s, moved to background).
- **Status:** Phase 1 NEARLY COMPLETE — implementing, testing done. Awaiting flutter analyze result + writing Phase 1 report.