import 'dart:convert';
import 'dart:io';
import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
import 'package:http/http.dart' as http;

/// HTTP client for making ad requests without native dependencies
class AdRequestClient {
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// The base URL for ad requests.
  final String baseUrl;

  /// The timeout duration for ad requests.
  final Duration timeout;
  final Map<String, String> _defaultHeaders;

  /// Creates an [AdRequestClient].
  ///
  /// [baseUrl] sets the base URL for ad requests. Defaults to [Constants.baseURL].
  /// [timeout] sets the request timeout. Defaults to 30 seconds.
  /// [defaultHeaders] sets default headers for all requests.
  AdRequestClient({
    String? baseUrl,
    Duration? timeout,
    Map<String, String>? defaultHeaders,
  })  : baseUrl = baseUrl ?? Constants.baseURL,
        timeout = timeout ?? _defaultTimeout,
        _defaultHeaders = defaultHeaders ?? {};

  /// Request native ad
  Future<Map<String, dynamic>?> requestNativeAd({
    required String placementId,
    Map<String, String>? additionalHeaders,
    AdCallback? callback,
  }) async {
    try {
      // Notify caller that loading started
      callback?.onAdLoading(placementId);
      SDKLogger.info('Requesting native ad: $placementId');

      final apiURL = await URLBuilder.buildAdRequestURL(
        placementId: placementId,
        adType: AdType.native,
        position: AdPosition.unknown,
      );

      if (apiURL == null) {
        throw AdRequestException('Failed to build request URL', -1);
      }

      final uri = Uri.parse(apiURL);
      final userAgent = await URLBuilder.buildBrowserUserAgent();
      final requestHeaders = {
        'Content-Type': 'application/json',
        'User-Agent': userAgent,
        ..._defaultHeaders,
        ...additionalHeaders ?? {},
      };

      final response =
          await http.get(uri, headers: requestHeaders).timeout(timeout);

      SDKLogger.info('Native ad response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        onAdReceived(data, callback, placementId);
        return data;
      } else {
        final msg = 'Failed to load native ad: ${response.statusCode}';
        callback?.onAdFailed(placementId, 'HTTP_${response.statusCode}', msg);
        throw AdRequestException(msg, response.statusCode);
      }
    } catch (e) {
      SDKLogger.error('Native ad request failed', e);
      callback?.onAdFailed(placementId, 'REQUEST_ERROR', e.toString());
      rethrow;
    }
  }

  /// Request banner ad
  Future<Map<String, dynamic>?> requestBannerAd({
    required String placementId,
    Map<String, String>? additionalHeaders,
    AdCallback? callback,
  }) async {
    try {
      // Notify caller that loading started
      callback?.onAdLoading(placementId);
      SDKLogger.info('Requesting banner ad: $placementId');

      final apiURL = await URLBuilder.buildAdRequestURL(
        placementId: placementId,
        adType: AdType.banner,
        position: AdPosition.unknown,
      );

      if (apiURL == null) {
        throw AdRequestException('Failed to build request URL', -1);
      }

      final uri = Uri.parse(apiURL);
      final userAgent = await URLBuilder.buildBrowserUserAgent();
      final requestHeaders = {
        'Content-Type': 'application/json',
        'User-Agent': userAgent,
        ..._defaultHeaders,
        ...additionalHeaders ?? {},
      };

      final response =
          await http.get(uri, headers: requestHeaders).timeout(timeout);

      SDKLogger.info('Banner ad response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        onAdReceived(data, callback, placementId);
        return data;
      } else {
        final msg = 'Failed to load banner ad: ${response.statusCode}';
        callback?.onAdFailed(placementId, 'HTTP_${response.statusCode}', msg);
        throw AdRequestException(msg, response.statusCode);
      }
    } catch (e) {
      SDKLogger.error('Banner ad request failed', e);
      callback?.onAdFailed(placementId, 'REQUEST_ERROR', e.toString());
      rethrow;
    }
  }

  /// Request video ad (VAST)
  Future<String?> requestVideoAd({
    required String placementId,
    Map<String, String>? additionalHeaders,
    AdCallback? callback,
  }) async {
    try {
      // Notify caller that loading started
      callback?.onAdLoading(placementId);
      SDKLogger.info('Requesting video ad: $placementId');

      final apiURL = await URLBuilder.buildAdRequestURL(
        placementId: placementId,
        adType: AdType.video,
        position: AdPosition.unknown,
      );

      if (apiURL == null) {
        throw AdRequestException('Failed to build request URL', -1);
      }

      final uri = Uri.parse(apiURL);
      final userAgent = await URLBuilder.buildBrowserUserAgent();
      final requestHeaders = {
        'Content-Type': 'application/xml',
        'User-Agent': userAgent,
        ..._defaultHeaders,
        ...additionalHeaders ?? {},
      };

      final response =
          await http.get(uri, headers: requestHeaders).timeout(timeout);

      SDKLogger.info('Video ad response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        onAdReceived(data, callback, placementId);
        return response.body;
      } else {
        final msg = 'Failed to load video ad: ${response.statusCode}';
        callback?.onAdFailed(placementId, 'HTTP_${response.statusCode}', msg);
        throw AdRequestException(msg, response.statusCode);
      }
    } catch (e) {
      SDKLogger.error('Video ad request failed', e);
      callback?.onAdFailed(placementId, 'REQUEST_ERROR', e.toString());
      rethrow;
    }
  }

  void onAdReceived(
    Map<String, dynamic> data,
    AdCallback? callback,
    String placementId,
  ) {
    if (callback?.onAdRenderOverride != null) {
      callback?.onAdRenderOverride!(
        data['adm'],
        placementId,
        AdPositionExtension.fromValue(data['position'] ?? 0),
      );
    } else {
      callback?.onAdLoaded(placementId);
    }
  }

  /// Get device information for ad targeting
  Map<String, String> getDeviceInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
    };
  }
}

class AdRequestException implements Exception {
  final String message;
  final int statusCode;

  AdRequestException(this.message, this.statusCode);

  @override
  String toString() => 'AdRequestException: $message (Status: $statusCode)';
}

class AdRequestConfig {
  final Duration timeout;
  final Map<String, String> defaultHeaders;
  final bool enableLogging;
  final bool enableRetry;
  final int maxRetries;

  const AdRequestConfig({
    this.timeout = const Duration(seconds: 30),
    this.defaultHeaders = const {},
    this.enableLogging = true,
    this.enableRetry = true,
    this.maxRetries = 3,
  });

  factory AdRequestConfig.defaultConfig() {
    return const AdRequestConfig();
  }

  factory AdRequestConfig.testConfig() {
    return const AdRequestConfig(enableLogging: true);
  }
}
