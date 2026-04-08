# Android — Bidscube SDK resolution

This plugin is **self-contained** when you ship the native SDK inside the repo.

## Option A — Local AAR (recommended for monorepo / air-gapped builds)

1. Copy the release AAR from your Bidscube Android SDK build, e.g.  
   `sdk/build/outputs/aar/sdk-release.aar`
2. Rename and place it under **`android/libs/`** with **`bidscube`** in the filename, for example:
   - `bidscube-sdk-release.aar`, or  
   - `bidscube-sdk-1.0.0.aar`

The Gradle script picks the first `*.aar` in `libs/` whose name contains `bidscube` (case-insensitive). If none is found, it falls back to Maven:

`com.bidscube:bidscube-sdk:1.0.0`

## Option B — Maven

Publish or consume `com.bidscube:bidscube-sdk` from Maven Central / `mavenLocal()` as before. No AAR in `libs/` is required.

## AppLovin MAX

The plugin adds **`com.applovin:applovin-sdk`** **13.0+** so native mediation adapters target the MAX **13.x** line without a separate AppLovin declaration in the host app (you may still add one; Gradle resolves a single version).

## Transitive libraries

Keep the `implementation` lines in [`build.gradle`](../build.gradle) aligned with the native Bidscube SDK’s Gradle catalog when you upgrade the AAR.
