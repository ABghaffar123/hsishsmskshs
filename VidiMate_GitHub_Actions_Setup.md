# VidiMate — GitHub Actions Cloud Build Setup

## Project
`F:\VidiMate-App\vidmate_app`

My laptop has 4GB RAM. Build APKs and run Android Emulator tests on GitHub-hosted runners, not locally. Follow the project's `CLAUDE.md` rules.

## 1. Inspect first
- Check project structure, Git status/remotes, Flutter and Android build configuration, dependencies, and existing tests.
- Identify confirmed build issues and propose minimal fixes.
- Inspect `.gitignore` and flag API keys, credentials, signing keys, personal data, and other secrets.
- Do not run a local APK build.

## 2. Prepare APK workflow
Create `.github/workflows/android.yml` with:
- GitHub-hosted Ubuntu runner.
- Compatible Flutter, Java, and Android SDK setup.
- Dependency caching where appropriate.
- `flutter pub get` and practical lightweight validation.
- Debug APK build and upload as a downloadable Actions artifact.
- Manual `workflow_dispatch` and pushes to `main`.
- Concurrency controls to reduce duplicate/obsolete runs.
- A reasonable timeout.
- No emulator tests in the normal APK workflow.

## 3. Prepare separate emulator workflow
Create `.github/workflows/android-emulator.yml`:
- Manually triggered only.
- GitHub-hosted runner and headless Android Emulator.
- Prefer Android API 31 if compatible.
- Use a suitable maintained emulator action.
- Run only valid existing automated tests; do not invent tests.
- Do not trigger this workflow during setup.
- Explain expected runtime/resource costs.

## 4. GitHub repository and upload approval
- Check whether a remote repository already exists.
- If none exists, prepare to create a **private** repository named `VidiMate-App`.
- Before creating a remote repository, pushing code, or triggering any remote workflow, show me the planned actions and files to be uploaded, flag potential secrets, and ask for my explicit approval.
- Never expose authentication tokens or commit secrets.
- Never force-push or rewrite Git history.

## 5. Preserve functionality and verify honestly
Preserve the existing Flutter UI, Kotlin download engine, platform channels, background downloads, notifications, and other functionality. Avoid speculative dependency upgrades and unrelated rewrites. Review workflow configuration and run lightweight checks only. Do not claim a successful build until a real GitHub Actions run succeeds.

## 6. Report back
List files created/modified, confirmed issues, planned repository/upload steps, how to run the APK workflow and download its artifact, how to run emulator tests separately, and anything still unverified.

**Do not create a remote repository, push code, or start a GitHub Actions run until I explicitly approve.**
