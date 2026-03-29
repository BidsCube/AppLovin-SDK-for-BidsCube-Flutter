/// Query parameters for image / banner SSP requests (`c=b`, `m=api`, `res=js`).
///
/// Parity with Android `ImageAdUrlBuilder`.
class ImageAdUrlBuilder {
  ImageAdUrlBuilder._();

  static Map<String, String> build({
    required String placementId,
    required String bundle,
    required String name,
    required String appStoreUrl,
    required String language,
    required String deviceWidth,
    required String deviceHeight,
    required String ua,
    required String ifa,
    required String dnt,
  }) {
    return {
      'c': 'b',
      'm': 'api',
      'res': 'js',
      'app': '1',
      'placementId': placementId,
      'bundle': bundle,
      'name': name,
      'app_store_url': appStoreUrl,
      'language': language,
      'deviceWidth': deviceWidth,
      'deviceHeight': deviceHeight,
      'ua': ua,
      'ifa': ifa,
      'dnt': dnt,
    };
  }
}
