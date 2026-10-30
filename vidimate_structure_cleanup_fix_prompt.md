# VidiMate Project — Structure Cleanup Fix Prompt (11 Items + Git Branch)

Project structure verification report ke mutabiq ye 11 fixes karo. Sirf listed files touch karo — baaki project ko mat chhedo.

---

## STEP 0: GIT BRANCH BANAO (PEHLE YE KARO)

```bash
git checkout -b structure-fix
git status
git add -A
git commit -m "baseline before structure fixes"
```

Rule: Har fix ke baad commit karo:
```bash
git add -A
git commit -m "fix: [kya fix hua]"
```

Agar kuch galat ho jaye to revert:
```bash
git checkout main
git branch -D structure-fix
```

---

## DELETE karo (5 items)

1. **vidmate_app/test_response.dart** — orphan, unknown purpose. Delete karo.

2. **lib/services/api_client.dart** — legacy duplicate API client, backend_api_client.dart already active hai (grep proof: no imports). Delete karo.

3. **lib/services/mock_backend.dart** — orphan, deprecated, self-referenced only. Delete karo.

4. **lib/core/app_settings.dart** — blank file (sirf comment). Delete karo (settings logic already hive_database.dart + repositories.dart mein hai).

5. **vidmate_app/libservices/ directory** — orphan directory, lib/ ke bahar, duplicate mock_backend.dart (432 bytes) contained, not imported. Poora directory delete karo:
```bash
rm -rf vidmate_app/libservices/
```

---

## VERIFY then DELETE/WIRE karo (3 files)

6. **lib/features/player/presentation/video_player_from_url.dart** — orphan (no imports). Agar zaroorat nahi to delete karo.

7. **lib/core/permission_manager.dart** — orphan (no imports). Wire karo (main.dart mein permissions ke liye) ya delete karo.

8. **lib/features/library/data/library_video_service.dart** — limited usage. Verify karo actively use ho raha hai ya nahi — agar nahi to delete karo.

---

## SYNC karo (1 item)

9. **Version mismatch** — teeno alag hain:
   - pubspec.yaml: 1.2.8+9
   - build_config.dart: 1.2.4+5
   - backend/config.py: 1.2.4+4

   Final version 1.2.8+9 decide karo aur build_config.dart + backend/config.py dono ko 1.2.8+9 par sync karo.

---

## VERIFY karo (1 item)

10. **Android manifest permissions + assets folders**
   - android/app/src/main/AndroidManifest.xml check karo:
     - WRITE_EXTERNAL_STORAGE
     - READ_EXTERNAL_STORAGE
     - POST_NOTIFICATIONS
     - INTERNET
   - Missing hon to add karo.
   - Assets folders check karo: assets/images/, assets/thumbnails/, assets/icons/, assets/videos/ — missing hon to create karo:
```bash
mkdir -p vidmate_app/assets/{images,thumbnails,icons,videos}
```

---

## IMPLEMENT karo (1 item)

11. **Mock data offline fallback (4 files)** — mock_continue_watching.dart, mock_data.dart, mock_discover.dart, mock_downloads.dart

Decision: Mock data DELETE NAHI karni — offline fallback banao, real backend priority.

Implementation:
- Har feature (Home/Discover/Downloads) mein pehle BackendApiClient se real data fetch karo
- Fail/offline hone par mock data fallback dikhaao
```dart
try {
  final data = await BackendApiClient.fetchX();
  // use real data
} catch (e) {
  // fallback to mock data
  final data = MockData.x;
}
```
- Har mock file ke top par comment: // OFFLINE FALLBACK — real backend se replace hota hai, fail par use hota hai

---

## PROOF REQUIREMENTS (MANDATORY)

Har fix ke liye real proof do — fake/assumed evidence reject:

1. Git Diff — har changed/deleted file ka git diff output
2. Git Commit — har fix ke baad commit hash + message
3. File Path + Line Numbers — exact location
4. Code Snippet — actual code (before/after)
5. Flutter Analyze — full output, 0 errors
6. Backend Proof (agar backend change) — git diff backend/ + endpoint test
7. Updated Report — project_structure.md update karo (saare 11 items ka final status + proof refs)

---

## DELIVERABLE

1. Git branch structure-fix created + baseline commit
2. 5 items delete (git diff + commit proof)
3. 3 files verify-then-delete/wire (git diff + code + commit)
4. Version sync (git diff + commit)
5. Manifest + assets verify (proof + commit)
6. Mock data fallback (code snippet + git diff + commit)
7. flutter analyze clean (0 errors)
8. Updated project_structure.md report (11 items final status + proof refs)

Rule: Koi bhi fix bina git diff + commit ke accept nahi hoga. Fake/assumed evidence = reject.

Safety: Har fix ke baad flutter analyze chalao — 0 errors hone chahiye. Ek ek fix karo, saare ek sath mat karo.

Final Goal: Cleanup ke baad APK build ready — flutter clean && flutter pub get && flutter analyze lib && flutter build apk --release
