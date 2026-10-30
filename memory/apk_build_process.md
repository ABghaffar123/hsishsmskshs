---
name: apk_build_process
description: Steps to build, trigger, and download the Flutter APK via GitHub Actions
metadata:
  type: project
---

## Workflow file
`.github/workflows/build-apk.yml` — triggers on `push` to `master`/`main` and via manual `workflow_dispatch`.

## Trigger (manual)
```bash
gh workflow run build-apk.yml --ref master
```
Run URL pattern: https://github.com/ABghaffar123/hsishsmskshs/actions/runs/<RUN_ID>

## View status (recent runs)
```bash
gh run list --repo ABghaffar123/hsishsmskshs --limit 5
gh run view <RUN_ID> --log-failed --repo ABghaffar123/hsishsmskshs
```

## Expected build steps
1. `actions/checkout@v4`
2. Java 17 (temurin)
3. `subosito/flutter-action@v2` (stable, cache: true)
4. `flutter pub get` (in `vidmate_app/`)
5. `flutter analyze`
6. `flutter build apk --release`
7. Upload `build/app/outputs/flutter-apk/app-release.apk` as artifact `app-release-apk`

## Known blocker (to resolve first)
The first builds **failed** because the GitHub repository only contained a **gitlink** to `vidmate_app` instead of the real source files. The `pubspec.yaml` lives at `vidmate_app/pubspec.yaml`, but nothing under `vidmate_app/` was pushed to GitHub except a submodule pointer.

### Fix to apply
1. Remove the nested repo metadata: `rm -rf vidmate_app/.git`
2. Untrack the gitlink: `git rm --cached -r vidmate_app`
3. Re-add the real files: `git add vidmate_app`
4. Commit: `git commit -m "Fix: Include actual vidmate_app source files..."`
5. Push: `git push`
6. Then re-trigger the workflow.

## Why
[[github_repo_name]]
