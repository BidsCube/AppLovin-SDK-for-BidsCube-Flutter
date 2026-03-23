import 'logger.dart';
import 'ad_position.dart';

/// Ad callback interface for BidsCube SDK
abstract class AdCallback {
  /// Called when ad starts loading
  void onAdLoading(String placementId);

  /// Called when ad is loaded successfully
  void onAdLoaded(String placementId);

  /// Called when ad is displayed
  void onAdDisplayed(String placementId);

  /// Called when ad fails to load or display
  void onAdFailed(String placementId, String errorCode, String errorMessage);

  /// Called when ad is clicked
  void onAdClicked(String placementId);

  /// Called when ad is closed
  void onAdClosed(String placementId);

  /// Called when video ad starts playing
  void onVideoAdStarted(String placementId);

  /// Called when video ad completes
  void onVideoAdCompleted(String placementId);

  /// Called when video ad is skipped
  void onVideoAdSkipped(String placementId);

  /// Called when ad render is overridden
  void Function(String placementId, String adm, AdPosition position)?
      onAdRenderOverride;
}

/// Default implementation of AdCallback
class DefaultAdCallback implements AdCallback {
  @override
  void onAdLoading(String placementId) {
    SDKLogger.info('Ad loading: $placementId');
  }

  @override
  void onAdLoaded(String placementId) {
    SDKLogger.info('Ad loaded: $placementId');
  }

  @override
  void onAdDisplayed(String placementId) {
    SDKLogger.info('Ad displayed: $placementId');
  }

  @override
  void onAdFailed(String placementId, String errorCode, String errorMessage) {
    SDKLogger.error(
      'Ad failed: $placementId - $errorMessage (Code: $errorCode)',
    );
  }

  @override
  void onAdClicked(String placementId) {
    SDKLogger.info('Ad clicked: $placementId');
  }

  @override
  void onAdClosed(String placementId) {
    SDKLogger.info('Ad closed: $placementId');
  }

  @override
  void onVideoAdStarted(String placementId) {
    SDKLogger.info('Video ad started: $placementId');
  }

  @override
  void onVideoAdCompleted(String placementId) {
    SDKLogger.info('Video ad completed: $placementId');
  }

  @override
  void onVideoAdSkipped(String placementId) {
    SDKLogger.info('Video ad skipped: $placementId');
  }

  @override
  void Function(String placementId, String adm, AdPosition position)?
      onAdRenderOverride;
}
