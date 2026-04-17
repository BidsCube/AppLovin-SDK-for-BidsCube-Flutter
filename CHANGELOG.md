## 1.0.3+1

* **Version:** `1.0.3+1` (pub semver; same line as “1.0.3 patch 1”). `Constants.sdkVersion`, Android `build.gradle`, iOS podspec aligned.
* **Custom video player (Flutter-only):** `SDKConfig.customVideoPlayerBuilder` / `SDKConfigBuilder.customVideoPlayerBuilder(...)` — host returns a widget instead of the default IMA player when not using `onAdRenderOverride`.
* **Diagnostics:** `[BidsCubeDiag]` logs via `SDKDiagnostics` — init (native vs Flutter-only), AppLovin MAX hint in mediation mode, ad load phases, IMA lifecycle, native `getVideoAdView` / placement logs (Android Logcat / Xcode). `BidscubeSDK.initialize` applies `enableLogging` / `enableDebugMode` to `SDKLogger` before init.

## 1.0.3

* README streamlined (removed duplicate install / usage / config blocks; fixed example path `example/`); version **1.0.3**.

## 1.0.2

* **Self-contained native SDK:** Android prefers a local `*.aar` in `android/libs/` (filename contains `bidscube`); iOS vendors `ios/Frameworks/*.xcframework` when present, otherwise `bidscubeSdk` pod.
* **AppLovin MAX 13+:** Android `com.applovin:applovin-sdk:13.6.0`; iOS `AppLovinSDK ~> 13.0`. Minimum iOS **13.0**.

## 1.0.1

* **Ad request:** `SDKConfig.adRequestAuthority` (default `ssp-bcc-ads.com`); `baseURL` is a resolved getter; builder `baseURL(...)` normalizes like Android.
* **URI / query:** `normalizeAdRequestAuthority`, `buildSdkBaseUri`, per-format URL builders (banner / video / native); `onAdRenderOverride` order `(placementId, adm, position)`.
* **Android plugin:** optional `adRequestAuthority` on native `SDKConfig.Builder`.

## 1.0.0

* **Breaking:** `BidscubeIntegrationMode.levelPlayMediation` removed; `levelPlay` in maps maps to `appLovinMaxMediation`.
* AppLovin MAX mediation mode; Android/iOS plugins, PlatformViews, `example/`, native SDK via Maven or `mavenLocal()`.
