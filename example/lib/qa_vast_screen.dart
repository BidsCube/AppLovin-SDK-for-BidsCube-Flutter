import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// Local QA for VAST preview / end-card behavior (no backend).
///
/// Uses the in-app [VastVideoAdView] so companion parsing and fallback end cards
/// are exercised on every platform. Production apps on Android/iOS may use
/// [BidscubeSDK.showVideoAdFromVast] to delegate to the native player instead.
class QaVastScreen extends StatelessWidget {
  const QaVastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QA — VAST preview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Hardcoded VAST fixtures. Filter logs: [BidsCubeDiag] end_card_show, '
            'vast_parsed, companion_preview.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 24),
          _QaCaseCard(
            title: 'Case 1 — VAST without preview',
            subtitle:
                'No Companion / StaticResource. End card without preview image '
                '(fallback UI). Complete or wait for video end.',
            buttonLabel: 'Play DoorDash (no preview)',
            onPlay: () => _playFixture(
              context,
              caseId: 'no-preview',
              vastXml: QaVastFixtures.vastNoCompanion,
            ),
          ),
          const SizedBox(height: 16),
          _QaCaseCard(
            title: 'Case 2 — VAST with preview',
            subtitle:
                'Companion StaticResource + skip in 5s. End card shows parsed '
                'preview; tap opens https://www.google.com.',
            buttonLabel: 'Play Big Buck Bunny + preview',
            onPlay: () => _playFixture(
              context,
              caseId: 'with-preview',
              vastXml: QaVastFixtures.vastWithCompanion,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _playFixture(
    BuildContext context, {
    required String caseId,
    required String vastXml,
  }) async {
    final placementId = 'qa-vast-$caseId';
    debugPrint('[QA-VAST] start case=$caseId placement=$placementId');
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => VastVideoAdView(
          placementId: placementId,
          vastXml: vastXml,
          callback: QaVastAdCallback(caseId),
        ),
      ),
    );
    debugPrint('[QA-VAST] closed case=$caseId');
  }
}

class _QaCaseCard extends StatelessWidget {
  const _QaCaseCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPlay,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton(onPressed: onPlay, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

/// Logs callback order for manual QA verification.
class QaVastAdCallback implements AdCallback {
  QaVastAdCallback(this.caseId);

  final String caseId;

  void _log(String event, String placementId, [String? extra]) {
    final suffix = extra != null ? ' $extra' : '';
    debugPrint('[QA-VAST][$caseId] $event placement=$placementId$suffix');
  }

  @override
  void Function(String placementId, String adm, AdPosition position)?
      onAdRenderOverride;

  @override
  void onAdLoading(String placementId) => _log('onAdLoading', placementId);

  @override
  void onAdLoaded(String placementId) => _log('onAdLoaded', placementId);

  @override
  void onAdDisplayed(String placementId) => _log('onAdDisplayed', placementId);

  @override
  void onAdFailed(String placementId, String errorCode, String errorMessage) {
    _log('onAdFailed', placementId, '$errorCode $errorMessage');
  }

  @override
  void onAdClicked(String placementId) => _log('onAdClicked', placementId);

  @override
  void onAdClosed(String placementId) => _log('onAdClosed', placementId);

  @override
  void onVideoAdStarted(String placementId) =>
      _log('onVideoAdStarted', placementId);

  @override
  void onVideoAdCompleted(String placementId) =>
      _log('onVideoAdCompleted', placementId);

  @override
  void onVideoAdSkipped(String placementId) =>
      _log('onVideoAdSkipped', placementId);
}
