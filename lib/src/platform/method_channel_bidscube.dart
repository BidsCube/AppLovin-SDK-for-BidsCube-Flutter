import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'bidscube_platform.dart';
import '../core/sdk_config.dart';
import '../core/callbacks.dart';
import '../core/ad_type.dart';
import '../core/ad_position.dart';
import '../core/logger.dart';

/// Method channel implementation for BidsCube SDK
class MethodChannelBidscube extends BidscubePlatform {
  static const MethodChannel _channel = MethodChannel('bidscube_sdk');

  @override
  Future<void> initialize({required SDKConfig config}) async {
    try {
      await _channel.invokeMethod('initialize', config.toMap());
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
    AdPosition position, [
    double? borderRadius,
  ]) async {
    try {
      SDKLogger.info(
        'Requesting native banner ad view for placement: $placementId',
      );

      final result = await _channel.invokeMethod('getBannerAdView', {
        'placementId': placementId,
        'position': position.value,
      });

      SDKLogger.info('Received result from native: $result');

      if (callback != null) {
        _setCallback(placementId, callback);
      }

      final widget = _createAdWidget(result, placementId, callback);
      SDKLogger.info('Created ad widget: ${widget.runtimeType}');

      return widget;
    } on PlatformException catch (e) {
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
      final result = await _channel.invokeMethod('getVideoAdView', {
        'placementId': placementId,
        'position': position.value,
      });

      if (callback != null) {
        _setCallback(placementId, callback);
      }

      return _createAdWidget(result, placementId, callback);
    } on PlatformException catch (e) {
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
      final result = await _channel.invokeMethod('getNativeAdView', {
        'placementId': placementId,
        'position': position.value,
      });

      if (callback != null) {
        _setCallback(placementId, callback);
      }

      return _createAdWidget(result, placementId, callback);
    } on PlatformException catch (e) {
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
  bool isConsentRequired() {
    try {
      // For now, return a default value. In a real implementation,
      // this would call the native platform
      return false;
    } catch (e) {
      SDKLogger.error('Failed to check consent required', e);
      return false;
    }
  }

  @override
  bool hasAdsConsent() {
    try {
      // For now, return a default value. In a real implementation,
      // this would call the native platform
      return true;
    } catch (e) {
      SDKLogger.error('Failed to check ads consent', e);
      return false;
    }
  }

  @override
  bool hasAnalyticsConsent() {
    try {
      // For now, return a default value. In a real implementation,
      // this would call the native platform
      return true;
    } catch (e) {
      SDKLogger.error('Failed to check analytics consent', e);
      return false;
    }
  }

  @override
  Future<void> requestConsentInfoUpdate({AdCallback? callback}) async {
    try {
      await _channel.invokeMethod('requestConsentInfoUpdate');

      if (callback != null) {
        // Simulate consent info update
        callback.onAdLoading('consent_info_update');
        callback.onAdLoaded('consent_info_update');
      }
    } on PlatformException catch (e) {
      SDKLogger.error('Failed to request consent info update', e);
      rethrow;
    }
  }

  @override
  Future<void> showConsentForm({AdCallback? callback}) async {
    try {
      await _channel.invokeMethod('showConsentForm');

      if (callback != null) {
        // Simulate consent form shown and granted
        callback.onAdLoading('consent_form');
        callback.onAdLoaded('consent_form');
        callback.onAdDisplayed('consent_form');
      }
    } on PlatformException catch (e) {
      SDKLogger.error('Failed to show consent form', e);
      rethrow;
    }
  }

  @override
  String getConsentStatusSummary() {
    try {
      // For now, return a default summary. In a real implementation,
      // this would call the native platform
      return "required=false, ads=true, analytics=true";
    } catch (e) {
      SDKLogger.error('Failed to get consent status summary', e);
      return "required=false, ads=false, analytics=false";
    }
  }

  @override
  void enableConsentDebugMode(String testDeviceId) {
    try {
      // For now, just log. In a real implementation,
      // this would call the native platform
      SDKLogger.info('Consent debug mode enabled for device: $testDeviceId');
    } catch (e) {
      SDKLogger.error('Failed to enable consent debug mode', e);
    }
  }

  @override
  void resetConsent() {
    try {
      // For now, just log. In a real implementation,
      // this would call the native platform
      SDKLogger.info('Consent information reset');
    } catch (e) {
      SDKLogger.error('Failed to reset consent', e);
    }
  }

  @override
  void cleanup() {
    try {
      // For now, just log. In a real implementation,
      // this would call the native platform
      SDKLogger.info('SDK cleanup completed');
    } catch (e) {
      SDKLogger.error('Failed to cleanup SDK', e);
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

  void _setCallback(String placementId, AdCallback callback) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAdLoading':
          callback.onAdLoading(call.arguments['placementId']);
          break;
        case 'onAdLoaded':
          callback.onAdLoaded(call.arguments['placementId']);
          break;
        case 'onAdDisplayed':
          callback.onAdDisplayed(call.arguments['placementId']);
          break;
        case 'onAdFailed':
          callback.onAdFailed(
            call.arguments['placementId'],
            call.arguments['errorCode'],
            call.arguments['errorMessage'],
          );
          break;
        case 'onAdClicked':
          callback.onAdClicked(call.arguments['placementId']);
          break;
        case 'onAdClosed':
          callback.onAdClosed(call.arguments['placementId']);
          break;
        case 'onVideoAdStarted':
          callback.onVideoAdStarted(call.arguments['placementId']);
          break;
        case 'onVideoAdCompleted':
          callback.onVideoAdCompleted(call.arguments['placementId']);
          break;
        case 'onVideoAdSkipped':
          callback.onVideoAdSkipped(call.arguments['placementId']);
          break;
      }
    });
  }

  static const String _androidPlatformViewType = 'bidscube_native_ad';

  Widget _createAdWidget(
    dynamic result,
    String placementId,
    AdCallback? callback,
  ) {
    if (result is! Map) {
      return _placeholderAd(placementId, 'Invalid native response');
    }
    final viewKey = result['viewKey'] as String? ?? result['viewId'] as String?;
    if (viewKey == null || viewKey.isEmpty) {
      return _placeholderAd(placementId, 'Missing native view handle');
    }

    if (kIsWeb) {
      return _placeholderAd(
        placementId,
        'Native Bidscube views are not supported on web',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return SizedBox(
          width: 320,
          height: 240,
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
          width: 320,
          height: 240,
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
        );
    }
  }

  Widget _placeholderAd(String placementId, String message) {
    return SizedBox(
      width: 320,
      height: 240,
      child: Container(
        color: Colors.grey[300],
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child:
                Text('$message\n($placementId)', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
