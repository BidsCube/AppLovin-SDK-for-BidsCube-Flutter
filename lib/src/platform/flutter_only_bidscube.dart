import 'dart:async';

import 'package:flutter/material.dart';
import 'bidscube_platform.dart';
import '../core/bidscube_integration_mode.dart';
import '../core/sdk_config.dart';
import '../core/callbacks.dart';
import '../core/ad_type.dart';
import '../core/ad_position.dart';
import '../core/logger.dart';
import '../core/ad_request_client.dart';
import '../views/webview_image_ad_view.dart';
import '../views/ima_vast_video_ad_view.dart';
import '../views/flutter_native_ad_view.dart';
import '../core/constants.dart';

/// Flutter-only implementation of BidsCube SDK
/// Uses WebView, video_player, and custom widgets instead of native code
class FlutterOnlyBidscube extends BidscubePlatform {
  late AdRequestClient _adClient;
  final Map<String, AdCallback> _callbacks = {};

  @override
  Future<void> initialize({required SDKConfig config}) async {
    if (config.integrationMode.isMediationMode) {
      throw StateError(
        'Flutter-only mode cannot be used with AppLovin MAX mediation.',
      );
    }
    try {
      _adClient = AdRequestClient(
        baseUrl: config.baseURL,
        timeout: Duration(milliseconds: config.defaultAdTimeout),
        defaultHeaders: {'X-SDK-Version': '1.0.0', 'X-Platform': 'Flutter'},
      );

      SDKLogger.info('BidsCube Flutter-only SDK initialized successfully');
    } catch (e) {
      SDKLogger.error('Failed to initialize Flutter-only SDK', e);
      rethrow;
    }
  }

  @override
  Future<Widget> getBannerAdView(
    String placementId,
    AdCallback? callback,
    AdPosition position, [
    double? borderRadius,
  ]) async {
    try {
      if (callback != null) {
        _callbacks[placementId] = callback;
        SDKLogger.info(
          'Registered callback for placement: $placementId (banner)',
        );

        // If host provided onAdRenderOverride, trigger request immediately so host can render the ad.
        if (callback.onAdRenderOverride != null) {
          // Fire-and-forget: request ad and let the callback handle rendering.
          requestAd(
            placementId: placementId,
            adType: AdType.banner,
            position: position,
            callback: callback,
          );
          // Return an empty placeholder since host will render the ad themselves
          return SizedBox(
            width: Constants.defaultAdWidth,
            height: Constants.defaultAdHeight,
          );
        }
      }

      // Use WebView for banner/image ads (default SDK rendering)
      return WebViewImageAdView(
        placementId: placementId,
        callback: callback,
        adType: AdType.banner,
        position: position,
        borderRadius: borderRadius,
      );
    } catch (e) {
      SDKLogger.error('Failed to get banner ad view', e);
      rethrow;
    }
  }

  @override
  Future<Widget> getVideoAdView(
    String placementId,
    AdCallback? callback,
    AdPosition position, [
    double? borderRadius,
  ]) async {
    try {
      if (callback != null) {
        _callbacks[placementId] = callback;
        SDKLogger.info(
          'Registered callback for placement: $placementId (video)',
        );

        if (callback.onAdRenderOverride != null) {
          requestAd(
            placementId: placementId,
            adType: AdType.video,
            position: position,
            callback: callback,
          );
          return SizedBox(
            width: Constants.defaultAdWidth,
            height: Constants.defaultAdHeight,
          );
        }
      }

      return ImaVastVideoAdView(
        placementId: placementId,
        callback: callback,
        baseUrl: _adClient.baseUrl,
        adType: AdType.video,
        position: position,
        borderRadius: borderRadius,
      );
    } catch (e) {
      SDKLogger.error('Failed to get video ad view', e);
      rethrow;
    }
  }

