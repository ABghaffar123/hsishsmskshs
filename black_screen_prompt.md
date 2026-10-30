# VidiMate — Black Screen Root Cause Analysis PROMPT

> **Claude Code ko ye prompt do — app open hone ke baad BLACK SCREEN kyun aa rahi hai, iski root cause report nikalni hai.**  
> **Report isko `black_screen_report.md` file mein save karna (ye PROMPT file nahi hai).**  
> **Rule:** Pehle root cause report, phir fix. Andha fix NAHI karna.

---

## PROBLEM

App open hote hi **BLACK SCREEN** aati hai — koi UI render nahi hota. Pehle wale fixes ke baad bhi same issue hai. Cleanup (structure-fix branch) ke baad bhi same.

---

## INSTRUCTION (Claude Code ko ye do)

Mere app mein black screen issue hai. Tum **root cause analysis report** banao aur **`black_screen_report.md`** file mein save karo. **Abhi fix mat karo — pehle sirf report banao.**

### Report (`black_screen_report.md`) mein ye sections hone chahiye:

1. **Exact Error / Stack Trace**
   - `flutter run --verbose` chalao
   - Black screen aane par terminal ka **poora red error + stack trace** copy karo
   - Pehla error line + file name + line number highlight karo

2. **Crash Point**
   - Error kis file / kis line par aa raha hai
   - Kaunsa function / init fail ho raha hai

3. **Root Cause Analysis**
   - Ye 5 jagah check karo aur har ek ka status report karo:
     - `main.dart` — Hive init / ThemeController.loadTheme / BackendApiClient.initialize / NotificationService.init — kya `await` crash kar raha hai?
     - Hive boxes — "Box already open" / corrupt box / adapter missing error?
     - Notification init — Android 13+ POST_NOTIFICATIONS permission issue?
     - GoRouter — `/` route ya main_screen.dart build exception?
     - Home/Discover naye try-catch — MockDiscoverData/MockData undefined reference ya type error?

4. **Suspect Files**
   - Jin files mein problem hai — unki list + line numbers

5. **Fix Plan**
   - Har problem ka exact fix (file + line + kya change hoga)
   - **Abhi implement mat karo — sirf plan likho**

6. **Verification Plan**
   - Fix ke baad kaise confirm hoga (flutter run output, home screen render proof)

---

## CONSTRAINTS

- **Sirf report banao — koi code change NAHI karna**
- Sirf real logs/se real code se proof do — koi assumption nahi
- Report **`black_screen_report.md`** file mein save karo
- Report complete hone ke baad mujhe dikhao, phir main approve karunga fix ke liye

---

## DELIVERABLE

1. `black_screen_report.md` file — complete root cause report
2. Exact stack trace + crash point
3. 5 areas ka status (main/Hive/Notification/Router/Try-catch)
4. Fix plan (implement NAHI karna)
5. Verification plan
