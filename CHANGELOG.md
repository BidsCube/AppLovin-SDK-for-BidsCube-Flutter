## 1.0.2

* **Self-contained native SDK:** Android prefers a local `*.aar` in `android/libs/` (filename contains `bidscube`); iOS vendors every `ios/Frameworks/*.xcframework` when present, otherwise falls back to the `bidscubeSdk` pod. See README **Self-contained native SDK** and `android/libs/README.md` / `ios/Frameworks/README.md`.
* **AppLovin MAX 13+:** Android `implementation com.applovin:applovin-sdk:13.6.0`; iOS `AppLovinSDK ~> 13.0`. Minimum iOS platform for the pod and example **13.0**.

## 1.0.1

* **Ad request configuration:** `SDKConfig.adRequestAuthority` (default `ssp-bcc-ads.com`, aligned with Android `DEFAULT_AD_REQUEST_AUTHORITY`). Legacy `SDKConfig.baseURL` remains a **getter** resolving to `https://<authority>/sdk`; `SDKConfig.builder().baseURL(...)` still accepts a full or partial URL and normalizes it to authority (Android `SDKConfig` parity).
* **Normalization & URI:** `normalizeAdRequestAuthority`, `buildSdkBaseUri` / `SspParsedAuthority` match Android authority handling and `SspAdUriHelper` port/IPv6 rules so `127.0.0.1:8787` and `[::1]:8787` use real URI ports (no `%3A` in the host).
* **Query parameters:** Per-format builders (`ImageAdUrlBuilder`, `VideoAdUrlBuilder`, `NativeAdUrlBuilder`) align with Android (`c`/`m`, native `m=s`, banner privacy params omitted; native includes GDPR/CCPA fields and `"null"` literals where applicable).
* **HTTP:** `AdRequestClient` GET requests no longer send a `Content-Type` body header; `onAdRenderOverride` invocation order fixed to `(placementId, adm, position)`.
* **Docs:** README section **Ad request endpoint (reference)**; example app supports `--dart-define=BIDSCUBE_SSP_AUTHORITY=...`.
* **Android plugin:** forwards `adRequestAuthority` to native `SDKConfig.Builder` when the native SDK exposes a matching setter.

## 1.0.0

* **Breaking**: Removed `BidscubeIntegrationMode.levelPlayMediation`. Mediation targets **AppLovin MAX only** (`appLovinMaxMediation`). For backward compatibility, `SDKConfig` maps deserialized with `integrationMode: 'levelPlay'` still resolve to `appLovinMaxMediation`.
* Documentation and comments: IronSource / Level Play removed; README is MAX-centric.

* Version aligned with Bidscube stack **1.0.0** (Android, iOS, Unity).
* **Mediation**: `BidscubeIntegrationMode.appLovinMaxMediation` for AppLovin MAX (native init only, no `get*AdView` from Flutter). README documents MAX flow (`getImageAdView` / `showImageAd` / `showVideoAd` / `MaxNativeAd`).
* **Android plugin**: Flutter plugin (`android/src/main/...`, `BidscubeSdkFlutterPlugin`), native SDK `com.bidscube:bidscube-sdk:1.0.0` + `mavenLocal()` for local dev, `ActivityAware`, callbacks to Dart, PlatformView `bidscube_native_ad`.
* **iOS plugin**: banner via `getImageAdView`, unique `viewId`, callbacks to Dart.
* **Dart**: `AndroidView` on Android for native ads; full `example/`.
* Android: transitive SDK dependencies, desugar 2.1.3 in example, minSdk 24.
* Version / pub.dev compliance updates

* TODO: Describe initial release.
