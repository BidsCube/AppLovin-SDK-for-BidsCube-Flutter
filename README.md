# BidsCube Flutter SDK (`bidscube_sdk_flutter`)

Flutter plugin: **Bidscube** ads on Android / iOS — **AppLovin MAX 13+** mediation (native init + adapters) or **direct** widgets (`getBannerAdView`, video, native). Optional **vendored** native SDK (`android/libs/*.aar`, `ios/Frameworks/*.xcframework`).

## Contents

- [Install](#install)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [AppLovin MAX (mediation)](#applovin-max-mediation)
- [Self-contained native SDK](#self-contained-native-sdk)
- [Ad request endpoint](#ad-request-endpoint)
- [`onAdRenderOverride`](#onadrenderoverride)
- [Test placements & example app](#test-placements--example-app)
- [Troubleshooting](#troubleshooting)
- [Maintainers](#maintainers)

---

## Install

```yaml
dependencies:
  bidscube_sdk_flutter: ^1.0.3
  # path: ../AppLovin-SDK-Flutter   # local
```

```dart
import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
```

Run `flutter pub get`; on iOS, `cd ios && pod install`. Native Bidscube: local AAR / XCFramework (see below) **or** Maven `com.bidscube:bidscube-sdk` / CocoaPods `bidscubeSdk`. The plugin declares **AppLovin MAX 13.x**; add [`applovin_max`](https://pub.dev/packages/applovin_max) only if you need Dart load/show APIs.

---

## Requirements

| | |
|--|--|
| Flutter / Dart | 3.19+ / 3.5+ ([`pubspec.yaml`](pubspec.yaml)) |
| Android | minSdk **24**; Bidscube AAR in [`android/libs/`](android/libs/) or Maven |
| iOS | **13.0+** |
| AppLovin | **13+** (bundled in plugin: Android `applovin-sdk` 13.6.x, iOS `AppLovinSDK ~> 13.0`) |
| Web / desktop | **Direct** path only (`useFlutterOnly`), no native bridge |

---

## Quick start

**Direct SDK** (default). For MAX-only mediation, skip `get*AdView` and use [AppLovin MAX](#applovin-max-mediation).

```dart
await BidscubeSDK.initialize(
  config: SDKConfig.builder()
      .adRequestAuthority('ssp-bcc-ads.com') // optional; default production host
      .enableLogging(true)
      .defaultAdTimeout(30000)
      .build(),
);

final banner = await BidscubeSDK.getBannerAdView('placement_id', callback: MyAdCallback());
// getVideoAdView / getNativeAdView — same pattern
```

Implement `AdCallback` (or extend `DefaultAdCallback`). Banner / image in Dart map to native `getImageAdView`.

**Builder highlights:** `adRequestAuthority` / legacy `baseURL(...)`, `integrationMode`, `enableTestMode`, `defaultAdPosition`, `enableDebugMode`.

---

## AppLovin MAX (mediation)

Mediation is **native** (`BidscubeMediationAdapter` / `ALBidscubeMediationAdapter`). From Flutter you only **initialize** `BidscubeSDK` so the adapter shares one instance.

| Mode | Dart `get*AdView` |
|------|-------------------|
| `directSdk` (default) | Allowed |
| `appLovinMaxMediation` | **Not** — use MAX (`applovin_max` or native APIs) |

```dart
await BidscubeSDK.initialize(
  config: SDKConfig.builder()
      .integrationMode(BidscubeIntegrationMode.appLovinMaxMediation)
      .build(),
  useFlutterOnly: false,
);
```

`useFlutterOnly: false` is required. Serialized `integrationMode: 'levelPlay'` still maps to `appLovinMaxMediation`.

| Dashboard | Note |
|-----------|------|
| Custom network | Bidscube adapter class (per your artifact) |
| Instance string | Bidscube **placement ID** |
| `request_authority` / `ssp_host` | Same normalization as `adRequestAuthority` |

[Custom networks (AppLovin)](https://support.axon.ai/en/max/mediated-network-guides/integrating-custom-sdk-networks/)

---

## Self-contained native SDK

- **Android:** put `*bidscube*.aar` in [`android/libs/`](android/libs/) — preferred over Maven ([`android/build.gradle`](android/build.gradle)).
- **iOS:** put `*.xcframework` in [`ios/Frameworks/`](ios/Frameworks/) — else pod `bidscubeSdk` 1.0.0.

Details: [`android/libs/README.md`](android/libs/README.md), [`ios/Frameworks/README.md`](ios/Frameworks/README.md).

---

## Ad request endpoint

- **Authority:** `SDKConfig.adRequestAuthority`, default `ssp-bcc-ads.com`. Do not pass full URLs with query; SDK builds `https://<host>[:port]/sdk` and query (normalization matches Android `SDKConfig` / `SspAdUriHelper`).
- **GET** → JSON: **`adm`** (string), **`position`** (int).
- **Query:** banner `c=b,m=api,res=js`; video `c=v,m=xml`; native `c=n,m=s` — field lists align with Android `*AdUrlBuilder` classes.

**Local mock:** `flutter run --dart-define=BIDSCUBE_SSP_AUTHORITY=127.0.0.1:8787` and `.adRequestAuthority(...)` from `String.fromEnvironment`.

---

## `onAdRenderOverride`

If set on `AdCallback`, the SDK fetches the ad then calls **`onAdRenderOverride(placementId, adm, position)`**; you render `adm` (HTML / VAST / JSON); a placeholder widget is returned. Wrap parsing in try/catch.

---

## Test placements & example app

| ID | Type |
|----|------|
| `20212` | Banner |
| `20213` | Video |
| `20214` | Native |

```bash
cd example && flutter pub get && flutter run -d android   # or ios, web, …
```

---

## Troubleshooting

- Ads: network, placement ID, `SDKLogger` / console.
- Video: IMA / VAST URLs reachable.
- Build: Flutter/Dart versions, `flutter clean`, `pod install`, adapter docs vs dependency versions.

---

## Maintainers

- Release: [`RELEASE.md`](RELEASE.md), [`.github/workflows/release.yml`](.github/workflows/release.yml).
- Tests: `flutter test` · `flutter analyze` · `flutter build apk` / `ios` from `example/`.

**Changelog:** [`CHANGELOG.md`](CHANGELOG.md) · **License:** [`LICENSE`](LICENSE)
