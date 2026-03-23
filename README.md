# BidsCube Flutter SDK (`bidscube_sdk_flutter`)

Flutter plugin for **BidsCube** on Android/iOS with **AppLovin MAX** mediation (native adapter + shared `BidscubeSDK` init), plus a **direct SDK** (Flutter widgets) when you use `directSdk` instead of mediation.

## Use as a Flutter library

Add the dependency, then import the **library barrel** (only public entry you need):

```yaml
# pubspec.yaml
dependencies:
  bidscube_sdk_flutter: ^1.0.0
  # Local development:
  # bidscube_sdk_flutter:
  #   path: path/to/AppLovin-SDK-Flutter
```

```dart
import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
```

The package is a **Flutter plugin** (`flutter.plugin` in [pubspec.yaml](pubspec.yaml)): Android (`BidscubeSdkFlutterPlugin`) and iOS (`BidscubeSdkPlugin`) register `MethodChannel('bidscube_sdk')` and PlatformViews. Run `flutter pub get`; on iOS run `pod install` under `ios/`. Native Bidscube artifacts are pulled per [android/build.gradle](android/build.gradle) and [ios/bidscube_sdk_flutter.podspec](ios/bidscube_sdk_flutter.podspec).

## Features

- Android & iOS; **mediation**: early `BidscubeSDK.initialize` so native adapters share one SDK instance
- **Direct SDK** (`directSdk`): image, video, native, banner, VAST / IMA, positions & styling
- **Mediation** (`appLovinMaxMediation`): no `get*AdView` from Dart — ads are driven only by **AppLovin MAX**
- Logging, timeouts, `onAdRenderOverride`, test placement IDs in README tables below

## Requirements

- Flutter **3.19.0+**, Dart **3.5.0+** (`pubspec.yaml`, `.github/flutter-version` for CI)
- Android **24+** with native SDK; **`mavenLocal()`** + local publish from your native SDK tree when needed — see `android/libs/README.md`
- iOS **13+**; Web/Desktop: same as Flutter platform support for direct SDK

## AppLovin MAX (mediation)

Mediation lives in **native** `BidscubeMediationAdapter` (Android) / `ALBidscubeMediationAdapter` (iOS), not in Dart. From Flutter you only **initialize** the native Bidscube SDK so the MAX adapter uses the same instance.

| Format | Native (native Bidscube SDK) | Role |
|--------|------------------------------|------|
| **Banner** | `getImageAdView` (native SDK) | Adapter passes the returned `View` / `UIView` to MAX. Inside AppLovin, **AdDisplayManager** uses the rendered ADM and **BannerViewFactory** builds the **WebView**. In **Dart** direct SDK, use `getBannerAdView` (maps to the same native call). |
| **Interstitial** | `showImageAd` | Full-screen image flow inside AppLovin (overlay from your rendered ADM). |
| **Video** | `showVideoAd` | Full-screen playback via **IMAPlayerHandler** (or platform equivalent) and **fullscreen** container. |
| **Native** | `getNativeAdView` | Adapter builds **`MaxNativeAd`** from the native payload and passes **that** to MAX — not the SDK view as the mediated creative. |

**Flutter:** use `BidscubeIntegrationMode.appLovinMaxMediation`, `useFlutterOnly: false`, and **do not** call Dart `getBannerAdView` / `getVideoAdView` / etc. — load/show only through MAX (`applovin_max` or native MAX APIs). (Mediation uses native `getImageAdView`, not the Flutter API.)

```dart
await BidscubeSDK.initialize(
  config: SDKConfig.builder()
      .baseURL('https://ssp-bcc-ads.com/sdk')
      .integrationMode(BidscubeIntegrationMode.appLovinMaxMediation)
      .build(),
  useFlutterOnly: false,
);
// Then: AppLovin MAX SDK init, ad units, load/show via MAX.
```

| Mode | Mediation | Dart `getBannerAdView` / … |
|------|-----------|----------------------------|
| `directSdk` (default) | Optional (you add MAX yourself) | Yes |
| `appLovinMaxMediation` | Yes — MAX only | No — `UnsupportedError` |

