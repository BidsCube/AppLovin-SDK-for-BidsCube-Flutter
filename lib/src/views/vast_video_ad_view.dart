import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../core/callbacks.dart';
import '../core/logger.dart';
import '../core/sdk_diagnostics.dart';
import '../core/vast_parser.dart';
import 'vast_end_card_view.dart';

/// Progressive MP4 VAST player with skip countdown and companion end card.
class VastVideoAdView extends StatefulWidget {
  final String placementId;
  final String vastXml;
  final AdCallback? callback;

  const VastVideoAdView({
    super.key,
    required this.placementId,
    required this.vastXml,
    this.callback,
  });

  @override
  State<VastVideoAdView> createState() => _VastVideoAdViewState();
}

class _VastVideoAdViewState extends State<VastVideoAdView> {
  VastAd? _vastAd;
  VideoPlayerController? _controller;
  String? _error;
  bool _showEndCard = false;
  bool _videoStarted = false;
  int _skipCountdown = -1;
  bool _skipEnabled = false;
  Timer? _skipTimer;

  @override
  void initState() {
    super.initState();
    _loadVast();
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadVast() async {
    try {
      widget.callback?.onAdLoading(widget.placementId);
      final vastAd = await VastParser.parseVast(widget.vastXml);
      if (vastAd == null || vastAd.videoUrl == null) {
        throw Exception('No video URL in VAST');
      }

      await _fireTracking(vastAd.impressionUrls);

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(vastAd.videoUrl!),
      );
      await controller.initialize();
      controller.addListener(_onVideoTick);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final hasCompanionPreview =
          vastAd.companionPreviewUrl?.isNotEmpty == true;
      SDKDiagnostics.logAdRequestPhase(
        placementId: widget.placementId,
        phase: 'vast_parsed',
        detail: hasCompanionPreview
            ? 'companion_preview=${vastAd.companionPreviewUrl}'
            : 'companion_preview=none_using_fallback_end_card',
      );
      if (vastAd.skipOffsetSeconds > 0) {
        SDKDiagnostics.logVideoPlayerRoute(
          placementId: widget.placementId,
          route: 'vast_skip_offset',
          detail: 'seconds=${vastAd.skipOffsetSeconds}',
        );
      }

      setState(() {
        _vastAd = vastAd;
        _controller = controller;
      });

      widget.callback?.onAdLoaded(widget.placementId);
      widget.callback?.onAdDisplayed(widget.placementId);

      await controller.play();
      _onVideoStarted();
      _startSkipCountdown(vastAd.skipOffsetSeconds);
    } catch (e) {
      SDKLogger.error('VAST video load failed', e);
      if (mounted) {
        setState(() => _error = e.toString());
      }
      widget.callback?.onAdFailed(
        widget.placementId,
        'VAST_ERROR',
        e.toString(),
      );
    }
  }

  void _onVideoStarted() {
    if (_videoStarted) return;
    _videoStarted = true;
    final startUrls = _vastAd?.trackingEvents['start'] ?? [];
    unawaited(_fireTracking(startUrls));
    widget.callback?.onVideoAdStarted(widget.placementId);
  }

  void _onVideoTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.position >= controller.value.duration &&
        !controller.value.isPlaying &&
        controller.value.duration > Duration.zero &&
        !_showEndCard) {
      _onVideoFinished(skipped: false);
    }
  }

  void _startSkipCountdown(int skipOffsetSeconds) {
    if (skipOffsetSeconds <= 0) return;

    setState(() {
      _skipCountdown = skipOffsetSeconds;
      _skipEnabled = false;
    });

    _skipTimer?.cancel();
    _skipTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_skipCountdown > 1) {
          _skipCountdown -= 1;
        } else {
          _skipCountdown = 0;
          _skipEnabled = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _onVideoFinished({required bool skipped}) async {
    _skipTimer?.cancel();
    await _controller?.pause();

    if (skipped) {
      final skipUrls = _vastAd?.trackingEvents['skip'] ?? [];
      await _fireTracking(skipUrls);
      widget.callback?.onVideoAdSkipped(widget.placementId);
    } else {
      final completeUrls = _vastAd?.trackingEvents['complete'] ?? [];
      await _fireTracking(completeUrls);
      widget.callback?.onVideoAdCompleted(widget.placementId);
    }

    if (mounted) {
      final preview = _vastAd?.companionPreviewUrl;
      SDKDiagnostics.logAdRequestPhase(
        placementId: widget.placementId,
        phase: 'end_card_show',
        detail: preview != null && preview.isNotEmpty
            ? 'companion_image'
            : 'fallback_placeholder',
      );
      setState(() => _showEndCard = true);
    }
  }

  Future<void> _fireTracking(List<String> urls) async {
    for (final url in urls) {
      try {
        await http.get(Uri.parse(url));
      } catch (_) {
        // Best-effort tracking for QA.
      }
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    final clickTracking = _vastAd?.clickTrackingUrls ?? [];
    await _fireTracking(clickTracking);

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    widget.callback?.onAdClicked(widget.placementId);
  }

  void _closeAd() {
    widget.callback?.onAdClosed(widget.placementId);
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  String? get _endCardClickUrl {
    final vast = _vastAd;
    if (vast == null) return null;
    if (vast.companionClickThroughUrl?.isNotEmpty == true) {
      return vast.companionClickThroughUrl;
    }
    return vast.clickThroughUrl;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _scaffold(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return _scaffold(const Center(child: CircularProgressIndicator()));
    }

    return _scaffold(
      Stack(
        fit: StackFit.expand,
        children: [
          if (!_showEndCard)
            FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            _buildEndCard(),
          if (!_showEndCard && _skipCountdown >= 0)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              right: 12,
              child: _buildSkipControl(),
            ),
          if (_showEndCard && !_hasCompanionPreview)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              right: 12,
              child: _buildCloseButton(),
            ),
        ],
      ),
      backgroundColor: _showEndCard && _hasCompanionPreview
          ? const Color(0xFFF2F2F2)
          : Colors.black,
    );
  }

  bool get _hasCompanionPreview =>
      _vastAd?.companionPreviewUrl?.isNotEmpty == true;

  Widget _scaffold(Widget body, {Color backgroundColor = Colors.black}) {
    return Scaffold(backgroundColor: backgroundColor, body: body);
  }

  Widget _buildSkipControl() {
    final label = _skipEnabled ? 'Skip' : 'Skip in $_skipCountdown';
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: _skipEnabled ? () => _onVideoFinished(skipped: true) : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: _closeAd,
      ),
    );
  }

  Widget _buildEndCard() {
    final clickUrl = _endCardClickUrl;

    if (_hasCompanionPreview) {
      return VastEndCardView(
        previewUrl: _vastAd!.companionPreviewUrl!,
        clickUrl: clickUrl,
        onClose: _closeAd,
        onTap: clickUrl != null ? () => _openUrl(clickUrl) : null,
      );
    }

    return GestureDetector(
      onTap: clickUrl != null ? () => _openUrl(clickUrl) : null,
      child: ColoredBox(
        color: const Color(0xFF1A1A1A),
        child: _fallbackEndCard(clickUrl),
      ),
    );
  }

  Widget _fallbackEndCard(String? clickUrl) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.play_circle_outline,
            color: Colors.white70,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            clickUrl != null ? 'Tap to learn more' : 'Thanks for watching',
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
