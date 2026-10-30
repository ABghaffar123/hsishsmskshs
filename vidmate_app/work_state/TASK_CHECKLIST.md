---
name: task-checklist
---
# TASK_CHECKLIST.md

**Assignment:** VIDIMATE_SESSION_RECOVERY_AND_FULL_APP_AUDIT.md – Durable checkpoints + full-app audit.

## Phase B – Durable checkpoint system
- [x] `work_state/` directory created per spec.
- [x] **CURRENT_STATE.md** saved.
- [x] **TASK_CHECKLIST.md** saved.
- [x] **TEST_EVIDENCE.md** saved.
- [x] **ACTIVITY_LOG.md** saved.
- [x] Update **CLAUDE.md** with checkpoint discipline (Phase B, § 89–97).
- [x] Demonstrate recovery by re-reading populated checkpoint files.
- [x] Report exact recoverable next step from saved checkpoint.

## Phase C – Full-app audit
- [x] **new_report.md** created at Flutter project root – COMPLETE (all 15 sections).
- [x] Inspect project/build/version/configuration – DONE.
- [x] Audit app startup/navigation/state/lifecycle – DONE.
- [x] Audit Home and clipboard/Get workflow – DONE.
- [x] Audit Discover provider layer – DONE.
- [x] Audit extraction and format selection – DONE.
- [x] Audit backend startup/config/security – DONE.
- [x] Audit download pipeline – DONE.
- [x] Audit mobile save/history/refresh – DONE.
- [x] Audit library/local media – DONE.
- [x] Audit video/audio players – DONE.
- [x] Audit settings/storage/notifications/permissions – DONE.
- [x] Audit performance/accessibility/UI – DONE.
- [x] Audit mock/stub/dead-code review – DONE.
- [x] Verify 1080p/360p test artifacts – DONE (360p confirmed, 1080p missing).
- [ ] Run runtime/test/build plan (flutter test, flutter build apk --release) – IN PROGRESS.
- [x] Save detailed **new_report.md** with all sections – DONE.

## Implementation tasks (CRITICAL BUGS)
Based on VIDIMATE_CRITICAL_FIX_IMPLEMENTATION.md – implement one at a time:
- [x] Fix canonical job ID mismatch (job_A vs. job_B). – **COMPLETE** (retry reuses job_id; verified).
- [x] Fix quality filtering/sorting (lexicographic vs numeric). – **VERIFIED PRESENT** (backend has _numeric_quality_sort).
- [x] Fix Piped provider HTML/JSON parsing. – **VERIFIED PRESENT** (backend has _fetch_piped).
- [x] Fix video playback surface bug. – **PARTIAL** (streamUrl wired in VideoPlayerScreen).
- [x] Fix _saveDownloadedFile returning null. – **FIXED** (real impl present; pending MediaStore upgrade – VM-008).
- [x] Fix version/build/install mismatch. – **FIXED** (all sources consistent).
- [x] VM-002: GoRouter /player route streamUrl/sourceUrl – **FIXED** (router.dart updated).
- [x] VM-015: Deprecated textScaleFactor – **FIXED** (main.dart → textScaler).
- [x] VM-007: Pause/cancel stops yt-dlp subprocess – **FIXED** (cooperative cancel flag + progress hook abort + thread registry; verified by 35 backend tests).
- [ ] VM-008: True MediaStore file saving – **PENDING** (reported only).

## Build status
- [ ] `flutter build apk --release` – IN PROGRESS (backgrounded, checking output…)