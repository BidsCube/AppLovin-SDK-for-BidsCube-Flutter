/// Query parameters for video SSP requests (`c=v`, `m=xml`).
///
/// Parity with Android `VideoAdUrlBuilder`.
class VideoAdUrlBuilder {
  VideoAdUrlBuilder._();

  static Map<String, String> build({
    required String placementId,
    required String bundle,
    required String name,
    required String appVersion,
    required String ifa,
    required String dnt,
    required String appStoreUrl,
    required String ua,
    required String language,
    required String deviceWidth,
    required String deviceHeight,
    required String screenWidth,
    required String screenHeight,
  }) {
    return {
      'c': 'v',
      'm': 'xml',
      'id': placementId,
      'app': '1',
      'w': screenWidth,
      'h': screenHeight,
      'bundle': bundle,
      'name': name,
      'app_version': appVersion,
      'ifa': ifa,
      'dnt': dnt,
      'app_store_url': appStoreUrl,
      'ua': ua,
      'language': language,
      'deviceWidth': deviceWidth,
      'deviceHeight': deviceHeight,
    };
  }
}
