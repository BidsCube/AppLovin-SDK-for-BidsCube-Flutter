/// Query parameters for native SSP requests (`c=n`, `m=s`).
///
/// Parity with Android `NativeAdUrlBuilder`: some fields use the literal string
/// `"null"` when the value is absent (empty), matching Java `String.valueOf` /
/// nullable concatenation behavior.
class NativeAdUrlBuilder {
  NativeAdUrlBuilder._();

  static String _literalNull(String? value) =>
      (value == null || value.isEmpty) ? 'null' : value;

  static Map<String, String> build({
    required String placementId,
    required String bundle,
    required String name,
    required String appVersion,
    required String ifa,
    required String dnt,
    required String appStoreUrl,
    required String ua,
    required String gdpr,
    required String gdprConsent,
    required String usPrivacy,
    required String ccpa,
    required String coppa,
    required String language,
    required String deviceWidth,
    required String deviceHeight,
    required String logicalWidth,
    required String logicalHeight,
  }) {
    return {
      'c': 'n',
      'm': 's',
      'id': placementId,
      'app': '1',
      'bundle': _literalNull(bundle),
      'name': _literalNull(name),
      'app_version': _literalNull(appVersion),
      'ifa': _literalNull(ifa),
      'dnt': dnt,
      'app_store_url': _literalNull(appStoreUrl),
      'ua': _literalNull(ua),
      'gdpr': gdpr,
      'gdpr_consent': gdprConsent,
      'us_privacy': usPrivacy,
      'ccpa': ccpa,
      'coppa': coppa,
      'language': _literalNull(language),
      'deviceWidth': deviceWidth,
      'deviceHeight': deviceHeight,
      'w': logicalWidth,
      'h': logicalHeight,
    };
  }
}
