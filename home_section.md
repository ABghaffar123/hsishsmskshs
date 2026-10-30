# Home Section — Detailed Problem Report

**Report Date:** 2026-10-25  
**Issue Category:** Frontend / UI Flow  
**Backend Status:** Working (confirmed via CLI/test commands)  
**Affected Area:** `vidmate_app/lib/features/home/presentation/home_screen.dart`  

---

## 1. User-Reported Symptom

> "Home section main link paste kardi, Get button click kiya, kuch time baad quality selection options aaye. Maine 1080p select kiya lekin kuch nahi hua — sirf touch feel hui, download start nahi hua. Backend se video download command chalne par successful thi, isliye ye sirf frontend/issue hai."

**Translation:** "I pasted a link in the home section, clicked the Get button, after some time quality selection options appeared. I selected 1080p but nothing happened — just a touch feeling, download didn't start. Since the backend video download command was successful via CLI, this is purely a frontend issue."

---

## 2. Code Flow Analysis

The download flow in the home section follows this sequence:

1. **`_handleGetButton()`** (line 319) — Called when user taps "Get"
   - Calls `_checkClipboard()` to populate `_pasteLinkController` from clipboard if a video URL is detected
   - If URL present, calls `_detectAndDownload()`

2. **`_detectAndDownload()`** (line 109) — Main orchestration function
   - Validates URL via `_validateVideoUrl()` (lines 113-121)
   - Sets `_isDetecting = true` (line 125)
   - Calls `BackendApiClient.extractVideoInfo(url)` (line 130)
   - If extraction succeeds, shows **quality selection dialog** via `_showQualitySelectionDialog(context, extracted)` (line 149)
   - Awaits user's quality choice (`selectedQuality`)
   - If quality selected, sets `_isDownloading = true` (lines 158-161)
   - Calls `BackendApiClient.startDownload(url, quality, fileType)` (line 163)

3. **`_showQualitySelectionDialog()`** (line 209) — Shows AlertDialog with radio tiles for each available quality + "Audio Only" option
   - Returns the selected `String?` quality value
   - On user selection, `onChanged` sets `selectedQuality` and calls `Navigator.of(context).pop()`

---

## 3. Identified Issues in the Home Section Flow

### Issue A: Quality Selection Dialog — Selection Not Propagating to Download

**Evidence:** Lines 149-174 in `home_screen.dart`

```dart
// Line 149 — awaits the dialog result
final selectedQuality = await _showQualitySelectionDialog(context, extracted);

// Lines 151-155 — handles cancellation
if (selectedQuality == null) {
  setState(() {
    _isDetecting = false;
  });
  return;
}

// Lines 158-161 — sets downloading state
setState(() {
  _isDetecting = false;
  _isDownloading = true;
});

// Line 163 — starts download with selected quality
final job = await BackendApiClient.startDownload(
  url: extracted.sourceUrl,
  quality: isAudioOnly ? 'best' : selectedQuality,
  fileType: isAudioOnly ? 'audio' : 'video',
);
```

**Potential Problem:** While the code appears correct, there are several edge cases where the flow can break:

- **Context invalidation:** The `context` used in `_showQualitySelectionDialog` and its internal `onChanged` callbacks references the `BuildContext` at dialog-creation time. If the `HomeScreen` widget rebuilds or disposes before the user's selection is processed (e.g., due to a parent widget rebuild, navigation away, or setState elsewhere), `Navigator.of(context).pop()` and the subsequent `setState`/`startDownload` calls may fail silently or reference a stale/defunct context.

- **Dialog dismissal without selection:** If the user taps outside the dialog or presses the back button, `selectedQuality` will be `null`, and the function returns early at line 152-155 without starting a download. This is intentional but could confuse users who expect tapping the background to also start a default download.

- **Race condition with `mounted` checks:** The function has multiple `if (!mounted) return;` guards (lines 131, 150, 169). These are good defensive checks, but they also mean that if the widget becomes unmounted at any point during the flow (e.g., user navigates away), the download will never start — and there's no feedback to the user about why nothing happened.

- **`selectedQuality` scope:** The `selectedQuality` variable at line 211 is local to `_showQualitySelectionDialog`'s return value, not a class field. This is correct, but any exception or early return in the dialog builder could leave the variable in an unexpected state.

### Issue B: `_isDownloading` Flag Not Properly Reset on Failure

**Evidence:** Lines 175-206 in `home_screen.dart` (catch block of `_detectAndDownload`)

```dart
} catch (e, st) {
  debugPrint('HOME: _detectAndDownload catch - $e\n$st');
  ErrorHandler.logError(e, stackTrace: st);
  // ... error message selection ...
  if (mounted) {
    _showErrorDialog(message, errorType: errorType);
  }
} finally {
  if (mounted) {
    setState(() {
      _isDetecting = false;
      _isDownloading = false;  // <-- Only reset in finally block
    });
  }
}
```

**Potential Problem:** The `_isDownloading = false` reset only happens in the `finally` block (line 201). If an error occurs and `_showErrorDialog` is called, the error dialog appears, but `_isDownloading` is still `true` until the `finally` block runs. However, the more concerning issue is: **if the user taps "Get" again while a previous download is still in the `_isDownloading = true` state**, the `ElevatedButton` at line 472 has `onPressed: _isDetecting || _isDownloading ? null : _handleGetButton`, which disables the button. This prevents double-taps but also means if the user waits for the `finally` block to reset `_isDownloading`, they can retry. If the `finally` block doesn't run for some reason (e.g., async callback after dispose), the button stays disabled permanently.

