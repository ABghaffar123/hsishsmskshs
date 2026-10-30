---
name: home_section_report
description: Detailed report of home section download flow issues
metadata:
  type: reference
---

Home section download flow analysis completed. Key findings:

1. Quality selection dialog not propagating selection to download reliably
2. `_isDownloading` state reset only in finally block - potential race conditions
3. No visual on-screen marker during the extraction/dialog flow
4. Clipboard auto-detection requires extra "Get" tap
5. Continue watching/recent downloads show empty states (Hive DB not populated)

Fix recommendations: Add debug markers, improve state management, ensure visible feedback on phone. Modify existing `home_screen.dart` only - no new files with _new/_fixed/_final suffixes.

Verification: Check `git diff --stat`, `flutter analyze lib` (0 errors), end-to-end flow from `main.dart` → quality selection → `startDownload()`.