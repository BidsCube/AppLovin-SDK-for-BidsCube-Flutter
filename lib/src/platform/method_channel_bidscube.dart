import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'bidscube_platform.dart';
import '../core/sdk_config.dart';
import '../core/callbacks.dart';
import '../core/ad_type.dart';
import '../core/ad_position.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../core/sdk_diagnostics.dart';

/// Method channel implementation for BidsCube SDK
class MethodChannelBidscube extends BidscubePlatform {
  static const MethodChannel _channel = MethodChannel('bidscube_sdk');

  final Map<String, AdCallback> _callbacks = {};
  bool _handlerInstalled = false;

  bool _cachedConsentRequired = false;
  bool _cachedAdsConsent = false;
  bool _cachedAnalyticsConsent = false;
  String _cachedConsentSummary = 'required=false, ads=false, analytics=false';

  @override
  Future<void> initialize({required SDKConfig config}) async {
    try {
      SDKDiagnostics.logAdRequestPhase(
        placementId: '_native_',
        phase: 'methodChannel_initialize_invoke',
      );
      await _channel.invokeMethod('initialize', config.toMap());
      await _refreshConsentCache();
      SDKLogger.info('BidsCube SDK initialized successfully');
    } on PlatformException catch (e) {
      SDKLogger.error('Failed to initialize BidsCube SDK', e);
      rethrow;
    }
  }

  @override
  Future<Widget> getBannerAdView(
    String placementId,
    AdCallback? callback,
    AdPosition position, {
    double? borderRadius,
    double width = Constants.defaultAdWidth,
    double height = Constants.defaultBannerHeight,
  }) async {
    return _getAdView(
      method: 'getBannerAdView',
      placementId: placementId,
      callback: callback,
      position: position,
      width: width,
      height: height,
      fallbackWidth: Constants.defaultAdWidth,
      fallbackHeight: Constants.defaultBannerHeight,
    );
  }

  @override
  Future<Widget> getVideoAdView(
    String placementId,
    AdCallback? callback,
    AdPosition position, {
    double? borderRadius,
    double width = Constants.defaultAdWidth,
    double height = 180,
  }) async {
    SDKDiagnostics.logAdRequestPhase(
      placementId: placementId,
      phase: 'native_getVideoAdView_invoke',
    );
    SDKDiagnostics.logVideoPlayerRoute(
      placementId: placementId,
      route: 'native_platform_view',
    );
    try {
      final widget = await _getAdView(
        method: 'getVideoAdView',
        placementId: placementId,
        callback: callback,
        position: position,
        width: width,
        height: height,
        fallbackWidth: Constants.defaultAdWidth,
        fallbackHeight: 180,
      );
      SDKDiagnostics.logAdRequestPhase(
        placementId: placementId,
        phase: 'native_platformView_ready',
        detail: widget.runtimeType.toString(),
      );
      return widget;
    } on PlatformException catch (e) {
      SDKDiagnostics.logAdRequestPhase(
        placementId: placementId,
        phase: 'native_getVideoAdView_failed',
        detail: e.message,
      );
      SDKLogger.error('Failed to get video ad view', e);
      rethrow;
    }
  }

  @override
  Future<Widget> getNativeAdView(
    String placementId,
    AdCallback? callback,
    AdPosition position, {
    double? borderRadius,
    double width = Constants.defaultAdWidth,
    double height = 250,
  }) async {
    return _getAdView(
      method: 'getNativeAdView',
      placementId: placementId,
      callback: callback,
      position: position,
      width: width,
      height: height,
      fallbackWidth: Constants.defaultAdWidth,
      fallbackHeight: 250,
    );
  }

