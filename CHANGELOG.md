## Unreleased

* **Breaking**: Removed `BidscubeIntegrationMode.levelPlayMediation`. Mediation targets **AppLovin MAX only** (`appLovinMaxMediation`). For backward compatibility, `SDKConfig` maps deserialized with `integrationMode: 'levelPlay'` still resolve to `appLovinMaxMediation`.
* Documentation and comments: IronSource / Level Play removed; README is MAX-centric.

## 1.0.0

* Version aligned with Bidscube stack **1.0.0** (Android, iOS, Unity).
* **Mediation**: `BidscubeIntegrationMode.appLovinMaxMediation` for AppLovin MAX (native init only, no `get*AdView` from Flutter). README documents MAX flow (`getImageAdView` / `showImageAd` / `showVideoAd` / `MaxNativeAd`).
* **Android plugin**: Flutter plugin (`android/src/main/...`, `BidscubeSdkFlutterPlugin`), native SDK `com.bidscube:bidscube-sdk:1.0.0` + `mavenLocal()` for local dev, `ActivityAware`, callbacks to Dart, PlatformView `bidscube_native_ad`.
* **iOS plugin**: banner via `getImageAdView`, unique `viewId`, callbacks to Dart.
* **Dart**: `AndroidView` on Android for native ads; full `example/`.
* Android: transitive SDK dependencies, desugar 2.1.3 in example, minSdk 24.
* Version / pub.dev compliance updates

## 1.2.0

* Fix for Android build
* Added onAdRenderOverride callback to notify when an ad is rendered with position override
* Improved error handling and logging for ad loading and rendering
* Updated dependencies to latest versions
* Minor documentation updates and code cleanup

## 1.1.0

* Major API cleanup and doc updates for publishing to pub.dev
* Fixed missing type imports (AdPosition, etc.) for platform builds
* Updated pubspec fields for pub.dev compliance and metadata
* Optimized builder pattern for SDKConfig (default URLs, etc.)
* Expanded README with usage, configuration, testApp details
* Removed example/, created testApp/ for better cross-platform demos
* Miscellaneous bugfixes, compliance improvements, and code cleanup

## 0.1.1

* Dependency updates to latest versions (Flutter, Dart, and all plugins)
* Improved documentation coverage for public API
* Added a complete example in example/main.dart
* Fixed static analysis and lint warnings
* Added library directives to fix dangling doc comments
* Fixed unused variable and whitespace widget issues
* Improved consent management callback handling in testapp
* Various bugfixes and code cleanup for pub.dev compliance

## 0.1.0

* Initial release of BidsCube Flutter SDK
* Multi-platform support (Android, iOS, Web, Desktop)
* Image, Video, and Native ad support
* Multiple ad positions with dynamic styling
* VAST video ad support with IMA SDK integration
* Responsive native ads with flexible layouts
* Position override functionality for testing
* Comprehensive error handling and logging
* Production-ready SDKLogger implementation
* Unified API across all platforms
* Real-time position changes with visual feedback

## 0.0.1

* TODO: Describe initial release.
