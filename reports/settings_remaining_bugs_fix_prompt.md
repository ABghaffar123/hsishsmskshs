# VidiMate Settings — Remaining 8 Bugs Fix Prompt (With Proof)

Settings section ke **8 pending bugs** fix karo. Sirf Settings related files touch karo — Home, Download, Discover, Library, Theme ko mat chhedo (wo pass hain).

**Fix karo:**

1. **Notifications (BUG 5)** — `flutter_local_notifications` package add karo, permission request karo, download complete/fail par notification bhejo (agar `notifications` toggle on ho)

2. **Background Audio (BUG 7)** — `just_audio_background` ya `audio_service` package add karo, player mein background audio support add karo

3. **PiP Mode (BUG 8)** — `floating` ya `pip_flutter` package add karo, player mein PiP button/logic add karo

4. **Vault PIN (BUG 9)** — PIN setup + entry screen banao, Private Vault tab access se pehle PIN verify karo

5. **Fingerprint (BUG 10)** — `local_auth` package add karo, fingerprint auth flow add karo (Vault PIN ke sath combine)

6. **Storage Info (BUG 13)** — Real storage stats compute karo — `disk_space` package se total/free space, download dir se cache size, downloads box se count (hardcoded 2.3 GB / 1.1 GB / 12 hatao)

7. **Free up Space (BUG 14)** — Cache dir + temp dir dono clean karo, deletion se pehle/after real size calculate karo

8. **CORS (BUG 18)** — `backend/main.py` mein `allow_origins=["*"]` hatao, specific origins allow karo

---

## PROOF REQUIREMENTS (MANDATORY)

Har fix ke liye **real proof** do — koi fake/assumed evidence nahi:

### 1. Git Diff
- Har changed file ka `git diff` output do (before/after)
- Ya `git diff --stat` + full diff paste karo
- Example format:
```
git diff lib/features/settings/presentation/settings_screen.dart
```

### 2. File Path + Line Numbers
- Har fix ka exact file path + line numbers do
- Example: `lib/features/settings/presentation/settings_screen.dart:145-160`

### 3. Code Snippet
- Har fix ka actual code snippet do (before/after ya sirf after)
- Copy-paste from real file, not conceptual

### 4. Package Addition Proof
- Agar naya package add kiya (`flutter_local_notifications`, `just_audio_background`, `local_auth`, etc.) to:
  - `pubspec.yaml` ka diff do
  - `flutter pub get` output do
  - Import statement ka proof do

### 5. Flutter Analyze Output
- Full `flutter analyze` output paste karo
- 0 errors hona chahiye (minor linting warnings theek karo)
- Command: `flutter analyze lib`

### 6. Backend Proof (agar backend change)
- `git diff backend/` output do
- Endpoint test ka proof (curl ya Postman screenshot description)
- Example: `curl -X GET http://localhost:8000/api/updates`

### 7. Updated Report
- `settings.md` update karo — saare 18 bugs ka final status
- Har bug ke sath proof link/reference do

---

## DELIVERABLE

1. Saare 8 bugs fix
2. Har fix ka **git diff** (mandatory)
3. Har fix ka **file path + line numbers**
4. Har fix ka **code snippet**
5. Package additions ka **pubspec diff + pub get output**
6. **flutter analyze** full output (0 errors)
7. Backend changes ka **git diff + endpoint test proof**
8. Updated `settings.md` report (18 bugs final status + proof references)
9. Version bump confirm (pubspec + BuildConfig + config.py sab 1.2.4+4)

**Rule:** Koi bhi fix bina git diff ke accept nahi hoga. Fake/assumed evidence = reject.
