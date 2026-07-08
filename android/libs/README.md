# Android — Bidscube AppLovin MAX adapter resolution

This plugin wires **AppLovin MAX mediation** by default. The host app must contain:

`com.applovin.mediation.adapters.BidscubeMediationAdapter`

## Option A — Local adapter AAR (recommended for monorepo / air-gapped builds)

1. Build or copy a release adapter AAR from the Bidscube Android SDK repo, e.g.  
   `applovin-adapter/build/staged-aars/applovin-bidscube-max-adapter-full-video-1.2.10.aar`
2. Place it under **`android/libs/`** with a name containing `applovin-bidscube-max-adapter`, for example:
   - `applovin-bidscube-max-adapter-full-video-1.2.10.aar`

Gradle picks the first matching `applovin-bidscube-max-adapter*.aar` in `libs/`.

The adapter artifact pulls the matching Bidscube SDK runtime and AppLovin MAX SDK transitively.

## Option B — Maven

If no local adapter AAR is present, the plugin uses:

`com.bidscube:applovin-bidscube-max-adapter-full-video:1.2.10`

Publish or consume from Maven Central / `mavenLocal()` as needed.

## Do not use for MAX mediation

`com.bidscube:bidscube-sdk` **alone** does not ship `BidscubeMediationAdapter`. Do not place only `bidscube-sdk-*.aar` in `libs/` when integrating AppLovin MAX.

## Verify adapter presence

From the Flutter app:

```bash
cd android && ./gradlew :app:dependencies | grep -i bidscube
```

From this plugin module:

```bash
./gradlew verifyBidscubeMaxAdapter
```

Inspect the release APK / merged dex for `BidscubeMediationAdapter`.

## Flutter default adapter mode

The Flutter package defaults to **`full-video`** (banner, interstitial, rewarded with IMA VAST). Android exposes four adapter artifacts in the native repo; Flutter does not expose those modes in Dart — pick one artifact here for the whole app.
