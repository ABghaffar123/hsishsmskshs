# VidiMate — Black Screen Debug Prompt

App open hote hi BLACK SCREEN aa rahi hai (kuch bhi render nahi hota). Pehle wale fixes ke baad bhi same issue hai. **Andha fix mat karo — pehle ROOT CAUSE nikalo.**

---

## STEP 1: ROOT CAUSE NIKALO (sabse pehle)

```bash
cd F:\VidiMate-App\vidmate_app
flutter clean
flutter pub get
flutter run --verbose
```

Terminal mein **red error / stack trace** dhundo — black screen ka asli reason wahi hoga. Stack trace ka pehla error line + file name + line number report karo.

---

## STEP 2: YE 5 JAGAH CHECK KARO (priority order)

### 1. main.dart — blocking init
- `Hive.init`, `ThemeController.instance.loadTheme()`, `BackendApiClient.initialize()`, `NotificationService.init()` — kya koi `await` ke sath crash ho raha hai?
- Har init ko try-catch mein wrap karo, error log karo, app ko phir bhi open hone do (graceful degradation)

### 2. Hive boxes
- Koi box already open / corrupt? `getSettingsBox()` ya `initHive()` mein `StateError: Box already open` type error?
- Har box open ko try-catch mein wrap karo

### 3. Notification init (Android 13+)
- `POST_NOTIFICATIONS` permission ke bina notification init crash to nahi kar raha?
- Notification init ko non-blocking + try-catch karo

### 4. GoRouter initial route
- `/` route aur `main_screen.dart` build mein koi exception?
- Router ke redirect/builder mein koi null/crash?

### 5. Home/Discover naye try-catch
- Mock fallback try-catch mein koi variable/type/undefined error?
- `MockDiscoverData` / `MockData` references sahi hain?

---

## STEP 3: FIX RULES

- Pehle **error log ka exact stack trace** report karo
- Sirf usi file/line ko fix karo jahan error aa raha hai
- Har fix ke baad `flutter run` karke confirm karo ke black screen gaya
- Git commit har fix ke baad

---

## STEP 4: DELIVERABLE

1. Exact error/stack trace (root cause)
2. Fix (file + line + code)
3. `flutter run` output — app home screen tak pahunchne ka proof
4. Git commit hash
