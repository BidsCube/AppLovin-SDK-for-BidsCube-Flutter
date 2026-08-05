import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../bidscube_sdk.dart';
import '../core/callbacks.dart';
import '../core/logger.dart';
import '../core/sdk_diagnostics.dart';
import '../core/vast_parser.dart';
import '../video/fullscreen_post_video_action.dart';
import '../video/fullscreen_video_session_controller.dart';
import 'vast_end_card_view.dart';
import 'vast_html_companion_view.dart';

/// Progressive MP4 VAST player with skip countdown, [autoClose] policy, and
/// VAST Companion end cards (Static / HTML / IFrame).
class VastVideoAdView extends StatefulWidget {
  final String placementId;
  final String vastXml;
  final AdCallback? callback;
  final bool? autoClose;

  const VastVideoAdView({
    super.key,
    required this.placementId,
    required this.vastXml,
    this.callback,
    this.autoClose,
  });

  @override
  State<VastVideoAdView> createState() => _VastVideoAdViewState();
}

class _VastVideoAdViewState extends State<VastVideoAdView> {
  VastAd? _vastAd;
  VideoPlayerController? _controller;
  FullscreenVideoSessionController? _session;
  String? _error;

  bool _showSkipOverlay = true;
  bool _playerVisible = true;
  bool _showStaticEndCard = false;
  bool _showHtmlEndCard = false;
  bool _showManualCloseButton = false;
  bool _adClosed = false;
  bool _companionViewTrackingFired = false;

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

  bool get _autoClose =>
      widget.autoClose ?? BidscubeSDK.isAutoClose;

