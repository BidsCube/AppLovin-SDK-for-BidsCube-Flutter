/// BidsCube Flutter SDK — **single public import** for apps and plugins.
///
/// **Federated plugin:** Android and iOS use the native `BidscubeSDK` (AAR / CocoaPods).
/// Direct SDK mode can use [FlutterOnlyBidscube] paths on more platforms where HTTP/WebView
/// implementations apply; native ad [PlatformView]s require Android/iOS.
///
/// **Mediation (AppLovin MAX):** call [BidscubeSDK.initialize] early with
/// [BidscubeIntegrationMode.appLovinMaxMediation];
/// load/show ads only through AppLovin MAX, not Dart `get*AdView` APIs.
///
/// Usage: `import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';`
library;

// Core SDK
export 'src/bidscube_sdk.dart';
export 'src/core/ad_position.dart';
export 'src/core/ad_type.dart';
export 'src/core/sdk_config.dart';
export 'src/core/bidscube_integration_mode.dart';
export 'src/core/callbacks.dart';
export 'src/core/logger.dart';
export 'src/core/position_style.dart';

// Ad Views
export 'src/views/webview_image_ad_view.dart';
export 'src/views/banner_ad_view.dart';
export 'src/views/ima_vast_video_ad_view.dart';
export 'src/views/flutter_native_ad_view.dart';

// Platform Channels
export 'src/platform/bidscube_platform.dart';
export 'src/platform/method_channel_bidscube.dart';
export 'src/platform/flutter_only_bidscube.dart';

// Core utilities
export 'src/core/constants.dart';
export 'src/core/vast_parser.dart';
export 'src/core/ad_request_client.dart';
export 'src/core/url_builder.dart';
export 'src/core/ad_request_authority_normalizer.dart';
export 'src/core/ssp_ad_uri_helper.dart';
export 'src/network/image_ad_url_builder.dart';
export 'src/network/video_ad_url_builder.dart';
export 'src/network/native_ad_url_builder.dart';
