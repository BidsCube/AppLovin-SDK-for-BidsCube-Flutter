# Bidscube SDK for Flutter

Flutter plugin for **BidCube** demand on **Android** and **iOS**, with **AppLovin MAX** mediation. The plugin wires the native Bidscube runtime and MAX adapters (`BidscubeMediationAdapter` on Android, `ALBidscubeMediationAdapter` on iOS) into your Flutter app. For **direct** rendering (no MAX), use Dart APIs such as `getBannerAdView` / `getVideoAdView` / `getNativeAdView`.

**Repository:** https://github.com/bidscube/bidscube-sdk-flutter  

**Native iOS only (no Flutter):** https://github.com/BidsCube/AppLovin-SDK-for-BidsCube-iOS  

## Requirements

- **Flutter** 3.19+ / **Dart** 3.5+
- **Android** minSdk **24**
- **iOS** **13.0+**
- **CocoaPods:** resolved via the plugin’s [`ios/bidscube_sdk_flutter.podspec`](ios/bidscube_sdk_flutter.podspec) — `AppLovinSDK` **~> 13.0** and Bidscube native (vendored `ios/Frameworks/*.xcframework` **or** pod `bidscubeSdk`)
- **Gradle:** `AppLovinSDK` **13.x** + Bidscube AAR (see [`android/build.gradle`](android/build.gradle)); optional local AAR in [`android/libs/`](android/libs/)
- **Xcode** 14+ recommended

In MAX, put the **BidCube placement ID** in the custom network **App ID** field (see below).

---

## AppLovin MAX — installing

### Flutter (pub)

```yaml
dependencies:
  bidscube_sdk_flutter: ^1.0.3
  applovin_max: ^4.6.0   # MAX load/show from Dart; pin per your app
```

```dart
import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
```

```bash
flutter pub get
cd ios && pod install && cd ..
```

### iOS `Podfile` (host app)

Use at least:

```ruby
platform :ios, '13.0'
use_frameworks!
```

Let `flutter_install_all_ios_pods` pull `bidscube_sdk_flutter` — **do not** add a second Bidscube pod target for the same runtime unless you know you need an override (avoid duplicate symbols).

**CocoaPods (parity with standalone iOS SDK):** the consolidated iOS product is **`BidscubeSDKAppLovin`** (runtime + adapter). In Flutter, that stack is normally supplied through this plugin’s podspec; for a **Swift/iOS-only** app use:

```ruby
pod 'AppLovinSDK', '>= 13.0.0', '< 14.0'
pod 'BidscubeSDKAppLovin', '1.0.3'
```

Then `pod install` and open **`.xcworkspace`**.

### Android

No extra Gradle lines are required in the app if the plugin is the only Bidscube entry point; the plugin applies `com.applovin:applovin-sdk` and Bidscube AAR/Maven. Use **core desugaring** if your app already does (see [`example/android/app/build.gradle.kts`](example/android/app/build.gradle.kts)).

### Mediation init (Flutter)

```dart
await BidscubeSDK.initialize(
  config: SDKConfig.builder()
      .integrationMode(BidscubeIntegrationMode.appLovinMaxMediation)
      .build(),
  useFlutterOnly: false,
);
```

Then use **MAX** APIs (`applovin_max` or platform channels). Do **not** use Dart `getBannerAdView` / `getVideoAdView` / `getNativeAdView` in `appLovinMaxMediation` mode.

---

## MAX Dashboard

Follow AppLovin’s guide for custom SDK networks:  
[Integrating custom SDK networks](https://support.axon.ai/en/max/mediated-network-guides/integrating-custom-sdk-networks/)

1. Open your app in the **AppLovin MAX** dashboard.  
2. **MAX → Mediation → Manage → Networks** → add a **Custom** network:  
   - **Network type:** SDK  
   - **Name:** Bidscube (or your label)  
   - **Android adapter class:** `BidscubeMediationAdapter`  
   - **iOS adapter class:** `ALBidscubeMediationAdapter`  
3. **MAX → Mediation → Manage → Ad Units** — enable Bidscube on each ad unit that should use it.

### MAX parameters

| Field | Value |
|--------|--------|
| **Android adapter class** | `BidscubeMediationAdapter` |
| **iOS adapter class** | `ALBidscubeMediationAdapter` |
| **App ID** | BidCube **placement ID** (MAX still labels this “App ID”; for this network it must be the placement ID) |
| **Placement ID** | Optional; leave empty unless your MAX setup needs a second value |
| **Server parameters** (optional) | `request_authority` or `ssp_host` — SSP host or `host:port` (normalized like standalone `adRequestAuthority`) |

If `request_authority` or `ssp_host` is set, the adapter uses it as the ad request authority.

---

## Supported ad formats

Banner, MREC, Interstitial, Rewarded, Native (per native adapter capabilities).

---

## Direct SDK (no MAX)

Default integration mode: `BidscubeIntegrationMode.directSdk`. After `BidscubeSDK.initialize(...)`, use `getBannerAdView`, `getVideoAdView`, `getNativeAdView` and `AdCallback`. Optional: `onAdRenderOverride(placementId, adm, position)` for custom rendering.  
**Web / desktop:** `useFlutterOnly: true` — HTTP/WebView path only; no native bridge.

---

## Vendored native binaries (optional)

- **Android:** `*bidscube*.aar` in [`android/libs/`](android/libs/) — [`android/libs/README.md`](android/libs/README.md)  
- **iOS:** `*.xcframework` in [`ios/Frameworks/`](ios/Frameworks/) — [`ios/Frameworks/README.md`](ios/Frameworks/README.md)

---

## Troubleshooting

- **Ads do not load:** confirm **App ID** is the correct BidCube **placement ID**.  
- **SSP override:** use only host or `host:port` in `request_authority` / `ssp_host`.  
- **Custom network not found:** class names must match exactly (`ALBidscubeMediationAdapter` / `BidscubeMediationAdapter`).  
- **Native:** if your setup uses a native-specific local parameter, set `is_native = true` where applicable.  
- **Build:** `flutter clean`, `pod install`, match Flutter/Dart and adapter versions.

---

## Runtime behavior (Flutter + MAX)

Call **`BidscubeSDK.initialize`** once at startup with **`appLovinMaxMediation`** and **`useFlutterOnly: false`** so the native Bidscube layer matches the MAX adapter. Then drive ads with your usual **MAX** APIs.  

*(Pure native iOS with `BidscubeSDKAppLovin` only: the adapter may own runtime init — see the [iOS SDK repo](https://github.com/BidsCube/AppLovin-SDK-for-BidsCube-iOS).)*

---

## Sample app (testing)

From the repo **`example/`**:

```bash
cd example && flutter pub get && flutter run
```

Point at a test SSP:

- **Dart:** `--dart-define=BIDSCUBE_SSP_AUTHORITY=host:port` (see `example/lib/main.dart`)  
- **Native (iOS):** `bidcube.testSspAuthority` / `BIDSCUBE_TEST_SSP_AUTHORITY` where your native stack supports them  

Ad request uses `https://<authority>/sdk` with query params aligned to the native SDK builders (`c`, `m`, device fields, etc.).

---

## License

**MIT.** See [`LICENSE`](LICENSE).

## Version

**Bidscube Flutter SDK 1.0.3** (see [`pubspec.yaml`](pubspec.yaml), [`CHANGELOG.md`](CHANGELOG.md)).

Maintainers: [`RELEASE.md`](RELEASE.md) · `flutter test` · `flutter analyze`
