# VidiMate Settings Section — Bug Fix Prompt

> **Claude ko ye prompt do — Settings section ke saare errors/bugs fix karne ke liye.**

---

## CONTEXT

Settings section mein multiple bugs/gaps hain (verification report dekho: `settings.md`). Sirf **Theme** fully functional hai, baaki settings ya display-only hain, ya stored-but-unenforced, ya stubs hain.

**Project:** VidiMate APK (Flutter + FastAPI backend)  
**Version:** 1.2.4+4 (pubspec)  
**Files:** `settings_screen.dart`, `theme_controller.dart`, `build_config.dart`, `backend_api_client.dart`, `main.dart`, `backend/config.py`

---

## BUGS TO FIX (Priority Order)

### BUG 1: Stale Version Display (HIGH)
- **Problem:** `BuildConfig.fullVersion` = `1.0.33+29` hardcoded, lekin `pubspec.yaml` = `1.2.4+4`. Settings → App Info galat version dikhata hai.
- **Fix:** `build_config.dart` mein version ko `pubspec.yaml` se read karna (ya manually `1.2.4+4` par sync karna). Backend `config.py` ka `APP_VERSION` bhi `1.2.4+4` par update karna.
- **File:** `lib/core/build_config.dart`, `backend/config.py`

### BUG 2: `/api/updates` Endpoint Missing (HIGH)
- **Problem:** `BackendApiClient.checkUpdates()` `/api/updates` call karta hai lekin backend mein endpoint defined nahi — 404 aata hai.
- **Fix:** Backend mein `routes/updates.py` banao with `GET /api/updates` endpoint jo current version return kare. Ya frontend se `checkUpdates` call hata do agar feature nahi chahiye.
- **File:** `backend/main.py` (router register), new `backend/routes/updates.py` ya `backend_api_client.dart`

### BUG 3: Wi-Fi Only Toggle Not Enforced (MEDIUM)
- **Problem:** `wifi_only` Hive mein save hota hai lekin `download_service.py` isko read nahi karta — download hamesha chalta hai.
- **Fix:** Download start se pehle connectivity check karo — agar `wifi_only=true` aur network mobile data par hai to download block/pause karo with user message.
- **File:** `backend/services/download_service.py`, `lib/services/backend_api_client.dart`

### BUG 4: Auto-Retry Toggle Not Enforced (MEDIUM)
- **Problem:** `auto_retry` save hota hai lekin backend/backend client read nahi karta — sirf frontend manual Retry button hai.
- **Fix:** Download fail hone par automatic retry logic add karo (max 3 attempts), `auto_retry` flag check karke.
- **File:** `backend/services/download_service.py` ya `lib/services/backend_api_client.dart`

### BUG 5: Notifications Toggle Stored-Only (MEDIUM)
- **Problem:** `notifications` save hota hai lekin koi notification channel/permission nahi — koi real notification nahi.
- **Fix:** `flutter_local_notifications` package add karo, permission request karo, download complete/fail par notification bhejo (agar toggle on ho).
- **File:** `pubspec.yaml`, `lib/main.dart`, `lib/services/notification_service.dart` (new), `lib/features/settings/presentation/settings_screen.dart`

### BUG 6: Autoplay Toggle Not Enforced (LOW)
- **Problem:** `autoplay` save hota hai lekin `video_player_screen.dart` isko read nahi karta.
- **Fix:** Player open hone par `autoplay` flag check karo — agar true ho to video auto-play start karo.
- **File:** `lib/features/player/presentation/video_player_screen.dart`

### BUG 7: Background Audio Not Implemented (LOW)
- **Problem:** `background_audio` save hota hai lekin `just_audio` initialize nahi, koi AudioService/Foreground service nahi.
- **Fix:** `just_audio_background` ya `audio_service` package add karo, player mein background audio support add karo.
- **File:** `pubspec.yaml`, `lib/main.dart`, `lib/features/player/presentation/video_player_screen.dart`

### BUG 8: PiP Mode Not Implemented (LOW)
- **Problem:** `pip_mode` save hota hai lekin koi pip package nahi.
- **Fix:** `floating` ya `pip_flutter` package add karo, player mein PiP button/logic add karo.
- **File:** `pubspec.yaml`, `lib/features/player/presentation/video_player_screen.dart`

### BUG 9: Vault PIN Not Enforced (MEDIUM)
- **Problem:** `vault_pin` save hota hai lekin koi PIN entry screen nahi, koi encrypt/decrypt nahi.
- **Fix:** PIN setup + entry screen banao, Private Vault tab access se pehle PIN verify karo.
- **File:** `lib/features/settings/presentation/settings_screen.dart`, `lib/features/library/presentation/library_screen.dart`, new `lib/features/privacy/pin_screen.dart`

