import 'ad_position.dart';
import 'bidscube_integration_mode.dart';

/// SDK Configuration for BidsCube Flutter SDK
class SDKConfig {
  /// Base URL for API requests
  final String baseURL;

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
    required this.baseURL,
    this.enableLogging = true,
    this.enableDebugMode = false,
    this.defaultAdTimeout = 30000,
    this.defaultAdPosition = AdPosition.unknown,
    this.enableTestMode = false,
    this.integrationMode = BidscubeIntegrationMode.directSdk,
  });

  /// Create SDKConfig from Map
  factory SDKConfig.fromMap(Map<String, dynamic> map) {
    return SDKConfig(
      baseURL: map['baseURL'] ?? '',
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
  String _baseURL = 'https://ssp-bcc-ads.com/sdk';
  bool _enableLogging = true;
  bool _enableDebugMode = false;
  int _defaultAdTimeout = 30000;
  AdPosition _defaultAdPosition = AdPosition.unknown;
  bool _enableTestMode = false;
  BidscubeIntegrationMode _integrationMode = BidscubeIntegrationMode.directSdk;

  /// Set base URL
  SDKConfigBuilder baseURL(String url) {
    _baseURL = url;
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
    return SDKConfig(
      baseURL: _baseURL,
      enableLogging: _enableLogging,
      enableDebugMode: _enableDebugMode,
      defaultAdTimeout: _defaultAdTimeout,
      defaultAdPosition: _defaultAdPosition,
      enableTestMode: _enableTestMode,
      integrationMode: _integrationMode,
    );
  }
}
