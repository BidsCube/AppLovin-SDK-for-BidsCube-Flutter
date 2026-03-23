import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/logger.dart';
import '../core/ad_type.dart';
import '../core/ad_position.dart';
import '../core/constants.dart';

/// URL Builder for constructing API requests similar to iOS version
class URLBuilder {
  /// Build ad request URL for Flutter
  static Future<String?> buildAdRequestURL({
    required String placementId,
    required AdType adType,
    AdPosition position = AdPosition.unknown,
    int timeoutMs = 30000,
    bool debug = false,
    String? ctaText,
    String? baseURL,
  }) async {
    try {
      final base = baseURL ?? Constants.baseURL;
      final uri = Uri.parse(base);

      final queryParams = await _buildCommonQueryParams(
        placementId: placementId,
        adType: adType,
      );

      queryParams.addAll(_buildPrivacyQueryParams());

      if (ctaText != null) {
        queryParams['cta_text'] = ctaText;
      }

      final finalUri = uri.replace(queryParameters: queryParams);
      final url = finalUri.toString();

      SDKLogger.info('Building URL for ${adType.value} ad: $placementId');

      return url;
    } catch (e) {
      SDKLogger.error('Failed to build ad request URL', e);
      return null;
    }
  }

  /// Build common query parameters
  static Future<Map<String, String>> _buildCommonQueryParams({
    required String placementId,
    required AdType adType,
  }) async {
    final deviceInfo = await _getDeviceInfo();
    final packageInfo = await PackageInfo.fromPlatform();

    final params = <String, String>{
      'placementId': placementId,
      'app': '1',
      'bundle': packageInfo.packageName,
      'name': packageInfo.appName,
      'app_store_url': _getAppStoreURL(packageInfo.packageName),
      'language': deviceInfo['language'] ?? 'en',
      'deviceWidth': deviceInfo['deviceWidth'] ?? '1',
      'deviceHeight': deviceInfo['deviceHeight'] ?? '1',
      'ua': deviceInfo['userAgent'] ?? 'Flutter',
      'ifa': deviceInfo['advertisingId'] ?? '',
      'dnt': deviceInfo['doNotTrack'] ?? '0',
    };

    // Add ad type specific parameters
    switch (adType) {
      case AdType.banner:
        params['c'] = Constants.adTypeImage;
        params['m'] = Constants.methodApi;
        params['res'] = Constants.responseFormatJs;
        break;
      case AdType.video:
        params['id'] = placementId;
        params['c'] = Constants.adTypeVideo;
        params['m'] = Constants.methodXml;
        params['w'] = deviceInfo['deviceWidth'] ?? Constants.defaultDeviceWidth;
        params['h'] =
            deviceInfo['deviceHeight'] ?? Constants.defaultDeviceHeight;
        params['app_version'] = packageInfo.version;
        break;
      case AdType.native:
        params['c'] = Constants.adTypeNative;
        params['m'] = Constants.methodApi;
        params['res'] = Constants.responseFormatJson;
        break;
    }

    return params;
  }

  /// Build privacy query parameters
  static Map<String, String> _buildPrivacyQueryParams() {
    return {
      Constants.privacyGdprKey: _getGdprStatus(),
      Constants.privacyGdprConsentKey: Constants.defaultGdprConsent,
      Constants.privacyUsPrivacyKey: Constants.defaultUsPrivacy,
      Constants.privacyCcpaKey: Constants.defaultCcpa,
      Constants.privacyCoppaKey: Constants.defaultCoppa,
    };
  }

  /// Get device information
  static Future<Map<String, String>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      // PackageInfo is loaded in _buildCommonQueryParams when building URLs.

      // Get screen dimensions from platformDispatcher (physical pixels, not logical)
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final physicalSize = view.physicalSize;
      final screenWidth = physicalSize.width.toInt();
      final screenHeight = physicalSize.height.toInt();

      String platform;
      String language;

      if (Platform.isAndroid) {
        await deviceInfo.androidInfo;
        platform = 'Android';
        language = 'en';
      } else if (Platform.isIOS) {
        await deviceInfo.iosInfo;
        platform = 'iOS';
        language = 'en';
      } else {
        platform = 'Flutter';
        language = 'en';
      }
      final userAgent = await buildBrowserUserAgent();

      final deviceInfoMap = {
        'platform': platform,
        'deviceWidth': screenWidth.toString(),
        'deviceHeight': screenHeight.toString(),
        'userAgent': userAgent,
        'language': language,
        'advertisingId': await _getAdvertisingId(),
        'doNotTrack': await _getDoNotTrackStatus(),
      };