**Rules:** `useFlutterOnly: false`. Do not use `FlutterOnlyBidscube` with `appLovinMaxMediation`.

**Dependencies:** `bidscube_sdk_flutter` + [applovin_max](https://pub.dev/packages/applovin_max) (or native MAX SDK) + your **Bidscube MAX adapter** artifacts per integration guide.

**Android `app`:** `minSdk` 24; add AppLovin MAX SDK and Bidscube adapter dependencies from your adapter docs; `mavenLocal()` if the Bidscube AAR is local; core desugaring like `example/android/app/build.gradle.kts` if Gradle asks.

**iOS `Podfile`:** after `flutter_install_all_ios_pods`, add AppLovin MAX, `BidscubeSDK`, and the Bidscube MAX adapter pod (versions per your release). Then `pod install`.

**MAX dashboard**

| Item | Where | Note |
|------|--------|------|
| SDK Key | AppLovin MAX | MAX SDK initialization |
| Ad unit IDs | MAX dashboard | Used in load/show APIs |
| Custom network | MAX mediation | Bidscube adapter class / package |
| Android | Network setup | e.g. `BidscubeMediationAdapter` (match your artifact) |
| iOS | Network setup | e.g. `ALBidscubeMediationAdapter` |
| Instance / custom string | Network instance | **Bidscube placement ID** |

**Legacy configs:** Older serialized `SDKConfig` with `integrationMode: 'levelPlay'` still deserialize as **`appLovinMaxMediation`** (Level Play is no longer a separate mode).

## Releasing (maintainers)

`RELEASE.md` — tags, pub.dev OIDC, GitHub Release. Workflow: `.github/workflows/release.yml`.

## Installation

```yaml
dependencies:
  bidscube_sdk_flutter: ^1.0.0
```

Mediation: add native Bidscube + AppLovin MAX + your Bidscube MAX adapter (see **AppLovin MAX (mediation)** above).

```bash
flutter pub get
```

## Quick Start

**Direct SDK only** (`directSdk`). For MAX mediation use **AppLovin MAX (mediation)** — no Dart `get*AdView` there.

### 1. Initialize the SDK

```dart
import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';

// Configure the SDK
final config = SDKConfig.builder()
    .baseURL('https://ssp-bcc-ads.com/sdk')
    .enableLogging(true)
    .enableDebugMode(true)
    .defaultAdTimeout(30000)
    .defaultAdPosition(AdPosition.header)
    .enableTestMode(true)
    .build();

// Initialize the SDK
await BidscubeSDK.initialize(config: config);
```

### 2. Create Ad Views

Banner and image inventory share one path: Dart exposes **`getBannerAdView`** (the Android/iOS plugin calls native `BidscubeSDK.getImageAdView` under the hood). Mediation adapters call **`getImageAdView`** directly in native code — there is no `getImageAdView` on the Dart `BidscubeSDK` class.

```dart
// Banner / image (Dart API)
final bannerAdView = await BidscubeSDK.getBannerAdView(
  'your_banner_or_image_placement_id',
  callback: MyAdCallback(),
);

// Video Ad
final videoAdView = await BidscubeSDK.getVideoAdView(
  'your_video_placement_id',
  callback: MyAdCallback(),
);

// Native Ad
final nativeAdView = await BidscubeSDK.getNativeAdView(
  'your_native_placement_id',
  callback: MyAdCallback(),
);
```

### 3. Implement Ad Callbacks

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

## Custom rendering with onAdRenderOverride

If you want full control over how an ad is rendered in your app (for example to use your own native components, custom WebView handling, or a different layout), use the `onAdRenderOverride` callback on your `AdCallback` implementation.

How it works

- When you pass an `AdCallback` to `getBannerAdView`, `getVideoAdView`, or `getNativeAdView`, the SDK will check whether the callback's `onAdRenderOverride` is non-null.
- If `onAdRenderOverride` is provided, the SDK will perform the ad request and call your `onAdRenderOverride(placementId, adm, position)` handler with the server response.
  - `adm` is the ad markup or data: it may be an HTML snippet, a VAST XML (for video), or a JSON-encoded object for native ads. If the server doesn't provide a specific `adm` field the SDK will pass a JSON-encoded fallback with the full response.
- When `onAdRenderOverride` is used, the SDK returns a placeholder widget (a SizedBox) instead of mounting the SDK-built view — you are expected to render the ad yourself inside your app UI.

Recommended usage pattern

1. Implement an `AdCallback` and set the `onAdRenderOverride` handler. In the handler parse the `adm` and create a Widget to display the ad.
2. Insert that widget into your widget tree (for example by storing it in state and calling `setState`) at the desired location.
3. The SDK still calls lifecycle methods (`onAdLoading`, `onAdLoaded`, `onAdDisplayed`, `onAdFailed`) so you can track ad state as before.

Example: render HTML/creative in a WebView

```dart
class ClientAdWidget extends StatefulWidget {
  final String placementId;
  ClientAdWidget(this.placementId);
  @override
  State createState() => _ClientAdWidgetState();
}

class _ClientAdWidgetState extends State<ClientAdWidget> {
  String? _html;

  @override
  Widget build(BuildContext context) {
    if (_html == null) return SizedBox(width: 320, height: 240);
    return SizedBox(
      width: 320,
      height: 240,
      child: WebViewWidget(controller: WebViewController()..loadHtmlString(_html!)),
    );
  }

  void updateHtml(String html) => setState(() => _html = html);
}

// When you register the callback (example in a State object):
final clientAdWidgetKey = GlobalKey<_ClientAdWidgetState>();
final clientWidget = ClientAdWidget('20212');

final callback = MyAdCallback();
callback.onAdRenderOverride = (placementId, adm, position) {
  // adm may already be full HTML; if it's JSON-encoded, extract the HTML from adm
  final html = adm; // or parse adm to extract HTML fragment
  clientAdWidgetKey.currentState?.updateHtml(html);
};

// Add the clientWidget (with key) into your UI; then call:
await BidscubeSDK.getBannerAdView('20212', callback: callback);
```

Example: parse native JSON and build a Flutter widget

```dart
callback.onAdRenderOverride = (placementId, adm, position) {
  // adm may be JSON; try to decode
  try {
    final data = json.decode(adm) as Map<String, dynamic>;
    // Extract fields (title, image, cta, etc.) and create widget
    final title = data['title'] ?? '';
    final imageUrl = data['imageUrl'] ?? '';
    setState(() {
      _clientAdWidget = GestureDetector(
        onTap: () => _onAdClicked(placementId),
        child: Column(children: [Text(title), Image.network(imageUrl), /* cta */]),
      );
    });
  } catch (e) {
    // Fallback: treat adm as plain string and log
    print('Failed to parse adm: $e');
  }
};
```

Notes and tips

- The SDK will call your lifecycle methods (onAdLoading/onAdLoaded/onAdDisplayed/onAdFailed) so you can show placeholders or retry UI while the network request is in progress.
- For VAST video ADM you typically receive XML — you can either feed it to a VAST/IMA player or implement your own video player. The SDK's IMA integration is used only when the SDK renders the view itself; when you override rendering you are responsible for playing/pausing and tracking video events.
- If your `onAdRenderOverride` throws an error, the SDK will log the exception and continue; consider adding try/catch around parsing and rendering logic to avoid losing lifecycle notifications.
- When using custom rendering, make sure to call `BidscubeSDK.setAdCallback(placementId, callback)` if you need SDK-level registration for later events (optional — passing callback directly to `get*AdView` is usually sufficient).

## Usage Examples

### Banner / image ads (Dart)

```dart
final bannerAdView = await BidscubeSDK.getBannerAdView(
  'your_banner_or_image_placement_id',
  callback: MyAdCallback(),
);

// Add to your widget tree
Container(
  width: 320,
  height: 240,
  child: bannerAdView,
)
```

### Video Ads

```dart
final videoAdView = await BidscubeSDK.getVideoAdView(
  'your_video_placement_id',
  callback: MyAdCallback(),
);

// Add to your widget tree
Container(
  width: 320,
  height: 240,
  child: videoAdView,
)
```

### Native Ads

```dart
final nativeAdView = await BidscubeSDK.getNativeAdView(
  'your_native_placement_id',
  callback: MyAdCallback(),
);

// Add to your widget tree
Container(
  width: 320,
  height: 300,
  child: nativeAdView,
)
```

## Advanced Features

### Dynamic Position-Based Styling

The SDK automatically applies different visual styles based on the ad position received from the server:

- **Above The Fold**: Blue styling with rounded corners
- **Below The Fold**: Green styling with medium corners
- **Header**: Orange styling with small corners
- **Footer**: Purple styling with small corners
- **Sidebar**: Teal styling with medium corners
- **Full Screen**: Red styling with large corners and strong shadow
- **Depend On Screen Size**: Amber styling with medium corners

### Position Override for Testing

You can override the server-determined position for testing purposes:

```dart
// Enable position override
final config = SDKConfig.builder()
    .enableTestMode(true)
    .build();

// The ad view will use the specified position instead of server response
final adView = await BidscubeSDK.getBannerAdView(
  'your_placement_id',
  position: AdPosition.fullScreen, // Override position
  callback: MyAdCallback(),
);
```

### Responsive Native Ads

Native ads automatically adapt to different screen sizes using flexible Flutter widgets:

- **Small screens** (< 300px): Compact layout
- **Medium screens** (300-500px): Balanced layout
- **Large screens** (> 500px): Full layout with all elements

### Comprehensive Logging

The SDK provides detailed logging through `SDKLogger`:

```dart
// Enable detailed logging
final config = SDKConfig.builder()
    .enableLogging(true)
    .enableDebugMode(true)
    .build();

// Logs include:
// - Request URLs and parameters
// - Response status codes and content
// - Position changes from server
// - Error details and stack traces
```

## Test Placement IDs

| Placement ID | Ad Type | Description                      |
| ------------ | ------- | -------------------------------- |
| `20212`      | Banner  | Test banner ad                   |
| `20213`      | Video   | Test video ad with VAST response |
| `20214`      | Native  | Test native ad                   |

## Running the Test App

1. **Navigate to testapp directory**:

   ```bash
   cd testapp
   ```

2. **Get dependencies**:

   ```bash
   flutter pub get
   ```

3. **Run on your preferred platform**:

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

## Configuration Options

### SDK Configuration

```dart
final config = SDKConfig.builder()
    .baseURL('https://ssp-bcc-ads.com/sdk')  // API endpoint
    .enableLogging(true)                     // Enable console logging
    .enableDebugMode(true)                   // Enable debug mode
    .defaultAdTimeout(30000)                 // Timeout in milliseconds
    .defaultAdPosition(AdPosition.header)    // Default ad position
    .enableTestMode(true)                    // Enable test mode
    .build();
```

## Troubleshooting

### Common Issues

1. **Ad not loading**:

   - Check network connectivity
   - Verify placement ID is correct
   - Check console logs for error messages

2. **Video ads not playing**:

   - Ensure platform-specific video support
   - Check VAST response format
   - Verify video URL is accessible

3. **Build errors**:
   - Ensure Flutter 3.19+ / Dart 3.5+ (see `pubspec.yaml` and `.github/flutter-version` for CI)
   - Check platform-specific requirements
   - Verify all dependencies are properly configured

### Debug Mode

Enable debug mode for detailed logging:

```dart
final config = SDKConfig.builder()
    .enableDebugMode(true)
    .build();
```

## Building the Package

To build the package for production:

```bash
# Run tests
flutter test

# Analyze code
flutter analyze

# Build for all platforms
flutter build apk --release
flutter build ios --release
```

## License

This project is licensed under the MIT License — see `LICENSE`.

## Changelog

See `CHANGELOG.md`.