### BUG 10: Fingerprint Not Implemented (LOW)
- **Problem:** `fingerprint` save hota hai lekin `local_auth` import nahi.
- **Fix:** `local_auth` package add karo, fingerprint auth flow add karo (Vault PIN ke sath combine).
- **File:** `pubspec.yaml`, `lib/features/privacy/pin_screen.dart`

### BUG 11: Clipboard Detection Toggle Dead (MEDIUM)
- **Problem:** `clipboard_detection` save hota hai lekin `home_screen.dart` `_checkClipboardOnAppOpen` unconditional clipboard read karta hai — toggle consult nahi hota.
- **Fix:** Clipboard read se pehle `clipboard_detection` flag check karo — agar false ho to read mat karo.
- **File:** `lib/features/home/presentation/home_screen.dart`

### BUG 12: Clear History Stub (MEDIUM)
- **Problem:** "Clear History" tap par sirf snack aata hai, koi confirmation dialog nahi, koi Hive deletion nahi.
- **Fix:** Confirmation dialog add karo, confirm par `searchHistory` box clear karo, success snack dikhao.
- **File:** `lib/features/settings/presentation/settings_screen.dart`

### BUG 13: Storage Info Hardcoded (LOW)
- **Problem:** "2.3 GB of 16 GB", "1.1 GB cache", "12 downloads" — sab hardcoded numbers.
- **Fix:** Real storage stats compute karo — `disk_space` package se total/free space, download dir se cache size, downloads box se count.
- **File:** `lib/features/settings/presentation/settings_screen.dart`, new `lib/services/storage_service.dart`

### BUG 14: Free up Space Incomplete (LOW)
- **Problem:** Sirf temp dir delete hota hai, real cache dirs nahi; sizes computed nahi hote.
- **Fix:** Cache dir + temp dir dono clean karo, deletion se pehle/after real size calculate karo.
- **File:** `lib/features/settings/presentation/settings_screen.dart`, `lib/services/storage_service.dart`

### BUG 15: Video Quality / Simultaneous Downloads / Playback Speed Display-Only (LOW)
- **Problem:** Teeno read-only tiles hain, koi actual picker nahi.
- **Fix:** 
  - Video Quality: dropdown/bottom-sheet picker (360p/720p/1080p/4K), selection Hive mein save
  - Simultaneous Downloads: stepper/dropdown (1-5), Hive mein save
  - Playback Speed: dropdown (0.5x-2.0x), Hive mein save, player mein apply
- **File:** `lib/features/settings/presentation/settings_screen.dart`, `lib/features/player/presentation/video_player_screen.dart`

### BUG 16: Toggle Snacks Missing (LOW)
- **Problem:** Toggles silently persist, koi visible acknowledgment nahi.
- **Fix:** Har toggle par snack dikhao ("Wi-Fi Only enabled/disabled", etc.) — theme tiles ki tarah.
- **File:** `lib/features/settings/presentation/settings_screen.dart`

### BUG 17: Dual Settings Models (MEDIUM)
- **Problem:** `HiveSettingsRepository` + `SettingsModel` exist karte hain lekin UI raw string keys use karta hai — do persistence paths, `backendUrl`/`apiKey` wire nahi hote.
- **Fix:** Ya to `SettingsModel` use karo uniformly (recommended), ya `SettingsModel`/`HiveSettingsRepository` delete karo aur raw keys ko standard banao. `backendUrl`/`apiKey` ko `BackendApiClient.initialize` se wire karo.
- **File:** `lib/database/repositories.dart`, `lib/database/hive_database.dart`, `lib/features/settings/presentation/settings_screen.dart`, `lib/main.dart`

### BUG 18: CORS Wide Open (LOW, dev-only)
- **Problem:** `allow_origins=["*"]` — security concern.
- **Fix:** Production ke liye specific origins allow karo ya CORS restrict karo.
- **File:** `backend/main.py`

---

## CONSTRAINTS

- **Home, Download, Discover, Library sections ko touch mat karo** — wo already PASS hain
- **Theme system ko touch mat karo** — wo fully working hai
- Koi unnecessary file create mat karo — sirf zaroori files
- `flutter analyze` clean rehna chahiye (0 errors)
- Har fix ke baad chhota verification note do (kya change hua, kaise verify hua)

---

## DELIVERABLE

1. Saare 18 bugs fix (priority order mein)
2. Har fix ka short note (file + kya change hua)
3. `flutter analyze` output (0 errors)
4. Updated `settings.md` report (naye status ke sath)
5. Version bump in `pubspec.yaml` + `BuildConfig` + `config.py` (sab sync)
