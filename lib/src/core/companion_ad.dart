/// Parsed VAST [Companion] selected for post-video display.
class CompanionAd {
  final CompanionResourceType resourceType;
  final String resource;
  final int width;
  final int height;
  final String? clickThroughUrl;
  final List<String> clickTrackingUrls;
  final List<String> creativeViewTrackingUrls;

  const CompanionAd({
    required this.resourceType,
    required this.resource,
    this.width = 0,
    this.height = 0,
    this.clickThroughUrl,
    this.clickTrackingUrls = const [],
    this.creativeViewTrackingUrls = const [],
  });

  bool get isInteractive =>
      resourceType == CompanionResourceType.html ||
      resourceType == CompanionResourceType.iframe;

  bool get isStaticImage => resourceType == CompanionResourceType.staticImage;
}

enum CompanionResourceType {
  html,
  iframe,
  staticImage,
}