  Future<Widget> _getAdView({
    required String method,
    required String placementId,
    AdCallback? callback,
    AdPosition position = AdPosition.unknown,
    required double width,
    required double height,
    required double fallbackWidth,
    required double fallbackHeight,
  }) async {
    try {
      SDKLogger.info(
        'Requesting native ad view ($method) for placement: $placementId',
      );

      final result = await _channel.invokeMethod(method, {
        'placementId': placementId,
        'position': position.value,
        'width': width,
        'height': height,
      });

      if (callback != null) {
        _setCallback(placementId, callback);
      }

      return _createAdWidget(
        result,
        placementId,
        fallbackWidth: fallbackWidth,
        fallbackHeight: fallbackHeight,
      );
    } on PlatformException catch (e) {
      SDKLogger.error('Failed to get ad view via $method', e);
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
      await _channel.invokeMethod('requestAd', {
        'placementId': placementId,
        'adType': adType.value,
        'position': position.value,
      });

      if (callback != null) {
        _setCallback(placementId, callback);
      }
    } on PlatformException catch (e) {
      SDKLogger.error('Failed to request ad', e);
      rethrow;
    }
  }

  @override
  Future<void> setAdCallback(String placementId, AdCallback callback) async {
    _setCallback(placementId, callback);
  }

  @override
  Future<void> removeAdCallback(String placementId) async {
    _callbacks.remove(placementId);
    try {
      await _channel.invokeMethod('removeAdCallback', {
        'placementId': placementId,
      });
    } on PlatformException catch (e) {
      SDKLogger.error('Failed to remove ad callback', e);
      rethrow;
    }
  }

  @override
  bool isConsentRequired() => _cachedConsentRequired;

  @override
  bool hasAdsConsent() => _cachedAdsConsent;

  @override
  bool hasAnalyticsConsent() => _cachedAnalyticsConsent;

  @override
  Future<void> requestConsentInfoUpdate({AdCallback? callback}) async {
    try {
      if (callback != null) {
        _setCallback('_consent_', callback);
      }
      await _channel.invokeMethod('requestConsentInfoUpdate');
      await _refreshConsentCache();
    } on PlatformException catch (e) {
      SDKLogger.error('Failed to request consent info update', e);
      rethrow;
    }
  }

  @override
  Future<void> showConsentForm({AdCallback? callback}) async {
    try {
      if (callback != null) {
        _setCallback('_consent_', callback);
      }
      await _channel.invokeMethod('showConsentForm');
      await _refreshConsentCache();
    } on PlatformException catch (e) {
      SDKLogger.error('Failed to show consent form', e);
      rethrow;
    }
  }

  @override
  String getConsentStatusSummary() => _cachedConsentSummary;

  @override
  void enableConsentDebugMode(String testDeviceId) {
    try {
      _channel.invokeMethod('enableConsentDebugMode', {
        'testDeviceId': testDeviceId,
      });
    } catch (e) {
      SDKLogger.error('Failed to enable consent debug mode', e);
    }
  }

  @override
  void resetConsent() {
    try {
      _channel.invokeMethod('resetConsent');
      unawaited(_refreshConsentCache());
    } catch (e) {
      SDKLogger.error('Failed to reset consent', e);
    }
  }

  @override
  void cleanup() {
    _callbacks.clear();
    _handlerInstalled = false;
    _channel.setMethodCallHandler(null);
    SDKLogger.info('SDK cleanup completed');
  }

  @override
  Future<void> showVideoAdFromVast(
    String placementId,
    String vastXml, {
    AdCallback? callback,
  }) async {
    try {
      if (callback != null) {
        _setCallback(placementId, callback);
      }
      await _channel.invokeMethod('showVideoAdFromVast', {
        'placementId': placementId,
        'vastXml': vastXml,
      });
    } on PlatformException catch (e) {
      SDKLogger.error('Failed to show video ad from VAST', e);
      rethrow;
    }
  }

  @override
  Future<List<String>> getSKAdNetworkIds() async {
    try {
      final result = await _channel.invokeMethod('getSKAdNetworkIds');
      if (result is List) {
        return result.cast<String>();
      }
      return [];
    } on PlatformException catch (e) {
      SDKLogger.error('Failed to get SKAdNetwork IDs', e);
      return [];
    }
  }

