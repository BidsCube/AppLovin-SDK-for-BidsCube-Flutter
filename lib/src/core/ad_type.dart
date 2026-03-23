/// Ad types supported by BidsCube SDK
enum AdType {
  /// Banner ads
  banner,

  /// Video ads (VAST)
  video,

  /// Native ads
  native,
}

/// Extension for AdType to get string representation
extension AdTypeExtension on AdType {
  /// Get string representation of ad type
  String get value {
    switch (this) {
      case AdType.video:
        return 'video';
      case AdType.native:
        return 'native';
      case AdType.banner:
        return 'banner';
    }
  }
}
