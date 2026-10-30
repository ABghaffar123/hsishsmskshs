# Plan: Fix Offline Detection + Version Sync

## Root Cause (verified in code)
1. `build_config.dart:11` → `defaultBackendUrl = ''` (empty)
2. `backend_api_client.dart:31` → `_offlineMode = baseUrl.isEmpty` → **`true`**
3. `main.dart:41-47` → `isOffline==true` → app **always** shows `OfflineHomeScreen` ("OFFLINE MODE" banner)
4. The offline state is **hardcoded from empty URL**, NOT detected from real network.
5. `build_config.dart:6-8` version (`1.0.11+3`) is **stale** vs `pubspec.yaml` (`1.0.12+4`).

## User's asks
- "app offline mode pe he" → fix offline detection
- "app khud detect kryy online he yha offline" → auto-detect real network connectivity
- "permissions khattam kroo" → clarify: INTERNET/ACCESS_NETWORK_STATE are normal perms (no prompt) — keep them. The issue is logic, not permissions.
- "version 1.0.11 he apk ka but current version to 1.0.12" → yes; APK was stale. Fix version sync + rebuild.

## Proposed Changes

### 1. `lib/core/build_config.dart`
- Bump version strings to match pubspec: `1.0.12`, `4`, `1.0.12+4`
- Add a `static const bool forceOfflineFirst = true;` flag documenting current offline-first intent

### 2. NEW file `lib/core/connectivity_probe.dart`
- Zero-dependency network detection using `dart:io` `InternetAddress.lookup('example.com')` with a 5s timeout.
- Function: `Future<bool> hasInternetAccess()` → true/false.
- No new pubspec dependency needed.

### 3. `lib/main.dart`
- Replace hardcoded offline decision:
  - OLD: `isOffline` decided at init from empty URL → always true
  - NEW: Always start in **online mode** (`MainScreen`), then `verifyBackendConnectivity()` probes real network AND backend. If unreachable, set `_offlineMode=true` and **rebuild** → switch to `OfflineHomeScreen`.
- Add on-screen debug marker: version banner + online/offline banner + `debugPrint('MAIN: <step>')` chain.
- Make `VidiMateApp` stateful so connectivity result triggers a rebuild (switch between MainScreen/OfflineHomeScreen) — currently it's a StatelessWidget reading a static; a rebuild is needed for the switch to reflect on screen.

### 4. `lib/services/backend_api_client.dart`
- `verifyBackendConnectivity()` is currently skipped when `isOffline==true` at init. With the fix, init sets `_offlineMode=false` (assume online), then `verifyBackendConnectivity()` actually runs and probes. No code change strictly needed beyond removing the early-return-on-empty condition — but keep it safe: if healthCheck throws, fall back to offline + mock data (already implemented).

## What NOT changing
- Permissions in `AndroidManifest.xml` stay (INTERNET + ACCESS_NETWORK_STATE are needed and are normal/no-prompt).
- No new pubspec dependencies (uses dart:io only).

## Verification (per CLAUDE.md rule #4)
- `flutter analyze lib` → 0 errors
- On-screen markers: version banner `v1.0.12+4`, `ONLINE`/`OFFLINE` banner, `DISCOVER`/`HOME` tab markers
- Build APK → version `1.0.12+4`, label `VidiMate`

## Order
build_config → connectivity_probe → backend_api_client → main → verify (analyze) → build APK → verify version+label in APK
