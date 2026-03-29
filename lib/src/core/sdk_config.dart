import 'ad_request_authority_normalizer.dart';
import 'ad_position.dart';
import 'bidscube_integration_mode.dart';
import 'ssp_ad_uri_helper.dart';

/// SDK Configuration for BidsCube Flutter SDK
class SDKConfig {
  /// Normalized SSP authority (host or `host:port`, never a path or query).
  ///
  /// Default matches Android `DeviceInfo.DEFAULT_AD_REQUEST_AUTHORITY`
  /// (`ssp-bcc-ads.com`). The SDK builds requests as `https` + [adRequestAuthority] + `/sdk`.
  ///
  /// Do **not** pass a full URL with query parameters — the SDK appends `/sdk`
  /// and query fields. You may pass a host, `host:port`, or a short `https://` prefix
  /// without path/query; values are normalized like the Android SDK.
  final String adRequestAuthority;

  /// Resolved base URL for the SSP `/sdk` endpoint (`https` + [adRequestAuthority] + `/sdk`).
  ///
  /// Exposed for native bridges and HTTP clients that expect a full URL string.
  String get baseURL => buildSdkBaseUrlString(adRequestAuthority);

  /// Enable console logging
  final bool enableLogging;

  /// Enable debug mode
  final bool enableDebugMode;

  /// Default ad timeout in milliseconds
  final int defaultAdTimeout;

  /// Default ad position
  final AdPosition defaultAdPosition;

  /// Enable test mode
  final bool enableTestMode;

  /// Direct SDK vs AppLovin MAX mediation — see [BidscubeIntegrationMode].
  final BidscubeIntegrationMode integrationMode;

  const SDKConfig({
    required this.adRequestAuthority,
    this.enableLogging = true,
    this.enableDebugMode = false,
    this.defaultAdTimeout = 30000,
    this.defaultAdPosition = AdPosition.unknown,
    this.enableTestMode = false,
    this.integrationMode = BidscubeIntegrationMode.directSdk,
  });

  /// Create SDKConfig from Map
  factory SDKConfig.fromMap(Map<String, dynamic> map) {
    final authRaw = map['adRequestAuthority'] as String?;
    final baseRaw = map['baseURL'] as String?;

    String authority;
    if (authRaw != null && authRaw.trim().isNotEmpty) {
      authority = normalizeAdRequestAuthority(authRaw);
    } else if (baseRaw != null && baseRaw.trim().isNotEmpty) {
      authority = normalizeAdRequestAuthority(baseRaw);
    } else {
      authority = normalizeAdRequestAuthority(null);
    }

    return SDKConfig(
      adRequestAuthority: authority,
      enableLogging: map['enableLogging'] ?? true,
      enableDebugMode: map['enableDebugMode'] ?? false,
      defaultAdTimeout: map['defaultAdTimeout'] ?? 30000,
      defaultAdPosition: AdPosition.values.firstWhere(
        (position) => position.value == map['defaultAdPosition'],
        orElse: () => AdPosition.unknown,
      ),
      enableTestMode: map['enableTestMode'] ?? false,
      integrationMode: bidscubeIntegrationModeFromWire(
        map['integrationMode'] as String?,
      ),
    );
  }

  /// Convert SDKConfig to Map
  Map<String, dynamic> toMap() {
    return {
      'adRequestAuthority': adRequestAuthority,
      'baseURL': baseURL,
      'enableLogging': enableLogging,
      'enableDebugMode': enableDebugMode,
      'defaultAdTimeout': defaultAdTimeout,
      'defaultAdPosition': defaultAdPosition.value,
      'enableTestMode': enableTestMode,
      'integrationMode': integrationMode.wireValue,
    };
  }

  /// Builder pattern for SDKConfig
  static SDKConfigBuilder builder() => SDKConfigBuilder();
}

/// Builder class for SDKConfig
class SDKConfigBuilder {
  String? _adRequestAuthorityInput;
  bool _enableLogging = true;
  bool _enableDebugMode = false;
  int _defaultAdTimeout = 30000;
  AdPosition _defaultAdPosition = AdPosition.unknown;
  bool _enableTestMode = false;
  BidscubeIntegrationMode _integrationMode = BidscubeIntegrationMode.directSdk;

  /// Sets the SSP ad-request **authority** (host or `host:port`).
  ///
  /// Default: production `ssp-bcc-ads.com`. Pass `null` or omit to keep the default.
  /// The value is normalized (trim, percent-decode, strip `https://`, path, and query).
  SDKConfigBuilder adRequestAuthority(String? authority) {
    _adRequestAuthorityInput = authority;
    return this;
  }

  /// Legacy: accepts a full `https://host/sdk` URL or host-only; normalized to
  /// [SDKConfig.adRequestAuthority] the same way as on Android.
  SDKConfigBuilder baseURL(String url) {
    _adRequestAuthorityInput = url;
    return this;
  }

  /// Enable logging
  SDKConfigBuilder enableLogging(bool enable) {
    _enableLogging = enable;
    return this;
  }

  /// Enable debug mode
  SDKConfigBuilder enableDebugMode(bool enable) {
    _enableDebugMode = enable;
    return this;
  }

  /// Set default ad timeout
  SDKConfigBuilder defaultAdTimeout(int timeout) {
    _defaultAdTimeout = timeout;
    return this;
  }

  /// Set default ad position
  SDKConfigBuilder defaultAdPosition(AdPosition position) {
    _defaultAdPosition = position;
    return this;
  }

  /// Enable test mode
  SDKConfigBuilder enableTestMode(bool enable) {
    _enableTestMode = enable;
    return this;
  }

  /// AppLovin MAX mediation vs direct SDK (default: direct).
  SDKConfigBuilder integrationMode(BidscubeIntegrationMode mode) {
    _integrationMode = mode;
    return this;
  }

  /// Build SDKConfig
  SDKConfig build() {
    final authority = normalizeAdRequestAuthority(_adRequestAuthorityInput);
    return SDKConfig(
      adRequestAuthority: authority,
      enableLogging: _enableLogging,
      enableDebugMode: _enableDebugMode,
      defaultAdTimeout: _defaultAdTimeout,
      defaultAdPosition: _defaultAdPosition,
      enableTestMode: _enableTestMode,
      integrationMode: _integrationMode,
    );
  }
}
