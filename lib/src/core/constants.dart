/// Constants for BidsCube Flutter SDK
/// Similar to iOS version but adapted for Flutter
class Constants {
  /// Base URL for API requests
  /// Use 10.0.2.2 for Android emulator to access host's localhost
  /// Use localhost or 127.0.0.1 for iOS simulator
  static const String baseURL =
      'https://ssp-bcc-ads.com/sdk'; // "http://10.0.2.2:3000/api/sdk"; //'https://ssp-bcc-ads.com/sdk';

  /// Default timeout in milliseconds
  static const int defaultTimeoutMs = 30000;

  /// Default ad position
  static const String defaultAdPosition = 'unknown';

  /// Ad Types
  static const String adTypeImage = 'b';
  static const String adTypeVideo = 'v';
  static const String adTypeNative = 'n';

  /// Response Formats
  static const String responseFormatJson = 'json';
  static const String responseFormatJs = 'js';
  static const String responseFormatXml = 'xml';

  /// Methods
  static const String methodApi = 'api';
  static const String methodXml = 'xml';

  /// User Agent Prefix
  static const String userAgentPrefix = 'BidscubeSDK-Flutter';

  /// SDK Version
  static const String sdkVersion = "1.0.0";

  /// Error Codes
  static const int errorCodeInvalidURL = -1;
  static const int errorCodeNetworkError = -2;
  static const int errorCodeInvalidResponse = -3;
  static const int errorCodeParsingError = -4;
  static const int errorCodeTimeoutError = -5;
  static const int errorCodeConsentError = -6;

  /// Error Messages
  static const String errorMessageFailedToBuildURL =
      'Failed to build request URL';
  static const String errorMessageInvalidResponse = 'Invalid response';
  static const String errorMessageNetworkError = 'Network error occurred';
  static const String errorMessageTimeoutError = 'Request timed out';
  static const String errorMessageConsentRequired = 'User consent required';
  static const String errorMessageSDKNotInitialized = 'SDK not initialized';

  /// Log Prefixes
  static const String logPrefixSDK = '📱 BidscubeSDK';
  static const String logPrefixURLBuilder = '🔗 URLBuilder';
  static const String logPrefixNetwork = '🌐 Network';
  static const String logPrefixImageAd = '🖼️ ImageAd';
  static const String logPrefixVideoAd = '🎥 VideoAd';
  static const String logPrefixNativeAd = '📱 NativeAd';
  static const String logPrefixError = 'Error:';
  static const String logPrefixSuccess = '';
  static const String logPrefixInfo = 'Info:';

  /// Animation Durations
  static const double animationDefaultDuration = 0.3;
  static const double animationFastDuration = 0.2;
  static const double animationSlowDuration = 0.5;

  /// Layout Constants
  static const double layoutDefaultMargin = 16.0;
  static const double layoutButtonSize = 40.0;
  static const double layoutCornerRadius = 8.0;
  static const double layoutBorderWidth = 1.0;

  /// Privacy Keys
  static const String privacyGdprKey = 'gdpr';
  static const String privacyGdprConsentKey = 'gdpr_consent';
  static const String privacyUsPrivacyKey = 'us_privacy';
  static const String privacyCcpaKey = 'ccpa';
  static const String privacyCoppaKey = 'coppa';
  static const String privacyDntKey = 'dnt';
  static const String privacyIfaKey = 'ifa';

  /// Query Parameters
  static const String queryParamPlacementId = 'placementId';
  static const String queryParamId = 'id';
  static const String queryParamContentType = 'c';
  static const String queryParamMethod = 'm';
  static const String queryParamResponse = 'res';
  static const String queryParamApp = 'app';
  static const String queryParamBundle = 'bundle';
  static const String queryParamName = 'name';
  static const String queryParamAppStoreURL = 'app_store_url';
  static const String queryParamLanguage = 'language';
  static const String queryParamDeviceWidth = 'deviceWidth';
  static const String queryParamDeviceHeight = 'deviceHeight';
  static const String queryParamWidth = 'w';
  static const String queryParamHeight = 'h';
  static const String queryParamUserAgent = 'ua';
  static const String queryParamAdvertisingId = 'ifa';
  static const String queryParamDoNotTrack = 'dnt';
  static const String queryParamAppVersion = 'app_version';
  static const String queryParamCtaText = 'cta_text';

  /// EU Countries for GDPR
  static const List<String> euCountries = [
    'AT',
    'BE',
    'BG',
    'HR',
    'CY',
    'CZ',
    'DK',
    'EE',
    'FI',
    'FR',
    'DE',
    'GR',
    'HU',
    'IE',
    'IT',
    'LV',
    'LT',
    'LU',
    'MT',
    'NL',
    'PL',
    'PT',
    'RO',
    'SK',
    'SI',
    'ES',
    'SE',
  ];

  /// Default Privacy Values
  static const String defaultGdprConsent = '0';
  static const String defaultUsPrivacy = '1';
  static const String defaultCcpa = '0';
  static const String defaultCoppa = '0';
  static const String defaultDoNotTrack = '0';

  /// Default Device Values
  static const String defaultDeviceWidth = '375';
  static const String defaultDeviceHeight = '812';
  static const String defaultLanguage = 'en';
  static const String defaultPlatform = 'Flutter';

  /// WebView Constants
  static const String webViewUserAgent = "BidscubeSDK-Flutter/1.0.0";
  static const String webViewJavaScriptChannel = 'flutter_inappwebview';

  /// Ad View Constants
  static const double defaultAdWidth = 320.0;
  static const double defaultAdHeight = 240.0;
  static const double defaultBannerHeight = 50.0;

  /// Network Constants
  static const int maxRetries = 3;
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration retryDelay = Duration(seconds: 1);
}
