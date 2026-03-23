# Android native SDK resolution

The Flutter plugin depends on **`com.bidscube:bidscube-sdk:1.0.0@aar`**.

- **After the artifact is on Maven Central**, no extra steps are needed.
- **Local / monorepo development**: publish the SDK to your machine’s Maven Local once (or after SDK changes):

```bash
cd <path-to-bidscube-android-sdk>
./gradlew :sdk:publishReleasePublicationToMavenLocal
```

Gradle is configured with `mavenLocal()` in the plugin’s `android/build.gradle` and in the example app’s `android/build.gradle.kts`.

Keep transitive versions in **`android/build.gradle`** aligned with your native Bidscube SDK’s Gradle version catalog.
