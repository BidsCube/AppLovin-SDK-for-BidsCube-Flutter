import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Optional override for local mock SSP / tunnel (see README "Ad request endpoint").
/// Run: `flutter run --dart-define=BIDSCUBE_SSP_AUTHORITY=127.0.0.1:8787`
const String _kSspAuthorityOverride = String.fromEnvironment(
  'BIDSCUBE_SSP_AUTHORITY',
  defaultValue: '',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final nativeMobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  await BidscubeSDK.initialize(
    config: SDKConfig.builder()
        .enableLogging(true)
        .adRequestAuthority(
          _kSspAuthorityOverride.isEmpty ? null : _kSspAuthorityOverride,
        )
        // AppLovin MAX: .integrationMode(BidscubeIntegrationMode.appLovinMaxMediation)
        .build(),
    // Native Bidscube on Android/iOS; Web/Desktop use Flutter-only (HTTP/WebView).
    useFlutterOnly: !nativeMobile,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BidsCube SDK Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BidsCube Banner Ad Example')),
      body: Center(
        child: BannerAdView(
          placementId: '20212',
          width: 320,
          height: 50,
          callback: ExampleAdCallback(),
        ),
      ),
    );
  }
}

/// Example implementation of AdCallback to handle ad events.
class ExampleAdCallback implements AdCallback {
  @override
  void Function(String placementId, String adm, AdPosition position)?
      onAdRenderOverride;

  @override
  void onAdLoading(String placementId) {
    debugPrint('Ad is loading: $placementId');
  }

  @override
  void onAdLoaded(String placementId) {
    debugPrint('Ad loaded: $placementId');
  }

  @override
  void onAdDisplayed(String placementId) {
    debugPrint('Ad displayed: $placementId');
  }

  @override
  void onAdFailed(String placementId, String errorCode, String errorMessage) {
    debugPrint('Ad failed: $placementId, $errorCode, $errorMessage');
  }

  @override
  void onAdClicked(String placementId) {
    debugPrint('Ad clicked: $placementId');
  }

  @override
  void onAdClosed(String placementId) {
    debugPrint('Ad closed: $placementId');
  }

  @override
  void onVideoAdStarted(String placementId) {
    debugPrint('Video ad started: $placementId');
  }

  @override
  void onVideoAdCompleted(String placementId) {
    debugPrint('Video ad completed: $placementId');
  }

  @override
  void onVideoAdSkipped(String placementId) {
    debugPrint('Video ad skipped: $placementId');
  }
}
