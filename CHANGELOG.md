## 1.2.3 - 2026-07-08

* **Release:** AppLovin MAX Flutter integration — native adapter wiring on Android/iOS, mediation vs direct SDK modes, consent bridge, callback registry, PlatformView sizing.
* **Android:** `applovin-bidscube-max-adapter-full-video:1.2.10` (Maven POM, no `@aar`); local AAR from `${projectDir}/libs/`.
* **iOS:** `BidscubeSDKAppLovin ~> 1.1.0`; iOS 15.0+.
* **Docs:** README, archive hygiene (`.pubignore`, `git archive` verification), `scripts/validate-package.sh`.
* **Version:** `1.2.3` — `Constants.sdkVersion`, Android `build.gradle`, iOS podspec aligned.

## 1.2.2

* **AppLovin MAX wiring:** Android default dependency is `com.bidscube:applovin-bidscube-max-adapter-full-video:1.2.10` (local `applovin-bidscube-max-adapter-*.aar` override in `android/libs/`). iOS depends on `BidscubeSDKAppLovin ~> 1.1.0` (`ALBidscubeMediationAdapter`).
* **Mediation vs direct:** `appLovinMaxMediation` initializes native runtime only; load/show via `applovin_max`. Direct widget APIs remain blocked in MAX mode.
* **Consent bridge:** native `isConsentRequired`, `hasAdsConsent`, `hasAnalyticsConsent`, `getConsentStatusSummary`, `enableConsentDebugMode`, `resetConsent`, `requestConsentInfoUpdate`, `showConsentForm` wired on Android/iOS (no stub success values).
* **Callbacks:** per-placement callback registry in `MethodChannelBidscube`.
* **PlatformView sizing:** banner 320×50, video 320×180, native 320×250 defaults; width/height params on direct widget APIs.
* **QA:** sibling `BidscubeFlutterAppLovinTestApp/` for MAX mediation; in-repo `example/` stays direct SDK / Flutter-only.
* **Validation:** `scripts/validate-package.sh`; Android `verifyBidscubeMaxAdapter` Gradle task.
* **Version:** `1.2.2` — `Constants.sdkVersion`, Android `build.gradle`, iOS podspec aligned.
* **VAST companion preview:** `VastParser` reads Companion `StaticResource` and `CompanionClickThrough`; skip offset from `Linear@skipoffset`.
* **End card UI:** [`VastEndCardView`](lib/src/views/vast_end_card_view.dart) — fullscreen app-store style layout when companion preview is present; end card shown only when preview exists.
* **VAST from markup:** `BidscubeSDK.showVideoAdFromVast` / [`VastVideoAdView`](lib/src/views/vast_video_ad_view.dart); Android plugin uses reflection for `showVideoAdFromVastMarkup` when older AAR is on the classpath.
* **QA:** [`QaVastFixtures`](lib/src/core/qa_vast_fixtures.dart) + example **QA — VAST preview tests** screen.

## 1.0.3+1

* **Version:** `1.0.3+1` (pub semver; same line as “1.0.3 patch 1”). `Constants.sdkVersion`, Android `build.gradle`, iOS podspec aligned.
* **Custom video player (Flutter-only):** `SDKConfig.customVideoPlayerBuilder` / `SDKConfigBuilder.customVideoPlayerBuilder(...)` — host returns a widget instead of the default IMA player when not using `onAdRenderOverride`.
* **Diagnostics:** `[BidsCubeDiag]` logs via `SDKDiagnostics` — init (native vs Flutter-only), AppLovin MAX hint in mediation mode, ad load phases, IMA lifecycle, native `getVideoAdView` / placement logs (Android Logcat / Xcode). `BidscubeSDK.initialize` applies `enableLogging` / `enableDebugMode` to `SDKLogger` before init.
* **VAST preview / end card:** `VastParser` reads Companion `StaticResource` when present; [`VastVideoAdView`](lib/src/views/vast_video_ad_view.dart) keeps existing fallback end card when preview is absent. QA fixtures in [`QaVastFixtures`](lib/src/core/qa_vast_fixtures.dart); example app **QA — VAST preview tests** screen.

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
