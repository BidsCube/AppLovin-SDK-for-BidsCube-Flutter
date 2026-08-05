import '../core/companion_ad.dart';
import '../core/vast_parser.dart';
import 'fullscreen_post_video_action.dart';

/// Pure state machine for fullscreen video post-linear playback.
class FullscreenVideoSessionController {
  final bool autoClose;
  final bool playerManagesPostVideo;
  final bool hasStaticCompanion;
  final bool hasHtmlCompanion;

  bool _linearCompleted = false;
  bool _skipped = false;
  bool _adSessionCompleted = false;
  bool _adClosed = false;
  bool _linearPostVideoHandled = false;
  bool _sessionPostVideoHandled = false;
  bool _manualCloseShown = false;
  bool _staticCompanionShown = false;
  bool _htmlCompanionShown = false;

  FullscreenVideoSessionController({
    required this.autoClose,
    required this.playerManagesPostVideo,
    CompanionAd? companion,
  })  : hasHtmlCompanion = companion?.isInteractive ?? false,
        hasStaticCompanion = companion?.isStaticImage ?? false;

  FullscreenVideoSessionController.test({
    required this.autoClose,
    required this.playerManagesPostVideo,
    required this.hasStaticCompanion,
    required this.hasHtmlCompanion,
  });

  factory FullscreenVideoSessionController.fromVast({
    required bool autoClose,
    required bool playerManagesPostVideo,
    String? vastXml,
  }) {
    return FullscreenVideoSessionController(
      autoClose: autoClose,
      playerManagesPostVideo: playerManagesPostVideo,
      companion: vastXml == null
          ? null
          : VastParser.selectPostVideoCompanion(vastXml),
    );
  }

  bool get isAdClosed => _adClosed;

  bool shouldFireLinearCompleted() {
    if (_skipped) return false;
    if (_linearCompleted) return false;
    _linearCompleted = true;
    return true;
  }

  bool shouldFireSkipped() {
    if (_linearCompleted) return false;
    if (_skipped) return false;
    _skipped = true;
    return true;
  }

  bool shouldFireAdSessionCompleted() {
    if (_adSessionCompleted) return false;
    _adSessionCompleted = true;
    return true;
  }

  FullscreenPostVideoAction onLinearCompleted() {
    _linearCompleted = true;
    return _onLinearPlaybackEnded(wasSkipped: false);
  }

  FullscreenPostVideoAction onSkipped() {
    _skipped = true;
    return _onLinearPlaybackEnded(wasSkipped: true);
  }

  FullscreenPostVideoAction onAdSessionCompleted() {
    _adSessionCompleted = true;
    if (autoClose) {
      return _adClosed ? FullscreenPostVideoAction.noop : _closeEntireAd();
    }
    if (_adClosed) return FullscreenPostVideoAction.noop;
    if (!playerManagesPostVideo) {
      return _linearPostVideoHandled
          ? FullscreenPostVideoAction.noop
          : _onNonImaLinearPlaybackEnded();
    }
    return _onImaSessionCompleted();
  }

  FullscreenPostVideoAction onPlaybackFailed() {
    if (autoClose) {
      return _adClosed ? FullscreenPostVideoAction.noop : _closeEntireAd();
    }
    if (_adClosed) return FullscreenPostVideoAction.noop;
    _linearPostVideoHandled = true;
    _sessionPostVideoHandled = true;
    return _finalManualCloseState(releasePlayer: true, hidePlayer: true);
  }

  FullscreenPostVideoAction onUserClose() => _closeEntireAd();

  FullscreenPostVideoAction _onLinearPlaybackEnded({required bool wasSkipped}) {
    if (autoClose) {
      return _closeEntireAd();
    }
    if (wasSkipped) {
      return _onSkippedManualMode();
    }
    if (playerManagesPostVideo) {
      return _onImaLinearCompleted();
    }
    return _onNonImaLinearPlaybackEnded();
  }

  FullscreenPostVideoAction _onImaLinearCompleted() {
    if (_linearPostVideoHandled) return FullscreenPostVideoAction.noop;
    _linearPostVideoHandled = true;
    return FullscreenPostVideoAction(
      removeSkipOverlay: true,
      keepPlayerVisible: true,
      showManualCloseButton: _shouldShowManualCloseButton(),
    );
  }

  FullscreenPostVideoAction _onImaSessionCompleted() {
    if (_sessionPostVideoHandled) return FullscreenPostVideoAction.noop;
    _sessionPostVideoHandled = true;
    if (hasHtmlCompanion || hasStaticCompanion) {
      return _companionOrFinalState(releasePlayer: true, hidePlayer: true);
    }
    return FullscreenPostVideoAction.noop;
  }

  FullscreenPostVideoAction _onNonImaLinearPlaybackEnded() {
    if (_linearPostVideoHandled) return FullscreenPostVideoAction.noop;
    _linearPostVideoHandled = true;
    if (hasHtmlCompanion || hasStaticCompanion) {
      return _companionOrFinalState(releasePlayer: true, hidePlayer: true);
    }
    return FullscreenPostVideoAction(
      removeSkipOverlay: true,
      keepPlayerVisible: true,
      showManualCloseButton: _shouldShowManualCloseButton(),
    );
  }

  FullscreenPostVideoAction _onSkippedManualMode() {
    if (_linearPostVideoHandled) return FullscreenPostVideoAction.noop;
    _linearPostVideoHandled = true;
    _sessionPostVideoHandled = true;
    return _finalManualCloseState(releasePlayer: true, hidePlayer: true);
  }

  FullscreenPostVideoAction _companionOrFinalState({
    required bool releasePlayer,
    required bool hidePlayer,
  }) {
    if (hasHtmlCompanion) {
      return FullscreenPostVideoAction(
        removeSkipOverlay: true,
        releasePlayer: releasePlayer,
        hidePlayer: hidePlayer,
        showHtmlCompanionEndCard: _markHtmlCompanionShown(),
      );
    }
    if (hasStaticCompanion) {
      return FullscreenPostVideoAction(
        removeSkipOverlay: true,
        releasePlayer: releasePlayer,
        hidePlayer: hidePlayer,
        showStaticCompanionEndCard: _markStaticCompanionShown(),
      );
    }
    return _finalManualCloseState(
      releasePlayer: releasePlayer,
      hidePlayer: hidePlayer,
    );
  }

  FullscreenPostVideoAction _finalManualCloseState({
    required bool releasePlayer,
    required bool hidePlayer,
  }) {
    return FullscreenPostVideoAction(
      removeSkipOverlay: true,
      releasePlayer: releasePlayer,
      hidePlayer: hidePlayer,
      showManualCloseButton: _shouldShowManualCloseButton(),
    );
  }

  bool _shouldShowManualCloseButton() {
    if (_manualCloseShown) return false;
    _manualCloseShown = true;
    return true;
  }

  bool _markStaticCompanionShown() {
    if (_staticCompanionShown) return false;
    _staticCompanionShown = true;
    return true;
  }

  bool _markHtmlCompanionShown() {
    if (_htmlCompanionShown) return false;
    _htmlCompanionShown = true;
    return true;
  }

  FullscreenPostVideoAction _closeEntireAd() {
    if (_adClosed) return FullscreenPostVideoAction.noop;
    _adClosed = true;
    return const FullscreenPostVideoAction(
      removeSkipOverlay: true,
      releasePlayer: true,
      hidePlayer: true,
      dismissDialog: true,
      fireAdClosed: true,
    );
  }
}