### Issue C: No Visual Feedback During Quality Dialog

**Evidence:** Lines 209-261 in `home_screen.dart` (`_showQualitySelectionDialog`)

The quality selection dialog is a standard `AlertDialog` with no spinner or loading indicator. When the backend extraction takes time (YouTube extraction can take 5-15 seconds per the comment in `backend_api_client.dart` line 263), the user sees the paste link card, then after a delay the dialog appears with quality options. If the user taps a quality option immediately, the `onChanged` callback fires, but there's no visual confirmation that the selection was registered before the dialog closes and the download starts.

### Issue D: `_handleGetButton` Clipboard Check May Not Auto-Proceed

**Evidence:** Lines 319-331 in `home_screen.dart`

```dart
void _handleGetButton() async {
  await _checkClipboard();
  final url = _pasteLinkController.text.trim();
  if (url.isNotEmpty) {
    await _detectAndDownload();
  } else {
    _showSnackBar('Clipboard par link copy kiya gaya hai. Get click karein.');
  }
}
```

`_checkClipboard()` (lines 333-343) populates `_pasteLinkController` if a video URL is found in the clipboard, but it does **not** automatically call `_detectAndDownload()`. The user must explicitly tap "Get" again after the snack bar. This creates an extra step and potential confusion: the user pastes a link, sees the snack bar saying "Clipboard par link copy kiya gaya: URL", but then has to tap "Get" a second time to start the detection flow. If the user expects the app to auto-detect after pasting, this extra tap feels like a broken flow.

### Issue E: Continue Watching / Recent Downloads May Show Stale Data

**Evidence:** Lines 494-670 in `home_screen.dart`

The `_getContinueWatchingList()` (line 520) and `_getRecentDownloads()` (line 643) functions return empty lists by default (`return [];`), with comments indicating they'll be populated from Hive local database when downloads complete. If the Hive database is empty or has issues, users see "No continue watching" or "No recent downloads" even if they have completed downloads. This doesn't directly affect the paste/download flow, but it means the home section doesn't show any download history, which may make the app feel feature-light.

---

## 4. Root Cause Summary

Based on the code review and the user's confirmation that "backend se download successful thi" (backend download was successful), the problem is **entirely in the frontend/home screen flow**:

1. The quality selection dialog appears correctly after backend extraction
2. When the user selects a quality (e.g., 1080p), the `onChanged` callback should set `selectedQuality` and close the dialog
3. After the dialog closes, `startDownload()` should be called with the selected quality
4. **The issue occurs somewhere in steps 2-3** — likely due to context invalidation, timing issues with the `mounted` checks, or the `_isDownloading` state not properly transitioning

The fact that the user says "bass touch ho rha thaa lekin kuch nhii ho rha thaa" (only touch was happening, nothing was happening) suggests that the touch event is registered but the subsequent logic (setting state, closing dialog, starting download) is not completing properly.

---

## 5. Recommendations for Fix

Based on the project rules ("Koi bhi fix tab tak 'done' nahi jab tak wo UI mein user ko nazar na aaye"):

1. **Add a visible on-screen marker/status during the quality selection flow** — e.g., show "Selecting quality..." text or a small spinner below the "Get" button while the backend extracts video info and shows the dialog. This lets the user know the code is working.

2. **Add debug print statements** at key points in the flow:
   - `debugPrint('HOME: Quality selected: $selectedQuality')` after dialog closes
   - `debugPrint('HOME: Starting download with quality: $selectedQuality')` before `startDownload()`
   - `debugPrint('HOME: Download job result: $job')` after `startDownload()` returns

3. **Ensure `_isDownloading` reset is robust** — verify the `finally` block always runs, and consider adding a timer or watchdog to reset `_isDownloading` if it stays `true` for too long (e.g., >30 seconds).

4. **Add a retry mechanism** in the error dialog: currently the "Retry" button (line 300) calls `_detectAndDownload()` recursively. This could cause stack issues if many retries happen. Consider using a loop or limiting retry depth.

5. **Add a persistent offline/online banner** (already present at lines 369-385) but also add a "Download in progress" indicator somewhere visible on the home screen, per the rule: "Har fix mein ek chhota on-screen status/marker daalo (jaise loading screen par likha hua step ya error) taake user phone par dekh sake ke code chal raha hai."

6. **Do not create new files with `_new`, `_fixed`, `_final` suffixes** — per the rule "Ek waqt mein ek kaam. Nayi file, nayi screen ya duplicate (_new/_fixed/_final) mat banao." Instead, modify the existing `home_screen.dart` file directly.

7. **Verify the fix with `flutter run` on phone** before building APK — per the rule: "Pehle flutter run se phone par verify karwana."

---

## 6. Verification Checklist (to mark "done")

After fixing, confirm these visible signs on the phone:

- [ ] Quality selection dialog appears after pasting link and tapping "Get"
- [ ] When user selects 1080p (or any quality), the dialog closes and download starts
- [ ] A visible status marker appears (e.g., "Downloading at 1080p" or similar) on the home screen
- [ ] `_isDetecting` and `_isDownloading` flags reset properly after download completes/errors
- [ ] `git diff --stat` shows changes only to `home_screen.dart` (no new files)
- [ ] `flutter analyze lib` reports 0 errors
- [ ] Call chain from `main.dart` → `HomeScreen` → `_handleGetButton` → `_detectAndDownload` → quality dialog → `startDownload` all works end-to-end
- [ ] APK build and phone test successful

---

**Report End.** This file has been written to `F:\VidiMate-App\home_section.md` for the user's reference. No code changes have been made yet — per user request, only a report was generated.