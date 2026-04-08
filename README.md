# BidsCube Flutter SDK (`bidscube_sdk_flutter`)

Flutter plugin for **BidsCube** on **Android** / **iOS** with **AppLovin MAX** mediation (native adapter + shared `BidscubeSDK` init), plus a **direct SDK** (Flutter widgets) when you use `directSdk` instead of mediation.

## Contents

- [Use as a Flutter library](#use-as-a-flutter-library)
- [Features](#features)
- [Requirements](#requirements)
- [Self-contained native SDK](#self-contained-native-sdk)
- [AppLovin MAX (mediation)](#applovin-max-mediation)
- [Releasing (maintainers)](#releasing-maintainers)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Custom rendering with `onAdRenderOverride`](#custom-rendering-with-onadrenderoverride)
- [Usage examples](#usage-examples)
- [Advanced features](#advanced-features)
- [Test placement IDs](#test-placement-ids)
- [Running the test app](#running-the-test-app)
- [Configuration options](#configuration-options)
- [Ad request endpoint (reference)](#ad-request-endpoint-reference)
- [Troubleshooting](#troubleshooting)
- [Building the package](#building-the-package)
- [Changelog](#changelog)
- [License](#license)

---

## Use as a Flutter library

Add the dependency, then import the **library barrel** (the main public entry):

```yaml
# pubspec.yaml
dependencies:
  bidscube_sdk_flutter: ^1.0.2
  # Local development:
  # bidscube_sdk_flutter:
  #   path: path/to/AppLovin-SDK-Flutter
```

```dart
import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
```

The package is a **Flutter plugin** (`flutter.plugin` in [`pubspec.yaml`](pubspec.yaml)): **Android** (`BidscubeSdkFlutterPlugin`) and **iOS** (`BidscubeSdkPlugin`) register `MethodChannel('bidscube_sdk')` and **PlatformViews**. Run `flutter pub get`; on iOS run `pod install` under `ios/`. Native Bidscube artifacts can live **inside this repo** (see [Self-contained native SDK](#self-contained-native-sdk)) or resolve from Maven / CocoaPods. The plugin also pulls **AppLovin MAX SDK 13.x** on Android and iOS so you do not need a separate AppLovin dependency for adapter compilation (your app may still add [`applovin_max`](https://pub.dev/packages/applovin_max) for Dart APIs).

---

## Features

| Area | Behavior |
|------|----------|
| **Platforms** | Android & iOS for native bridge; Web/Desktop follow Flutter support when using **direct** (`useFlutterOnly`) paths |
| **Mediation** | Early `BidscubeSDK.initialize` so native **MAX** adapters share **one** native SDK instance |
| **Direct SDK** (`directSdk`) | Image, video, native, banner, VAST / IMA, positions & styling |
| **Mediation** (`appLovinMaxMediation`) | No `get*AdView` from Dart — ads are driven only by **AppLovin MAX** |
| **Extras** | Logging, timeouts, `onAdRenderOverride`, test placement IDs (below) |

---

## Requirements

| Requirement | Details |
|-------------|---------|
| **Flutter / Dart** | Flutter **3.19.0+**, Dart **3.5.0+** — see [`pubspec.yaml`](pubspec.yaml); CI pins a Flutter SDK in [`.github/flutter-version`](.github/flutter-version) |
| **Android** | **API 24+**; native Bidscube via **`android/libs/*.aar`** (name contains `bidscube`) or Maven `com.bidscube:bidscube-sdk` — [`android/libs/README.md`](android/libs/README.md) |
| **iOS** | **13.0+** (required for AppLovin MAX **13.x** shipped with this plugin) |
| **AppLovin MAX** | **13.0+** on both platforms (`com.applovin:applovin-sdk` **13.6.0** on Android, `AppLovinSDK` **`~> 13.0`** on iOS) |
| **Web / desktop** | Same as Flutter platform support for **direct** SDK usage where applicable |

---

## Self-contained native SDK

You can ship the **main Bidscube native SDK** together with this Flutter package so integrators do **not** maintain a second Android/iOS project or Maven publish step.

### Android

- Place a release **`*.aar`** under [`android/libs/`](android/libs/) whose filename contains **`bidscube`** (case-insensitive), e.g. `bidscube-sdk-release.aar`.
- [`android/build.gradle`](android/build.gradle) prefers that file over `com.bidscube:bidscube-sdk:1.0.0` from Maven.

### iOS

- Add one or more **`*.xcframework`** bundles under [`ios/Frameworks/`](ios/Frameworks/).
- [`ios/bidscube_sdk_flutter.podspec`](ios/bidscube_sdk_flutter.podspec) sets `vendored_frameworks` for every `Frameworks/*.xcframework`. If the directory is empty, it falls back to the **`bidscubeSdk`** pod (`1.0.0`).

See [`android/libs/README.md`](android/libs/README.md) and [`ios/Frameworks/README.md`](ios/Frameworks/README.md) for details.

---

## AppLovin MAX (mediation)

Mediation lives in **native** code — `BidscubeMediationAdapter` (Android) / `ALBidscubeMediationAdapter` (iOS), **not** in Dart. From Flutter you only **initialize** the native Bidscube SDK so the MAX adapter uses the **same** instance.

### Native flow (formats)

| Format | Native (Bidscube SDK) | Role |
|--------|------------------------|------|
| **Banner** | `getImageAdView` | Adapter passes the returned `View` / `UIView` to MAX. Inside AppLovin, **AdDisplayManager** uses the rendered ADM and **BannerViewFactory** builds the **WebView**. In **Dart** direct SDK, use `getBannerAdView` (same native call under the hood). |
| **Interstitial** | `showImageAd` | Full-screen image flow inside AppLovin (overlay from rendered ADM). |
| **Video** | `showVideoAd` | Full-screen playback via **IMAPlayerHandler** (or platform equivalent) and fullscreen container. |
| **Native** | `getNativeAdView` | Adapter builds **`MaxNativeAd`** from the native payload for MAX — **not** the SDK view as the mediated creative. |

### Flutter initialization (mediation)

Use `BidscubeIntegrationMode.appLovinMaxMediation`, `useFlutterOnly: false`, and **do not** call Dart `getBannerAdView` / `getVideoAdView` / `getNativeAdView` — load/show only through MAX (`applovin_max` or native MAX APIs). Mediation uses native `getImageAdView`, not the Flutter API.

```dart
await BidscubeSDK.initialize(
  config: SDKConfig.builder()
      .adRequestAuthority('ssp-bcc-ads.com') // default; omit to use production host
      .integrationMode(BidscubeIntegrationMode.appLovinMaxMediation)
      .build(),
  useFlutterOnly: false,
);
// Then: AppLovin MAX SDK init, ad units, load/show via MAX.
```

### Mode summary

| Mode | Mediation | Dart `getBannerAdView` / … |
|------|-----------|----------------------------|
| `directSdk` (default) | Optional (you add MAX yourself) | **Yes** |
| `appLovinMaxMediation` | Yes — MAX only | **No** — throws `UnsupportedError` |

**Rules**

- Use `useFlutterOnly: false` for mediation.
- Do **not** use `FlutterOnlyBidscube` with `appLovinMaxMediation`.

**Dependencies:** `bidscube_sdk_flutter` already declares **AppLovin MAX SDK 13.x** natively; add [`applovin_max`](https://pub.dev/packages/applovin_max) if you want Dart APIs for load/show. Your **Bidscube mediation adapter** is expected to live inside the vendored / Maven Bidscube SDK (same as the standalone native integration guide).

**Android app**

- `minSdk` **24** (adjust if your adapter docs require higher).
- Add AppLovin MAX SDK and Bidscube adapter dependencies from your adapter docs.
- `mavenLocal()` if the Bidscube AAR is local.
- Enable **core desugaring** if Gradle requires it (see [`example/android/app/build.gradle.kts`](example/android/app/build.gradle.kts)).

**iOS `Podfile`**

After `flutter_install_all_ios_pods`, add AppLovin MAX, `BidscubeSDK`, and the Bidscube MAX adapter pod (versions per your release), then `pod install`.

### MAX dashboard

| Item | Where | Note |
|------|--------|------|
| **SDK Key** | AppLovin MAX | MAX SDK initialization |
| **Ad unit IDs** | MAX dashboard | Used in load/show APIs |
| **Custom network** | MAX mediation | Bidscube adapter class / package |
| **Android** | Network setup | e.g. `BidscubeMediationAdapter` (match your artifact) |
| **iOS** | Network setup | e.g. `ALBidscubeMediationAdapter` |
| **Instance / custom string** | Network instance | Bidscube **placement ID** |

AppLovin overview: [Integrating custom SDK networks](https://support.axon.ai/en/max/mediated-network-guides/integrating-custom-sdk-networks/).

**Legacy configs:** serialized `SDKConfig` with `integrationMode: 'levelPlay'` still deserializes as **`appLovinMaxMediation`** (Level Play is no longer a separate mode).

---

## Releasing (maintainers)

See [`RELEASE.md`](RELEASE.md) — tags, pub.dev OIDC, GitHub Release. Workflow: [`.github/workflows/release.yml`](.github/workflows/release.yml).

---

## Installation

```yaml
dependencies:
  bidscube_sdk_flutter: ^1.0.2
```

For **mediation**, add native Bidscube + AppLovin MAX + your Bidscube MAX adapter (see [AppLovin MAX (mediation)](#applovin-max-mediation)).

```bash
flutter pub get
```

---

## Quick start

**Direct SDK** (`directSdk`) only below. For **MAX** mediation, follow [AppLovin MAX (mediation)](#applovin-max-mediation) — **no** Dart `get*AdView` there.

### 1. Initialize the SDK

```dart
import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';

final config = SDKConfig.builder()
    .adRequestAuthority('ssp-bcc-ads.com') // optional; default production SSP host
    .enableLogging(true)
    .enableDebugMode(true)
    .defaultAdTimeout(30000)
    .defaultAdPosition(AdPosition.header)
    .enableTestMode(true)
    .build();

await BidscubeSDK.initialize(config: config);
```

### 2. Create ad views

Banner and image inventory share one path: Dart exposes **`getBannerAdView`** (plugin → native `BidscubeSDK.getImageAdView`). MAX adapters call **`getImageAdView`** in native code — there is **no** `getImageAdView` on the Dart `BidscubeSDK` class.

```dart
final bannerAdView = await BidscubeSDK.getBannerAdView(
  'your_banner_or_image_placement_id',
  callback: MyAdCallback(),
);

final videoAdView = await BidscubeSDK.getVideoAdView(
  'your_video_placement_id',
  callback: MyAdCallback(),
);

final nativeAdView = await BidscubeSDK.getNativeAdView(
  'your_native_placement_id',
  callback: MyAdCallback(),
);
```

### 3. Implement ad callbacks

```dart
class MyAdCallback implements AdCallback {
  @override
  void onAdLoading(String placementId) {
    print('Ad loading: $placementId');
  }

  @override
  void onAdLoaded(String placementId) {
    print('Ad loaded: $placementId');
  }

  @override
  void onAdDisplayed(String placementId) {
    print('Ad displayed: $placementId');
  }

  @override
  void onAdFailed(String placementId, String errorCode, String errorMessage) {
    print('Ad failed: $placementId - $errorMessage (Code: $errorCode)');
  }

  @override
  void onAdClicked(String placementId) {
    print('Ad clicked: $placementId');
  }

  @override
  void onAdClosed(String placementId) {
    print('Ad closed: $placementId');
  }

  @override
  void onVideoAdStarted(String placementId) {
    print('Video ad started: $placementId');
  }

  @override
  void onVideoAdCompleted(String placementId) {
    print('Video ad completed: $placementId');
  }

  @override
  void onVideoAdSkipped(String placementId) {
    print('Video ad skipped: $placementId');
  }
}
```

---

## Custom rendering with `onAdRenderOverride`

For full control over rendering (custom components, WebView, layout), implement **`onAdRenderOverride`** on your `AdCallback`.

### How it works

1. For `getBannerAdView` / `getVideoAdView` / `getNativeAdView`, if `onAdRenderOverride` is **non-null**, the SDK performs the request and calls **`onAdRenderOverride(placementId, adm, position)`** with the server response.
2. **`adm`** may be HTML, VAST XML, or JSON (native); if there is no dedicated `adm` field, the SDK may pass a JSON-encoded fallback with the full response.
3. With an override, the SDK returns a **placeholder** (`SizedBox`) instead of the SDK-built view — **you** render the ad in your widget tree.

### Recommended pattern

1. Implement `AdCallback` and assign `onAdRenderOverride`; parse `adm` and build a `Widget`.
2. Put that widget in the tree (e.g. store in state / `setState`).
3. Lifecycle methods (`onAdLoading`, `onAdLoaded`, …) still run as usual.

### Example: HTML in a WebView

```dart
import 'package:webview_flutter/webview_flutter.dart';

class ClientAdWidget extends StatefulWidget {
  final String placementId;
  const ClientAdWidget(this.placementId, {super.key});

  @override
  State<ClientAdWidget> createState() => _ClientAdWidgetState();
}

class _ClientAdWidgetState extends State<ClientAdWidget> {
  String? _html;

  @override
  Widget build(BuildContext context) {
    if (_html == null) return const SizedBox(width: 320, height: 240);
    return SizedBox(
      width: 320,
      height: 240,
      child: WebViewWidget(
        controller: WebViewController()..loadHtmlString(_html!),
      ),
    );
  }

  void updateHtml(String html) => setState(() => _html = html);
}

final clientAdWidgetKey = GlobalKey<_ClientAdWidgetState>();
final clientWidget = ClientAdWidget('20212', key: clientAdWidgetKey);

final callback = MyAdCallback();
callback.onAdRenderOverride = (placementId, adm, position) {
  final html = adm;
  clientAdWidgetKey.currentState?.updateHtml(html);
};

// Place clientWidget in the tree, then:
await BidscubeSDK.getBannerAdView('20212', callback: callback);
```

### Example: native JSON → Flutter widget

```dart
callback.onAdRenderOverride = (placementId, adm, position) {
  try {
    final data = json.decode(adm) as Map<String, dynamic>;
    final title = data['title'] ?? '';
    final imageUrl = data['imageUrl'] ?? '';
    setState(() {
      _clientAdWidget = GestureDetector(
        onTap: () => _onAdClicked(placementId),
        child: Column(
          children: [
            Text(title),
            Image.network(imageUrl),
            // CTA, etc.
          ],
        ),
      );
    });
  } catch (e) {
    print('Failed to parse adm: $e');
  }
};
```

### Notes

- Lifecycle callbacks still run for loading / errors / display.
- For **VAST** `adm`, you supply your own player or IMA pipeline when overriding; default SDK IMA applies only when the SDK renders the view.
- Wrap parsing in **try/catch**; exceptions in the override are logged by the SDK.
- Use `BidscubeSDK.setAdCallback(placementId, callback)` if you need SDK-level registration for later events (optional; passing `callback` into `get*AdView` is usually enough).

---

## Usage examples

### Banner / image (Dart)

```dart
final bannerAdView = await BidscubeSDK.getBannerAdView(
  'your_banner_or_image_placement_id',
  callback: MyAdCallback(),
);

SizedBox(
  width: 320,
  height: 240,
  child: bannerAdView,
);
```

### Video

```dart
final videoAdView = await BidscubeSDK.getVideoAdView(
  'your_video_placement_id',
  callback: MyAdCallback(),
);

SizedBox(
  width: 320,
  height: 240,
  child: videoAdView,
);
```

### Native

```dart
final nativeAdView = await BidscubeSDK.getNativeAdView(
  'your_native_placement_id',
  callback: MyAdCallback(),
);

SizedBox(
  width: 320,
  height: 300,
  child: nativeAdView,
);
```

---

## Advanced features

### Dynamic position-based styling

The SDK applies styles from server **position** (e.g. header, footer, above/below the fold, full screen). Inspect widget implementations for exact visuals.

### Position override (testing)

```dart
final config = SDKConfig.builder()
    .enableTestMode(true)
    .build();

final adView = await BidscubeSDK.getBannerAdView(
  'your_placement_id',
  position: AdPosition.fullScreen,
  callback: MyAdCallback(),
);
```

### Responsive native ads

Native layouts adapt by width (compact / balanced / full) via flexible Flutter widgets.

### Logging

```dart
final config = SDKConfig.builder()
    .enableLogging(true)
    .enableDebugMode(true)
    .build();
```

Logs include requests, responses, position changes, and errors (via `SDKLogger`).

---

## Test placement IDs

| Placement ID | Ad type | Description |
|--------------|---------|-------------|
| `20212` | Banner | Test banner |
| `20213` | Video | Test video (VAST) |
| `20214` | Native | Test native |

---

## Running the test app

```bash
cd testapp
flutter pub get
```

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d web

# macOS
flutter run -d macos

# Linux
flutter run -d linux

# Windows
flutter run -d windows
```

---

## Configuration options

```dart
final config = SDKConfig.builder()
    .adRequestAuthority('ssp-bcc-ads.com') // or .baseURL('https://ssp-bcc-ads.com/sdk') (legacy; normalized to authority)
    .enableLogging(true)
    .enableDebugMode(true)
    .defaultAdTimeout(30000)
    .defaultAdPosition(AdPosition.header)
    .enableTestMode(true)
    .integrationMode(BidscubeIntegrationMode.directSdk) // default; omit or set explicitly
    .build();
```

---

## Ad request endpoint (reference)

This matches the Bidscube Android SDK behavior (`SDKConfig`, `SspAdUriHelper`, `ImageAdUrlBuilder`, `VideoAdUrlBuilder`, `NativeAdUrlBuilder`).

### Host / authority

- **Public API:** `SDKConfig.adRequestAuthority` (optional on the builder via `adRequestAuthority(...)`).
- **Default:** `ssp-bcc-ads.com` (same as Android `DEFAULT_AD_REQUEST_AUTHORITY`).
- **Do not** pass a full URL that already includes the `/sdk` path **and** query parameters intended for your app — the SDK always uses **`https`**, appends **`/sdk`**, and adds query parameters described below. Passing a short `https://host` or `host:port` prefix without query is fine; values are **normalized** (trim, up to three rounds of percent-decoding, strip `http(s)://`, first path segment, and query) before use.

### Resolved base URL

- **Scheme:** always `https`.
- **Path:** `/sdk` (e.g. `https://ssp-bcc-ads.com/sdk`).
- **Port:** `host:port` is parsed so the port is a real URI port (e.g. `127.0.0.1:8787` → TCP 8787), not a single string that would encode as `host%3Aport` in the authority.

### HTTP method and response

- **Method:** `GET`.
- **Body:** JSON, UTF-8.
- **Fields used by the SDK:** `adm` (string) and `position` (int), consistent with the Android `BidscubeResponseParser`.

### Query parameters by ad format

| Format | `c` / `m` | Notes |
|--------|-----------|--------|
| **Banner / image** | `c=b`, `m=api`, `res=js`, `app=1` | Plus: `placementId`, `bundle`, `name`, `app_store_url`, `language`, `deviceWidth`, `deviceHeight`, `ua`, `ifa`, `dnt`. |
| **Video** | `c=v`, `m=xml`, `app=1` | Plus: `id`, `w`/`h` (screen size from device), `bundle`, `name`, `app_version`, `ifa`, `dnt`, `app_store_url`, `ua`, `language`, `deviceWidth`, `deviceHeight`. |
| **Native** | `c=n`, `m=s`, `app=1` | Plus: `id`, `bundle`, `name`, `app_version`, `ifa`, `dnt`, `app_store_url`, `ua`, `gdpr`, `gdpr_consent`, `us_privacy`, `ccpa`, `coppa`, `language`, `deviceWidth`, `deviceHeight`, `w`/`h` (logical size from the native ad view). Some optional strings use the literal `"null"` when empty (Android parity). |

### AppLovin MAX / mediation

On Android, the adapter may read **`request_authority`** or **`ssp_host`** from server parameters and pass them into **`adRequestAuthority`**. Use the **same keys and normalization** in your network configuration. Document for publishers: only **host**, **`host:port`**, or a short **`https://`** prefix **without** query strings.

### Example app: custom authority (e.g. local mock / tunnel)

```bash
flutter run --dart-define=BIDSCUBE_SSP_AUTHORITY=127.0.0.1:8787
```

```dart
const _authority = String.fromEnvironment('BIDSCUBE_SSP_AUTHORITY', defaultValue: '');
// ...
SDKConfig.builder()
    .adRequestAuthority(_authority.isEmpty ? null : _authority)
    .build();
```

### Integration testing

Point `adRequestAuthority` at a mock SSP (e.g. a Python script or HTTPS tunnel via **cloudflared** / **ngrok**) the same way as in the Bidscube Android project README: the client must reach `https://<authority>/sdk?…` with the query layout above.

---

## Troubleshooting

### Ads not loading

- Network connectivity
- Correct **placement ID**
- Console / `SDKLogger` output

### Video not playing

- Platform video / IMA support
- Valid **VAST** and reachable media URLs

### Build errors

- Flutter **3.19+** / Dart **3.5+** ([`pubspec.yaml`](pubspec.yaml), [`.github/flutter-version`](.github/flutter-version))
- Android / iOS dependency versions vs adapter docs
- `flutter clean`, then `flutter pub get` / `pod install`

### Debug mode

```dart
final config = SDKConfig.builder()
    .enableDebugMode(true)
    .build();
```

---

## Building the package

```bash
flutter test
flutter analyze
flutter build apk --release   # example app
flutter build ios --release   # example app
```

---

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).

---

## License

This project is licensed under the **MIT License** — see [`LICENSE`](LICENSE).
