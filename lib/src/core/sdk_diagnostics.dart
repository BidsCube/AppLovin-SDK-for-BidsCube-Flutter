import 'bidscube_integration_mode.dart';
import 'logger.dart';

/// Structured diagnostics for integration debugging (filter logs by `[BidsCubeDiag]`).
class SDKDiagnostics {
  SDKDiagnostics._();

  static const String _tag = '[BidsCubeDiag]';

  static void logInitStart({
    required bool flutterOnly,
    required BidscubeIntegrationMode integrationMode,
    required String baseUrl,
  }) {
    SDKLogger.info(
      '$_tag init_start flutterOnly=$flutterOnly '
      'integrationMode=${integrationMode.wireValue} baseURL=$baseUrl',
    );
  }

  static void logInitNativeBridgeOk() {
    SDKLogger.info(
      '$_tag bidscube_native_bridge BidscubeSDK.initialize completed (MethodChannel)',
    );
  }

  static void logInitFlutterOnlyOk() {
    SDKLogger.info(
      '$_tag bidscube_flutter_only AdRequestClient ready (no native bridge)',
    );
  }

  static void logInitFailed(Object error, [StackTrace? st]) {
    SDKLogger.error('$_tag init_failed', error, st);
  }

  /// AppLovin MAX is initialized in the **host app**; this plugin only shares Bidscube native SDK.
  static void logAppLovinMediationHint() {
    SDKLogger.info(
      '$_tag applovin_max Host must initialize AppLovin MAX SDK separately; '
      'verify MAX + Bidscube adapter in native logs (Android Logcat / Xcode console).',
    );
  }

  static void logVideoPlayerRoute({
    required String placementId,
    required String route,
    String? detail,
  }) {
    final extra = detail != null ? ' $detail' : '';
    SDKLogger.info(
      '$_tag video_player placement=$placementId route=$route$extra',
    );
  }

  static void logAdRequestPhase({
    required String placementId,
    required String phase,
    String? detail,
  }) {
    final extra = detail != null ? ' detail=$detail' : '';
    SDKLogger.info(
      '$_tag ad_load placement=$placementId phase=$phase$extra',
    );
  }
}
