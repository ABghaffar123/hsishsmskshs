# VidiMate Project — Full Folder & Files Verification Prompt

> **Goal:** Claude Code se project ke **har folder aur har file** ki full details leni hai — taake pata chale koi **duplicate file** hai ya koi **missing file** hai. Ye verification APK build se pehle zaroori hai.

---

## INSTRUCTION (Claude Code ko ye do)

Mere project ke **har folder aur har file** ki complete details nikalo aur analyze karo:

1. **Har folder ka purpose** — wo folder kis liye hai, kya role hai project mein
2. **Har file ka purpose** — wo file kis liye hai, kya karti hai, kis se connected hai
3. **Duplicate check** — koi 2 files same kaam kar rahi hain? (e.g. 2 settings models, 2 API clients, 2 theme controllers)
4. **Missing check** — koi zaroori file missing hai? (e.g. import ki hui file exist nahi karti, route register nahi hua, service missing)
5. **Orphan check** — koi file hai jo kahin import/use nahi hoti (dead code)
6. **Import chain verify** — har file ke imports valid hain? koi broken import to nahi?

---

## SCAN SCOPE

Ye folders/files scan karo:

- `lib/` (saare subfolders: features, core, database, services, etc.)
- `backend/` (routes, services, config, main)
- `android/` (manifest, gradle, kotlin files)
- `assets/` (images, fonts, icons)
- Root files: `pubspec.yaml`, `README.md`, `.gitignore`, etc.

---

## OUTPUT FORMAT

Har file ke liye ye table banao:

| File Path | Purpose | Used By | Duplicate? | Missing? | Orphan? | Status |
|---|---|---|---|---|---|---|
| `lib/main.dart` | App entry point, Hive init, theme load | router.dart | No | No | No | ✅ OK |
| `lib/database/repositories.dart` | Hive repos | settings_screen | Yes (dual w/ SettingsModel) | No | No | ⚠️ Duplicate |
| ... | ... | ... | ... | ... | ... | ... |

Har folder ke liye short summary do:
- Folder name
- Total files
- Purpose (1-2 lines)
- Issues found (duplicates/missing/orphans)

---

## FINAL REPORT

Report ko **`project_structure.md`** file mein save karo with ye sections:

1. **Project Overview** — total folders, total files, tech stack
2. **Folder-wise Breakdown** — har folder ka purpose + files list
3. **File-wise Details** — har file ka purpose + used by + status
4. **Duplicates Found** — list + recommendation (kaunsa rakhna, kaunsa delete)
5. **Missing Files Found** — list + recommendation (kya create karna hai)
6. **Orphan Files Found** — list + recommendation (delete ya wire karo)
7. **Import Chain Issues** — broken imports, circular deps
8. **APK Build Readiness** — kya blockers hain, kya clean hai
9. **Recommendations** — next steps

---

## CONSTRAINTS

- Koi file delete/create mat karo — sirf **scan + report** karo
- Sirf real code se proof do (file path + line numbers)
- Duplicate/missing/orphan ka **concrete evidence** do (import statements, usage references)
- Report `project_structure.md` mein save karo
- APK build se pehle ye verification complete honi chahiye

---

## DELIVERABLE

1. Full folder/file scan (table format)
2. Duplicates/missing/orphans ki list (evidence ke sath)
3. `project_structure.md` report file
4. APK build readiness verdict
