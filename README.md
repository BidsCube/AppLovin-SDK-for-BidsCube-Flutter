# Bidscube SDK for Flutter

Flutter plugin for **BidCube** demand on **Android** and **iOS**, with **AppLovin MAX** mediation. The plugin wires the native Bidscube runtime and MAX adapters (`BidscubeMediationAdapter` on Android, `ALBidscubeMediationAdapter` on iOS) into your Flutter app. For **direct** rendering (no MAX), use Dart APIs such as `getBannerAdView` / `getVideoAdView` / `getNativeAdView`.

**Repository:** https://github.com/bidscube/bidscube-sdk-flutter  

**Native iOS only (no Flutter):** https://github.com/BidsCube/AppLovin-SDK-for-BidsCube-iOS  

**Native Android only (no Flutter):** https://github.com/BidsCube/AppLovin-SDK-for-BidsCube-Android  

## Requirements

- **Flutter** 3.19+ / **Dart** 3.5+
- **Android** minSdk **24**
- **iOS** **15.0+** (matches `BidscubeSDKAppLovin`)
- **Android Gradle:** `com.bidscube:applovin-bidscube-max-adapter-full-video:1.2.10` (default) or local adapter AAR in [`android/libs/`](android/libs/)
- **iOS CocoaPods:** `BidscubeSDKAppLovin ~> 1.1.0` via this plugin’s podspec (or vendored XCFramework — see [`ios/Frameworks/`](ios/Frameworks/))
- **AppLovin MAX SDK:** 13.x (pulled transitively by native adapter pods/AARs)
- **Xcode** 14+ recommended

In MAX, put the **BidCube placement ID** in the custom network **App ID** field (see below).

### Version alignment

| Component | Version |
|-----------|---------|
| Flutter package (`bidscube_sdk_flutter`) | **1.2.3** |
| Android MAX adapter (default `full-video`) | **1.2.10** |
| iOS MAX pod (`BidscubeSDKAppLovin`) | **1.1.0** |
| AppLovin MAX SDK | **13.x** |

### Integration modes

**Direct SDK mode** — initialize with `BidscubeIntegrationMode.directSdk`, then use `getBannerAdView`, `getVideoAdView`, `getNativeAdView`, `requestAd`, and `showVideoAdFromVast`.

**AppLovin MAX mediation mode** — initialize with `BidscubeIntegrationMode.appLovinMaxMediation` and `useFlutterOnly: false` so the native Bidscube runtime is ready for MAX adapters. Load and show ads through **`applovin_max`** (or native MAX APIs). Do **not** call Bidscube Dart widget APIs in this mode.

### Diagnostics and logging

Search logs for **`[BidsCubeDiag]`** and the **`BidsCubeSDK`** logger name. `BidscubeSDK.initialize` applies `SDKConfig.enableLogging` / `enableDebugMode` to `SDKLogger` before starting the bridge.

### Custom video player (Flutter-only)

With **`useFlutterOnly: true`**, pass **`SDKConfigBuilder.customVideoPlayerBuilder((ctx) => YourWidget(...))`**. Does not apply to the native **`getVideoAdView`** PlatformView path.

### QA — VAST preview / end card (no backend)

[`QaVastFixtures`](lib/src/core/qa_vast_fixtures.dart) ships hardcoded VAST XML for local QA. Run the in-repo **`example/`** app (direct SDK / Flutter-only QA only).

The **AppLovin MAX mediation QA app** lives next to this repository as a sibling project: **`BidscubeFlutterAppLovinTestApp/`**.

---

## AppLovin MAX — installing

### Flutter (pub)

```yaml
dependencies:
  bidscube_sdk_flutter: ^1.2.3
  applovin_max: ^4.6.0   # MAX load/show from Dart; pin per your app
```

```dart
import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
import 'package:applovin_max/applovin_max.dart';
```

```bash
flutter pub get
cd ios && pod install && cd ..
```

