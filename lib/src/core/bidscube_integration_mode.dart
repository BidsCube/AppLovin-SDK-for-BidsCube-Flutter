/// How the host app delivers Bidscube inventory.
///
/// - [directSdk]: Flutter (or native channel) requests and shows ads via this SDK.
/// - [appLovinMaxMediation]: Ads are loaded and shown only through **AppLovin MAX**.
///   Initialize native [BidscubeSDK] early from Dart so the MAX mediation adapter shares
///   the same instance.
enum BidscubeIntegrationMode {
  /// Direct integration — use `getBannerAdView` / `FlutterOnlyBidscube` / native views.
  directSdk,

  /// AppLovin MAX mediation — load/show via MAX; native `BidscubeMediationAdapter` calls
  /// `getImageAdView` / `showImageAd` / `showVideoAd` / `getNativeAdView` (→ `MaxNativeAd`).
  appLovinMaxMediation,
}

extension BidscubeIntegrationModeWire on BidscubeIntegrationMode {
  String get wireValue {
    switch (this) {
      case BidscubeIntegrationMode.directSdk:
        return 'direct';
      case BidscubeIntegrationMode.appLovinMaxMediation:
        return 'appLovinMax';
    }
  }

  /// True when Flutter must not own ad widgets — the MAX adapter uses native Bidscube.
  bool get isMediationMode =>
      this == BidscubeIntegrationMode.appLovinMaxMediation;
}

BidscubeIntegrationMode bidscubeIntegrationModeFromWire(String? value) {
  switch (value) {
    case 'appLovinMax':
      return BidscubeIntegrationMode.appLovinMaxMediation;
    // Legacy serialized configs from older releases (Level Play mode removed).
    case 'levelPlay':
      return BidscubeIntegrationMode.appLovinMaxMediation;
    default:
      return BidscubeIntegrationMode.directSdk;
  }
}
