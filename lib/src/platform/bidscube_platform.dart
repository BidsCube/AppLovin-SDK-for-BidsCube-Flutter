import 'package:flutter/widgets.dart';
import '../core/sdk_config.dart';
import '../core/callbacks.dart';
import '../core/ad_type.dart';
import '../core/ad_position.dart';

/// Platform abstraction for BidsCube SDK
abstract class BidscubePlatform {
  /// Initialize the platform
  Future<void> initialize({required SDKConfig config});

  /// Get Banner Ad View
  Future<Widget> getBannerAdView(
    String placementId,
    AdCallback? callback,
    AdPosition position, [
    double? borderRadius,
  ]);

  /// Get Video Ad View
  Future<Widget> getVideoAdView(
    String placementId,
    AdCallback? callback,
    AdPosition position, [
    double? borderRadius,
  ]);

  /// Get Native Ad View
  Future<Widget> getNativeAdView(
    String placementId,
    AdCallback? callback,
    AdPosition position, [
    double? borderRadius,
  ]);

  /// Request Ad
  Future<void> requestAd({
    required String placementId,
    required AdType adType,
    AdPosition position = AdPosition.unknown,
    AdCallback? callback,
  });

  /// Set Ad Callback
  Future<void> setAdCallback(String placementId, AdCallback callback);

  /// Remove Ad Callback
  Future<void> removeAdCallback(String placementId);

  /// Check if consent is required
  bool isConsentRequired();

  /// Check if ads consent is granted
  bool hasAdsConsent();

  /// Check if analytics consent is granted
  bool hasAnalyticsConsent();

  /// Request consent info update
  Future<void> requestConsentInfoUpdate({AdCallback? callback});

  /// Show consent form
  Future<void> showConsentForm({AdCallback? callback});

  /// Get consent status summary
  String getConsentStatusSummary();

  /// Enable consent debug mode
  void enableConsentDebugMode(String testDeviceId);

  /// Reset consent information
  void resetConsent();

  /// Cleanup SDK
  void cleanup();

  /// Get SKAdNetwork IDs from Info.plist
  Future<List<String>> getSKAdNetworkIds();
}