### Mediation init (Flutter)

```dart
await BidscubeSDK.initialize(
  config: SDKConfig.builder()
      .integrationMode(BidscubeIntegrationMode.appLovinMaxMediation)
      .build(),
  useFlutterOnly: false,
);
```

Then initialize and drive ads with **AppLovin MAX** — not Bidscube widgets:

```dart
// Example only. Use real ad unit IDs from the AppLovin MAX dashboard.
await AppLovinMAX.initialize('YOUR_APPLOVIN_SDK_KEY');

AppLovinMAX.createBanner('YOUR_MAX_BANNER_AD_UNIT_ID', AdViewPosition.bottomCenter);
AppLovinMAX.createMRec('YOUR_MAX_MREC_AD_UNIT_ID', AdViewPosition.bottomCenter);
AppLovinMAX.loadInterstitial('YOUR_MAX_INTERSTITIAL_AD_UNIT_ID');
AppLovinMAX.showInterstitial('YOUR_MAX_INTERSTITIAL_AD_UNIT_ID');
AppLovinMAX.loadRewardedAd('YOUR_MAX_REWARDED_AD_UNIT_ID');
AppLovinMAX.showRewardedAd('YOUR_MAX_REWARDED_AD_UNIT_ID');
```

> **Warning:** Do not call `BidscubeSDK.getBannerAdView`, `getVideoAdView`, `getNativeAdView`, `requestAd`, or `showVideoAdFromVast` in AppLovin MAX mediation mode. Those APIs are for **direct SDK mode** only.

### iOS `Podfile` (host app)

```ruby
platform :ios, '15.0'
use_frameworks!
```

Let `flutter_install_all_ios_pods` pull `bidscube_sdk_flutter`. The plugin depends on **`BidscubeSDKAppLovin`** (~> 1.1.0), which pulls `AppLovinSDK` and the Bidscube runtime. **Do not** add duplicate Bidscube pods unless you intentionally override versions.

For a **Swift/iOS-only** app (no Flutter):

```ruby
pod 'BidscubeSDKAppLovin', '1.1.0'
```

### Android

No extra Gradle lines are required in the host app when this plugin is the Bidscube entry point. The plugin applies:

`com.bidscube:applovin-bidscube-max-adapter-full-video:1.2.10`

Verify the merged app contains `com.applovin.mediation.adapters.BidscubeMediationAdapter`:

```bash
cd android && ./gradlew :app:dependencies | grep -i bidscube
```

From the plugin module: `./gradlew verifyBidscubeMaxAdapter`

Use **core desugaring** in the host app if your stack already requires it (see [`example/android/app/build.gradle.kts`](example/android/app/build.gradle.kts)).

---

## MAX Dashboard

