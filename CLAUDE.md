# Vidimate APK — Claude Code Project Rules

## Mandatory Skill Routing

Har task se pehle skills-index.md padho. Jo skills task se match karein sirf unki SKILL.md kholo aur follow karo.

Agar Ruflo ya ECC wali entry match ho to us ka folder khol kar sirf wahi skill(s) chuno jo task ke liye zaroori hain, baqi mat kholo. Match na ho to koi skill use mat karo.

**Skills Index path:** `F:\claude_code-Skills\.agents\skills\skills-index.md`

## Additional Rules

- Mujhe hamesha Urdu Roman mein bat krni hai.
- Jab bhi main koi kam karu, uske baare mein sath-sath batana hai taaki aap ko pata chale main kya kr raha hoon.
- **Jab bhi koi error/bug fix ho ya koi change ho, version number (pubspec.yaml) LAZMI update karna hai, phir APK build karna hai.**
- **Durable checkpoint system (Phase B from VIDIMATE_SESSION_RECOVERY_AND_FULL_APP_AUDIT.md):**
  1. Jab bhi main nayi session mein shuru karun, pehle work_state/CURRENT_STATE.md aur checklist padhoon.
  2. Validate checkpoint against current source/status se pehle.
  3. Har fix se pehle checkpoint savo (code changes, tests, long downloads, task transitions).
  4. Agar main stop ya pause karun, to next action record karo.
  5. Uncompleted operations ko UNKNOWN/incomplete mark karo.
  6. Pvail validated saved artifacts ko reuse karo (dup edits na karo).

## KNOWN PROBLEM (read first every session)

PROBLEM:
Pehle tum fixes likhte ho aur "fixed" bolte ho, magar phone par app (debug run aur APK dono mein) bilkul purani rehti hai. Isse bar bar user ka time zaya hua. Build pipeline theek hai (flutter clean + run karne par home screen ka test text phone par dikha), yaani masla ye hai ke jo code tum likhte ho wo ya to us screen/branch mein hota hi nahi jo user ko dikhti hai, ya kabhi chalta nahi.
JO PAKKA PATA CHALA HAS:
- Discover se video tap par PlayerScreen.stream() khulti hai (discover_screen.dart:132, :375).
- player_screen.dart mein 2 alag build paths hain: (1) loading Scaffold (line ~469) jahan sirf upar ki patti (Download/Play/Settings) aur neeche black skeleton dikhta hai, (2) ready hone par Stack (line ~539-545) jisme video surface, controls aur banners hain.
- Video kabhi ready nahi hota, isliye path (2) mein likha har fix (banners, controls, next/previous/more buttons) user ko kabhi nazar nahi aata.
- _videoSurfaceOpacity, _buildLandscapeControls, _handoverToMini, _showMoreMenu, _previousVideo, _nextVideo, _showComments likhe gaye hain magar ya to unused hain ya sirf ready path mein hain.
AB SE QAWAID:
1. Koi bhi fix tab tak "done" nahi jab tak wo UI mein user ko nazar na aaye. Naya code sirf ussi build path mein likho jo user ko abhi dikh raha hai (loading path ho to wahan), warna pehle mujhe batao.
2. Har fix mein ek chhota on-screen status/marker daalo (jaise loading screen par likha hua step ya error) taake user phone par dekh sake ke code chal raha hai.
3. Root cause pehle dhoondo (debugPrint('PLAYER: <step>') se poora flow), andaze se fix mat likho.
4. Kaam ke baad sirf ye saboot dikhao: git diff --stat, flutter analyze lib (0 errors), call chain main.dart se changed code tak (file:line), aur wo marker jo phone par dikhna chahiye. Saboot na ho to "NOT DONE" likho.
5. APK tab banao jab user kahe. Pehle flutter run se phone par verify karwana.
6. Ek waqt mein ek kaam. Nayi file, nayi screen ya duplicate (_new/_fixed/_final) mat banao.