      SDKLogger.info('Device: $deviceInfoMap');

      return deviceInfoMap;
    } catch (e) {
      SDKLogger.error('Failed to get device info', e);
      // Fallback to platformDispatcher screen size or defaults
      try {
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        final physicalSize = view.physicalSize;
        final _ = view.devicePixelRatio;
        final screenWidth = (physicalSize.width).toInt();
        final screenHeight = (physicalSize.height).toInt();

        return {
          'platform': 'Flutter',
          'deviceWidth': screenWidth.toString(),
          'deviceHeight': screenHeight.toString(),
          'userAgent':
              'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          'language': 'en',
          'advertisingId': '',
          'doNotTrack': '0',
        };
      } catch (_) {
        return {
          'platform': 'Flutter',
          'deviceWidth': '375',
          'deviceHeight': '812',
          'userAgent':
              'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          'language': 'en',
          'advertisingId': '',
          'doNotTrack': '0',
        };
      }
    }
  }

  /// Build browser-like user agent for HTTP headers and `ua` query field.
  static Future<String> buildBrowserUserAgent() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        final version = info.version.release;
        final model = info.model.replaceAll(';', ' ');
        return 'Mozilla/5.0 (Linux; Android $version; $model) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';
      }
      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        final iosVersion = info.systemVersion.replaceAll('.', '_');
        return 'Mozilla/5.0 (iPhone; CPU iPhone OS $iosVersion like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/$iosVersion Mobile/15E148 Safari/604.1';
      }
      return 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
    } catch (_) {
      return 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
    }
  }

  /// Get advertising ID (real implementation)
  static Future<String> _getAdvertisingId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use Android ID as fallback for advertising ID
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use identifierForVendor as fallback for advertising ID
        return iosInfo.identifierForVendor ?? '';
      } else {
        // For other platforms, generate a unique identifier
        return 'flutter-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      SDKLogger.error('Failed to get advertising ID', e);
      return '';
    }
  }

  /// Get do not track status
  /// Returns '1' if DNT is enabled (user opted out of tracking), '0' if tracking is allowed
  static Future<String> _getDoNotTrackStatus() async {
    try {
      final platform = MethodChannel('com.bidscube.mobile_app_ads/ads');

      if (Platform.isAndroid) {
        try {
          // Call Android method to check advertising tracking status
          final bool isTrackingEnabled = await platform.invokeMethod<bool>(
                'isAdvertisingTrackingEnabled',
              ) ??
              true;
          final dntStatus = isTrackingEnabled
              ? '0'
              : '1'; // '0' = tracking allowed, '1' = tracking disabled
          SDKLogger.info(
            'DNT Status (Android): Advertising tracking ${isTrackingEnabled ? 'enabled' : 'disabled'} - DNT=$dntStatus',
          );
          return dntStatus;
        } catch (e) {
          SDKLogger.warning(
            'Failed to get Android advertising tracking status: $e',
          );
          return '0'; // Default: tracking allowed
        }
      } else if (Platform.isIOS) {
        try {
          // Call iOS method to check ASIdentifierManager.isAdvertisingTrackingEnabled
          final bool isTrackingEnabled = await platform.invokeMethod<bool>(
                'isAdvertisingTrackingEnabled',
              ) ??
              true;
          final dntStatus = isTrackingEnabled
              ? '0'
              : '1'; // '0' = tracking allowed, '1' = tracking disabled
          SDKLogger.info(
            'DNT Status (iOS): Advertising tracking ${isTrackingEnabled ? 'enabled' : 'disabled'} - DNT=$dntStatus',
          );
          return dntStatus;
        } catch (e) {
          SDKLogger.warning(
            'Failed to get iOS advertising tracking status: $e',
          );
          return '0'; // Default: tracking allowed
        }
      } else {
        SDKLogger.info('DNT Status: Unknown platform - tracking allowed (0)');
        return '0';
      }
    } catch (e) {
      SDKLogger.error(
        'Failed to get DNT status, defaulting to tracking allowed',
        e,
      );
      return '0'; // Default: tracking allowed on error
    }
  }

  /// Get GDPR status based on region
  static String _getGdprStatus() {
    try {
      final locale = Platform.localeName;
      final countryCode = locale.split('_').last.toUpperCase();

      return Constants.euCountries.contains(countryCode) ? '1' : '0';
    } catch (e) {
      return '0';
    }
  }

  /// Get appropriate app store URL based on platform
  static String _getAppStoreURL(String packageName) {
    if (Platform.isAndroid) {
      return 'https://play.google.com/store/apps/details?id=$packageName';
    } else if (Platform.isIOS) {
      // For iOS, we need the actual App Store ID, but for now use a placeholder
      return 'https://apps.apple.com/app/id$packageName';
    } else {
      return 'https://play.google.com/store/apps/details?id=$packageName';
    }
  }

  /// Build WebView URL for rendering ads
  static Future<String?> buildWebViewURL({
    required String placementId,
    required AdType adType,
    AdPosition position = AdPosition.unknown,
    String? baseURL,
  }) async {
    try {
      final apiURL = await buildAdRequestURL(
        placementId: placementId,
        adType: adType,
        position: position,
        baseURL: baseURL,
      );

      if (apiURL == null) return null;

      // For WebView rendering, we need to create an HTML page that loads the ad
      final htmlContent = _createWebViewHTML(apiURL, adType, placementId);
      return htmlContent;
    } catch (e) {
      SDKLogger.error('Failed to build WebView URL', e);
      return null;
    }
  }

  /// Create HTML content for WebView rendering
  static String _createWebViewHTML(
    String apiURL,
    AdType adType,
    String placementId,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body {
                margin: 0;
                padding: 0;
                width: 100%;
                height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                font-family: Arial, sans-serif;
            }
            .ad-container {
                width: 100%;
                height: 100%;
                position: relative;
                cursor: pointer;
                border-radius: 8px;
                overflow: hidden;
                box-shadow: 0 4px 8px rgba(0,0,0,0.1);
            }
            .ad-content {
                width: 100%;
                height: 100%;
                object-fit: cover;
                transition: transform 0.3s ease;
            }
            .ad-overlay {
                position: absolute;
                bottom: 0;
                left: 0;
                right: 0;
                background: linear-gradient(transparent, rgba(0,0,0,0.7));
                color: white;
                padding: 20px;
                text-align: center;
            }
            .ad-title {
                font-size: 18px;
                font-weight: bold;
                margin-bottom: 5px;
            }
            .ad-description {
                font-size: 14px;
                opacity: 0.9;
            }
            .loading {
                display: flex;
                align-items: center;
                justify-content: center;
                height: 100%;
                color: white;
                font-size: 16px;
            }
            .error {
                display: flex;
                align-items: center;
                justify-content: center;
                height: 100%;
                color: #ff6b6b;
                font-size: 16px;
                text-align: center;
                padding: 20px;
            }
        </style>
    </head>
    <body>
        <div class="ad-container" onclick="handleAdClick()">
            <div id="ad-content" class="loading">
                Loading ad...
            </div>
            <div class="ad-overlay">
                <div class="ad-title">${_getAdTypeTitle(adType)}</div>
                <div class="ad-description">Click to learn more</div>
            </div>
        </div>
        
        <script>
            let adData = null;
            
            async function loadAd() {
                try {
                    const response = await fetch('$apiURL');
                    if (response.ok) {
                        const data = await response.json();
                        adData = data;
                        renderAd(data);
                    } else {
                        showError('Failed to load ad: ' + response.status);
                    }
                } catch (error) {
                    showError('Network error: ' + error.message);
                }
            }
            
            function renderAd(data) {
                const container = document.getElementById('ad-content');
                container.className = 'ad-content';
                
                if (data.imageUrl) {
                    container.innerHTML = '<img src="' + data.imageUrl + '" alt="Ad" style="width: 100%; height: 100%; object-fit: cover;">';
                } else if (data.html) {
                    container.innerHTML = data.html;
                } else {
                    container.innerHTML = '<div style="display: flex; align-items: center; justify-content: center; height: 100%; background: #4CAF50; color: white; font-size: 18px; font-weight: bold;">Sample Ad</div>';
                }
            }
            
            function showError(message) {
                const container = document.getElementById('ad-content');
                container.className = 'error';
                container.innerHTML = message;
            }
            
            function handleAdClick() {
                if (adData && adData.clickUrl) {
                    window.open(adData.clickUrl, '_blank');
                }
                
                // Notify Flutter about the click
                if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('onAdClick', {
                        placementId: '$placementId'
                    });
                }
            }
            
            // Load ad when page loads
            loadAd();
        </script>
    </body>
    </html>
    ''';
  }

  /// Get ad type title for display
  static String _getAdTypeTitle(AdType adType) {
    switch (adType) {
      case AdType.banner:
        return 'Banner Ad';
      case AdType.video:
        return 'Video Ad';
      case AdType.native:
        return 'Native Ad';
    }
  }
}