  Future<void> _loadVast() async {
    try {
      widget.callback?.onAdLoading(widget.placementId);
      final vastAd = await VastParser.parseVast(widget.vastXml);
      if (vastAd == null || vastAd.videoUrl == null) {
        throw Exception('No video URL in VAST');
      }

      _session = FullscreenVideoSessionController(
        autoClose: _autoClose,
        playerManagesPostVideo: false,
        companion: vastAd.companion,
      );

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

      final companion = vastAd.companion;
      SDKDiagnostics.logAdRequestPhase(
        placementId: widget.placementId,
        phase: 'vast_parsed',
        detail: companion == null
            ? 'companion=none'
            : 'companion=${companion.resourceType.name}',
      );
      if (vastAd.skipOffsetSeconds > 0) {
        SDKDiagnostics.logVideoPlayerRoute(
          placementId: widget.placementId,
          route: 'vast_skip_offset',
          detail: 'seconds=${vastAd.skipOffsetSeconds}',
        );
      } else {
        SDKDiagnostics.logVideoPlayerRoute(
          placementId: widget.placementId,
          route: 'vast_skip_offset',
          detail: 'default_seconds=${VastParser.defaultSkipSeconds}',
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
      final skipSeconds = VastParser.resolveSkipSeconds(widget.vastXml);
      _startSkipCountdown(skipSeconds);
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
        _session != null &&
        !_session!.isAdClosed) {
      _onVideoFinished(skipped: false);
    }
  }

  void _startSkipCountdown(int skipOffsetSeconds) {
    final seconds = skipOffsetSeconds > 0
        ? skipOffsetSeconds
        : VastParser.defaultSkipSeconds;

    setState(() {
      _skipCountdown = seconds;
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
    final session = _session;
    if (session == null || session.isAdClosed) return;

    _skipTimer?.cancel();
    await _controller?.pause();

    if (skipped) {
      if (session.shouldFireSkipped()) {
        final skipUrls = _vastAd?.trackingEvents['skip'] ?? [];
        await _fireTracking(skipUrls);
        widget.callback?.onVideoAdSkipped(widget.placementId);
      }
      _applyPostVideoAction(session.onSkipped());
    } else {
      if (session.shouldFireLinearCompleted()) {
        final completeUrls = _vastAd?.trackingEvents['complete'] ?? [];
        await _fireTracking(completeUrls);
        widget.callback?.onVideoAdCompleted(widget.placementId);
      }
      _applyPostVideoAction(session.onLinearCompleted());
    }
  }

  void _applyPostVideoAction(FullscreenPostVideoAction action) {
    if (action.isNoop) return;

    if (action.dismissDialog || action.fireAdClosed) {
      _dismissEntireAd(fireCallback: action.fireAdClosed);
      return;
    }

    if (action.releasePlayer) {
      _releasePlayer();
    }

    if (mounted) {
      setState(() {
        if (action.removeSkipOverlay) _showSkipOverlay = false;
        if (action.hidePlayer) _playerVisible = false;
        if (action.keepPlayerVisible) _playerVisible = true;
        if (action.showStaticCompanionEndCard) {
          _showStaticEndCard = true;
          _fireCompanionViewTrackingOnce();
        }
        if (action.showHtmlCompanionEndCard) {
          _showHtmlEndCard = true;
          _fireCompanionViewTrackingOnce();
        }
        if (action.showManualCloseButton) _showManualCloseButton = true;
      });
    }

    SDKDiagnostics.logAdRequestPhase(
      placementId: widget.placementId,
      phase: 'post_video_action',
      detail:
          'playerVisible=$_playerVisible static=$_showStaticEndCard html=$_showHtmlEndCard manualClose=$_showManualCloseButton',
    );
  }

  void _releasePlayer() {
    final controller = _controller;
    if (controller == null) return;
    controller.removeListener(_onVideoTick);
    unawaited(controller.dispose());
    _controller = null;
  }

  void _fireCompanionViewTrackingOnce() {
    if (_companionViewTrackingFired) return;
    _companionViewTrackingFired = true;
    final urls = _vastAd?.companion?.creativeViewTrackingUrls ?? [];
    unawaited(_fireTracking(urls));
  }

  void _dismissEntireAd({required bool fireCallback}) {
    if (_adClosed) return;
    _adClosed = true;
    _skipTimer?.cancel();
    _releasePlayer();
    if (fireCallback) {
      widget.callback?.onAdClosed(widget.placementId);
    }
    if (mounted) {
      setState(() {
        _showSkipOverlay = false;
        _playerVisible = false;
        _showStaticEndCard = false;
        _showHtmlEndCard = false;
        _showManualCloseButton = false;
      });
      Navigator.of(context).maybePop();
    }
  }

  void _onUserClose() {
    final session = _session;
    if (session == null) {
      _dismissEntireAd(fireCallback: true);
      return;
    }
    _applyPostVideoAction(session.onUserClose());
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

  Future<void> _openUrl(String? url, {List<String> clickTracking = const []}) async {
    if (url == null || url.isEmpty) return;

    await _fireTracking(clickTracking);

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    widget.callback?.onAdClicked(widget.placementId);
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
      if (!_showStaticEndCard && !_showHtmlEndCard) {
        return _scaffold(const Center(child: CircularProgressIndicator()));
      }
    }

    return _scaffold(
      Stack(
        fit: StackFit.expand,
        children: [
          if (_playerVisible &&
              _controller != null &&
              _controller!.value.isInitialized)
            FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          if (_showStaticEndCard) _buildStaticEndCard(),
          if (_showHtmlEndCard) _buildHtmlEndCard(),
          if (_showSkipOverlay && _skipCountdown >= 0)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              right: 12,
              child: _buildSkipControl(),
            ),
          if (_showManualCloseButton)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              right: 12,
              child: _buildCloseButton(),
            ),
        ],
      ),
      backgroundColor: (_showStaticEndCard || _showHtmlEndCard)
          ? const Color(0xFFF2F2F2)
          : Colors.black,
    );
  }

  Widget _scaffold(Widget body, {Color backgroundColor = Colors.black}) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onUserClose();
      },
      child: Scaffold(backgroundColor: backgroundColor, body: body),
    );
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
        onPressed: _onUserClose,
      ),
    );
  }

  Widget _buildStaticEndCard() {
    final companion = _vastAd?.companion;
    final clickUrl = _endCardClickUrl;
    final previewUrl = companion?.resource ?? _vastAd?.companionPreviewUrl;

    if (previewUrl != null && previewUrl.isNotEmpty) {
      return VastEndCardView(
        previewUrl: previewUrl,
        clickUrl: clickUrl,
        onClose: _onUserClose,
        onTap: clickUrl != null
            ? () => _openUrl(
                  clickUrl,
                  clickTracking: companion?.clickTrackingUrls ??
                      _vastAd?.clickTrackingUrls ??
                      const [],
                )
            : null,
      );
    }

    return GestureDetector(
      onTap: clickUrl != null
          ? () => _openUrl(clickUrl, clickTracking: _vastAd?.clickTrackingUrls ?? const [])
          : null,
      child: ColoredBox(
        color: const Color(0xFF1A1A1A),
        child: _fallbackEndCard(clickUrl),
      ),
    );
  }

  Widget _buildHtmlEndCard() {
    final companion = _vastAd?.companion;
    if (companion == null || !companion.isInteractive) {
      return const SizedBox.shrink();
    }
    final clickUrl = companion.clickThroughUrl ?? _endCardClickUrl;
    return VastHtmlCompanionView(
      companion: companion,
      onClose: _onUserClose,
      onTap: clickUrl != null
          ? () => _openUrl(clickUrl, clickTracking: companion.clickTrackingUrls)
          : null,
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
