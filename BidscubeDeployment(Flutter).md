# Bidscube SDK — Deployment Guide for Flutter

This document explains how to prepare, version, test, and publish the Bidscube Flutter plugin/package to pub.dev.

Checklist (high level)
- [ ] Update `pubspec.yaml` version and metadata
- [ ] Update `CHANGELOG.md` / release notes
- [ ] Run static analysis, formatting, and tests
- [ ] Build example app(s) for target platforms (Android / iOS as applicable)
- [ ] Commit and tag the release in git
- [ ] Publish to pub.dev (dry-run then real publish)
- [ ] Create GitHub release and update docs

Prerequisites
- Dart and Flutter SDK installed and on PATH. Use the same SDK versions the project supports.
- An account on https://pub.dev with permission to publish this package (owner/publisher).
- If publishing iOS artifacts or building iOS example, macOS with Xcode and CocoaPods is required.
- Git configured with push access to the repository.

Quick notes on which command to use
- Use `flutter pub publish` for Flutter plugins/packages that contain platform code and examples.
- `dart pub publish` works for pure Dart packages. For this plugin repo use `flutter pub publish`.

1) Update version and metadata
- Open `pubspec.yaml`.
- Bump the `version:` field. Follow pub version format: MAJOR.MINOR.PATCH+BUILD (build number is optional).
  - Example: `version: 1.2.3` -> `version: 1.2.4` if you're releasing a patch.
- Update other metadata if needed (homepage, repository, authors, environment constraints).

PowerShell example:

```powershell
# show current version
Select-String -Path pubspec.yaml -Pattern "^version:" -Context 0,0

# open in your editor of choice (example uses code)
code pubspec.yaml
```

2) Update CHANGELOG and release notes
- Add an entry for the new version at the top of `CHANGELOG.md` using the "Keep a Changelog" style (recommended).
- Include short, accurate notes about what's changed (bug fixes, features, breaking changes).

3) Run preflight checks (static analysis, tests, formatting)
- Run package get, analyze, and tests. Fix any issues before publishing.

PowerShell commands:

```powershell
# fetch dependencies
flutter pub get

# run static analysis
flutter analyze

# run tests
flutter test

# optional: format codebase
flutter format .
```

4) Build example app(s)
- Ensure example builds cleanly for the platforms you support.
- Android build (works on any OS with Android SDK):

```powershell
cd example
flutter pub get
flutter build apk --release
# or build appbundle
flutter build appbundle --release
cd ..
```

- iOS build (macOS required):

```powershell
cd example
flutter pub get
flutter build ios --release
cd ..
```

If you cannot build iOS (not on macOS), at minimum run a code analysis and test; note that you should still ensure CI covers macOS/iOS builds.

5) Dry-run publish (highly recommended)
- Always run a dry-run first to catch pub-specific issues.

```powershell
# from repository root
flutter pub publish --dry-run
```

Fix any issues reported by the dry-run (missing assets, invalid YAML, missing authors, license, etc.).

6) Commit, tag, and push
- Commit changes to `pubspec.yaml`, `CHANGELOG.md`, and any other updated files.
- Create an annotated git tag for the release and push commits + tags.

PowerShell example:

```powershell
# stage changes
git add pubspec.yaml CHANGELOG.md

# create a commit
git commit -m "chore(release): bump version to x.y.z" # replace with the actual version

# create annotated tag
git tag -a vX.Y.Z -m "Release vX.Y.Z" # replace with actual version

# push to remote
git push origin HEAD
git push origin vX.Y.Z
```

7) Publish to pub.dev
- Publish from the repository root. You will be prompted to confirm.

```powershell
flutter pub publish
```

Notes:
- If you're not logged in, `flutter pub publish` will prompt you to sign in to your Google account used on pub.dev.
- If your package is managed under a pub.dev "publisher", make sure your account is an owner or member with publisher rights.

8) Post-publish tasks
- Create a GitHub release with the tag `vX.Y.Z` and paste release notes from `CHANGELOG.md`.
- Update `README.md` or any docs that reference the version if needed.
- Update the project's issue board or milestone to reflect the deployed version.
- Verify the package page on https://pub.dev shows the new version and the metadata is correct.

9) Rollback (rare)
- If you must unpublish a release, note that pub.dev only allows unpublishing within a limited time window after publishing and has restrictions on packages with other dependents. Typically prefer publishing a new patch release that reverts the bad change.
- See pub.dev unpublish policy: https://dart.dev/tools/pub/publishing

Preflight checklist (detailed)
- [ ] pubspec version updated
- [ ] CHANGELOG.md updated
- [ ] All tests pass: `flutter test` (and platform tests if any)
- [ ] `flutter analyze` returns no new issues
- [ ] Example app builds for Android
- [ ] If applicable, example app builds for iOS (CI/macOS)
- [ ] Dry-run publish succeeds
- [ ] Commit and push with annotated tag

Troubleshooting
- Invalid or missing files reported by dry-run: verify `pubspec.yaml` `assets:` and `publish_to:` settings.
- Missing README or LICENSE: pub.dev requires a LICENSE file and a README is strongly recommended.
- Authentication issues: run `flutter pub login` or visit pub.dev in a browser and sign in to ensure your account is active.

Advanced / CI recommendations
- Add a GitHub Action that runs `flutter analyze`, `flutter test`, and `flutter build` for the example on PRs and main branch.
- Add a release workflow that can tag a release and optionally publish to pub.dev using an API token or by using the `dart pub token` workflow in CI. (Be careful with secret handling.)

References
- Publishing packages: https://dart.dev/tools/pub/publishing
- Pub.dev publisher documentation: https://pub.dev/publishers


---

If you'd like, I can also:
- Update `CHANGELOG.md` with a templated release entry.
- Create a GitHub Actions workflow that runs the preflight checks automatically.
- Add a small `scripts/release.ps1` PowerShell helper to automate version bumping, tagging, and publish (interactive confirmation still recommended).