  @override
  Future<Widget> getNativeAdView(
    String placementId,
    AdCallback? callback,
    AdPosition position, [
    double? borderRadius,
  ]) async {
    try {
      if (callback != null) {
        _callbacks[placementId] = callback;
        SDKLogger.info(
          'Registered callback for placement: $placementId (native)',
        );

        if (callback.onAdRenderOverride != null) {
          requestAd(
            placementId: placementId,
            adType: AdType.native,
            position: position,
            callback: callback,
          );
          return SizedBox(
            width: Constants.defaultAdWidth,
            height: Constants.defaultAdHeight,
          );
        }
      }

      return FlutterNativeAdView(
        placementId: placementId,
        callback: callback,
        adType: AdType.native,
        position: position,
        borderRadius: borderRadius,
      );
    } catch (e) {
      SDKLogger.error('Failed to get native ad view', e);
      rethrow;
    }
  }

  @override
  Future<void> requestAd({
    required String placementId,
    required AdType adType,
    AdPosition position = AdPosition.unknown,
    AdCallback? callback,
  }) async {
    try {
      if (callback != null) {
        _callbacks[placementId] = callback;
      }

      // Ad request based on type
      switch (adType) {
        case AdType.banner:
          await _adClient.requestBannerAd(
            placementId: placementId,
            callback: callback,
          );
          break;
        case AdType.video:
          await _adClient.requestVideoAd(
            placementId: placementId,
            callback: callback,
          );
          break;
        case AdType.native:
          await _adClient.requestNativeAd(
            placementId: placementId,
            callback: callback,
          );
          break;
      }

      callback?.onAdLoaded(placementId);
    } catch (e) {
      SDKLogger.error('Failed to request ad', e);
      callback?.onAdFailed(placementId, 'REQUEST_ERROR', e.toString());
      rethrow;
    }
  }

  @override
  Future<void> setAdCallback(String placementId, AdCallback callback) async {
    _callbacks[placementId] = callback;
  }

  @override
  Future<void> removeAdCallback(String placementId) async {
    _callbacks.remove(placementId);
  }

  @override
  bool isConsentRequired() {
    // In a real implementation, this would check local storage or preferences
    return false;
  }

  @override
  bool hasAdsConsent() {
    // In a real implementation, this would check local storage or preferences
    return true;
  }

  @override
  bool hasAnalyticsConsent() {
    // In a real implementation, this would check local storage or preferences
    return true;
  }

  @override
  Future<void> requestConsentInfoUpdate({AdCallback? callback}) async {
    try {
      // Simulate consent info update
      await Future.delayed(const Duration(seconds: 1));

      callback?.onAdLoading('consent_info_update');
      callback?.onAdLoaded('consent_info_update');
    } catch (e) {
      SDKLogger.error('Failed to request consent info update', e);
      rethrow;
    }
  }

  @override
  Future<void> showConsentForm({AdCallback? callback}) async {
    try {
      // In a real implementation, this would show a consent form dialog
      // For now, just simulate the process
      callback?.onAdLoading('consent_form');
      await Future.delayed(const Duration(seconds: 2));
      callback?.onAdLoaded('consent_form');
      callback?.onAdDisplayed('consent_form');
    } catch (e) {
      SDKLogger.error('Failed to show consent form', e);
      rethrow;
    }
  }

  @override
  String getConsentStatusSummary() {
    return "required=false, ads=true, analytics=true";
  }

  @override
  void enableConsentDebugMode(String testDeviceId) {
    SDKLogger.info('Consent debug mode enabled for device: $testDeviceId');
  }

  @override
  void resetConsent() {
    SDKLogger.info('Consent information reset');
  }

  @override
  void cleanup() {
    _callbacks.clear();
    SDKLogger.info('Flutter-only SDK cleanup completed');
  }

  @override
  Future<List<String>> getSKAdNetworkIds() async {
    // In Flutter-only mode, we can't access native Info.plist
    // Return an empty list or mock data for testing
    SDKLogger.info('SKAdNetwork extraction not available in Flutter-only mode');
    return [];
  }
}
