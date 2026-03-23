/// Logger for BidsCube SDK
library;

import 'dart:developer';

/// Logger for BidsCube SDK
class SDKLogger {
  static bool _isEnabled = true;
  static bool _isDebugMode = false;

  /// Enable or disable logging
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Enable or disable debug mode
  static void setDebugMode(bool enabled) {
    _isDebugMode = enabled;
  }

  /// Log info message
  static void info(String message) {
    if (_isEnabled) {
      log('[BidsCube SDK] INFO: $message', name: 'BidsCubeSDK');
    }
  }

  /// Log debug message
  static void debug(String message) {
    if (_isEnabled && _isDebugMode) {
      log('[BidsCube SDK] DEBUG: $message', name: 'BidsCubeSDK');
    }
  }

  /// Log warning message
  static void warning(String message) {
    if (_isEnabled) {
      log('[BidsCube SDK] WARNING: $message', name: 'BidsCubeSDK', level: 900);
    }
  }

  /// Log error message
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_isEnabled) {
      log(
        '[BidsCube SDK] ERROR: $message',
        name: 'BidsCubeSDK',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