  Future<void> _refreshConsentCache() async {
    try {
      _cachedConsentRequired =
          await _channel.invokeMethod<bool>('isConsentRequired') ?? false;
      _cachedAdsConsent =
          await _channel.invokeMethod<bool>('hasAdsConsent') ?? false;
      _cachedAnalyticsConsent =
          await _channel.invokeMethod<bool>('hasAnalyticsConsent') ?? false;
      _cachedConsentSummary =
          await _channel.invokeMethod<String>('getConsentStatusSummary') ??
              _cachedConsentSummary;
    } on PlatformException catch (e) {
      SDKLogger.error('Failed to refresh consent cache', e);
    }
  }

  void _setCallback(String placementId, AdCallback callback) {
    _callbacks[placementId] = callback;
    _ensureHandlerInstalled();
  }

  void _ensureHandlerInstalled() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  Future<void> _handleNativeCallback(MethodCall call) async {
    final args = call.arguments;
    if (args is! Map) return;
    final map = Map<String, dynamic>.from(args);
    final placementId = map['placementId'] as String?;
    if (placementId == null) return;
    final callback = _callbacks[placementId];
    if (callback == null) return;

    switch (call.method) {
      case 'onAdLoading':
        callback.onAdLoading(placementId);
        break;
      case 'onAdLoaded':
        callback.onAdLoaded(placementId);
        break;
      case 'onAdDisplayed':
        callback.onAdDisplayed(placementId);
        break;
      case 'onAdFailed':
        callback.onAdFailed(
          placementId,
          map['errorCode']?.toString() ?? 'unknown',
          map['errorMessage']?.toString() ?? 'Unknown error',
        );
        break;
      case 'onAdClicked':
        callback.onAdClicked(placementId);
        break;
      case 'onAdClosed':
        callback.onAdClosed(placementId);
        break;
      case 'onVideoAdStarted':
        callback.onVideoAdStarted(placementId);
        break;
      case 'onVideoAdCompleted':
        callback.onVideoAdCompleted(placementId);
        break;
      case 'onVideoAdSkipped':
        callback.onVideoAdSkipped(placementId);
        break;
      case 'onConsentInfoUpdated':
      case 'onConsentFormShown':
      case 'onConsentGranted':
      case 'onConsentDenied':
      case 'onConsentNotRequired':
        callback.onAdLoaded(placementId);
        unawaited(_refreshConsentCache());
        break;
      case 'onConsentStatusChanged':
        unawaited(_refreshConsentCache());
        break;
    }
  }

  static const String _androidPlatformViewType = 'bidscube_native_ad';

  Widget _createAdWidget(
    dynamic result,
    String placementId, {
    required double fallbackWidth,
    required double fallbackHeight,
  }) {
    if (result is! Map) {
      return _placeholderAd(
        placementId,
        'Invalid native response',
        fallbackWidth,
        fallbackHeight,
      );
    }
    final viewKey = result['viewKey'] as String? ?? result['viewId'] as String?;
    if (viewKey == null || viewKey.isEmpty) {
      return _placeholderAd(
        placementId,
        'Missing native view handle',
        fallbackWidth,
        fallbackHeight,
      );
    }

    final width = (result['width'] as num?)?.toDouble() ?? fallbackWidth;
    final height = (result['height'] as num?)?.toDouble() ?? fallbackHeight;

    if (kIsWeb) {
      return _placeholderAd(
        placementId,
        'Native Bidscube views are not supported on web',
        width,
        height,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return SizedBox(
          width: width,
          height: height,
          child: AndroidView(
            viewType: _androidPlatformViewType,
            creationParams: <String, dynamic>{
              'viewKey': viewKey,
              'placementId': placementId,
            },
            creationParamsCodec: const StandardMessageCodec(),
          ),
        );
      case TargetPlatform.iOS:
        return SizedBox(
          width: width,
          height: height,
          child: UiKitView(
            viewType: viewKey,
            creationParams: <String, dynamic>{'placementId': placementId},
            creationParamsCodec: const StandardMessageCodec(),
          ),
        );
      default:
        return _placeholderAd(
          placementId,
          'Native Bidscube views are only supported on Android and iOS',
          width,
          height,
        );
    }
  }

  Widget _placeholderAd(
    String placementId,
    String message,
    double width,
    double height,
  ) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        color: Colors.grey[300],
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '$message\n($placementId)',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