Follow AppLovin’s guide for custom SDK networks:  
[Integrating custom SDK networks](https://support.axon.ai/en/max/mediated-network-guides/integrating-custom-sdk-networks/)

1. Open your app in the **AppLovin MAX** dashboard.  
2. **MAX → Mediation → Manage → Networks** → add a **Custom** network:  
   - **Network type:** SDK  
   - **Name:** Bidscube (or your label)  
   - **Android adapter class:** `com.applovin.mediation.adapters.BidscubeMediationAdapter`  
   - **iOS adapter class:** `ALBidscubeMediationAdapter`  
3. **MAX → Mediation → Manage → Ad Units** — enable Bidscube on each ad unit that should use it.

### MAX parameters

| Field | Value |
|--------|--------|
| **Android adapter class** | `com.applovin.mediation.adapters.BidscubeMediationAdapter` |
| **iOS adapter class** | `ALBidscubeMediationAdapter` |
| **App ID** | BidCube **placement ID** |
| **Placement ID** | Optional |
| **Server parameters** (optional) | `request_authority` or `ssp_host` |

---

## Supported ad formats

**Supported through AppLovin MAX mediation:**

- **Android:** depends on the selected native Android adapter artifact (Flutter default: `full-video` → banner, interstitial, rewarded with IMA VAST; native MAX not supported on lite adapter).
- **iOS:** Banner, MREC, Interstitial, Rewarded via `BidscubeSDKAppLovin` 1.1.0.
- **Native MAX:** not supported unless the native Android/iOS adapters implement real native asset mapping (not advertised for current releases).

**Direct SDK mode:**

- Flutter direct widgets may support banner (320×50 default), video (320×180 default), and native (320×250 default) views depending on platform implementation.
- MREC is not a separate direct widget API; use banner sizing or MAX for MREC inventory.

For MAX mediation, ad sizing is owned by **AppLovin MAX**, not Bidscube Dart widgets.

---

## Direct SDK (no MAX)

Default integration mode: `BidscubeIntegrationMode.directSdk`. After `BidscubeSDK.initialize(...)`, use `getBannerAdView`, `getVideoAdView`, `getNativeAdView` and `AdCallback`. Optional: `onAdRenderOverride(placementId, adm, position)` for custom rendering.  
**Web / desktop:** `useFlutterOnly: true` — HTTP/WebView path only; no native bridge.

---

## Vendored native binaries (optional)

- **Android:** `applovin-bidscube-max-adapter-*.aar` in [`android/libs/`](android/libs/) — [`android/libs/README.md`](android/libs/README.md)  
- **iOS:** `*.xcframework` in [`ios/Frameworks/`](ios/Frameworks/) — [`ios/Frameworks/README.md`](ios/Frameworks/README.md). Vendored runtime-only frameworks do **not** include `ALBidscubeMediationAdapter`; prefer the `BidscubeSDKAppLovin` pod for MAX QA.

---

## Troubleshooting

- **Ads do not load:** confirm **App ID** is the correct BidCube **placement ID**.  
- **SSP override:** use only host or `host:port` in `request_authority` / `ssp_host`.  
- **Custom network not found:** class names must match exactly (`ALBidscubeMediationAdapter` / `BidscubeMediationAdapter`).  
- **Build:** `flutter clean`, `pod install`, match Flutter/Dart and adapter versions.

---

## Sample apps

### In-repo `example/` (direct SDK / Flutter-only QA)

```bash
cd example && flutter pub get && flutter run
```

The in-repo **`example/`** is for direct SDK and Flutter-only / VAST QA — not for full AppLovin MAX mediation QA.

### Sibling MAX test app

```text
workspace/
  AppLovin-SDK-for-BidsCube-Flutter/
  BidscubeFlutterAppLovinTestApp/
```

See [`../BidscubeFlutterAppLovinTestApp/README.md`](../BidscubeFlutterAppLovinTestApp/README.md).

---

## Validation

```bash
./scripts/validate-package.sh
```

Release archive (no `.git/`, `__MACOSX/`, or build artifacts):

```bash
cd AppLovin-SDK-for-BidsCube-Flutter
git archive --format=zip --output ../AppLovin-SDK-for-BidsCube-Flutter-release.zip HEAD
```

Verify the archive is clean:

```bash
unzip -l ../AppLovin-SDK-for-BidsCube-Flutter-release.zip | grep -E '(^|/)(\.git|build/|\.dart_tool/|__MACOSX|\.DS_Store|/\._|pubspec\.lock$|\.flutter-plugins-dependencies$)' && exit 1 || true
```

See [`.pubignore`](.pubignore) for `dart pub publish` exclusions.

---

## License

**MIT.** See [`LICENSE`](LICENSE).

## Version

**Bidscube Flutter SDK 1.2.3** (see [`pubspec.yaml`](pubspec.yaml), [`CHANGELOG.md`](CHANGELOG.md)).

Maintainers: [`RELEASE.md`](RELEASE.md) · `./scripts/validate-package.sh`
