/// Ad positions supported by BidsCube SDK
enum AdPosition {
  unknown,

  aboveTheFold,

  dependOnTheScreenSize,

  belowTheFold,

  header,

  footer,

  sidebar,

  fullScreen,
}

/// Extension for AdPosition to get string representation and create from value
extension AdPositionExtension on AdPosition {
  /// Get string representation of ad position
  String get value {
    switch (this) {
      case AdPosition.unknown:
        return 'unknown';
      case AdPosition.aboveTheFold:
        return 'above_the_fold';
      case AdPosition.dependOnTheScreenSize:
        return 'depend_on_the_screen_size';
      case AdPosition.belowTheFold:
        return 'below_the_fold';
      case AdPosition.header:
        return 'header';
      case AdPosition.footer:
        return 'footer';
      case AdPosition.sidebar:
        return 'sidebar';
      case AdPosition.fullScreen:
        return 'fullscreen';
    }
  }

  /// Create AdPosition from integer value
  static AdPosition fromValue(int value) {
    switch (value) {
      case 0:
        return AdPosition.unknown;
      case 1:
        return AdPosition.aboveTheFold;
      case 2:
        return AdPosition.dependOnTheScreenSize;
      case 3:
        return AdPosition.belowTheFold;
      case 4:
        return AdPosition.header;
      case 5:
        return AdPosition.footer;
      case 6:
        return AdPosition.sidebar;
      case 7:
        return AdPosition.fullScreen;
      default:
        return AdPosition.unknown;
    }
  }
}
