/// UI/cleanup steps after a fullscreen video session event.
class FullscreenPostVideoAction {
  final bool removeSkipOverlay;
  final bool releasePlayer;
  final bool hidePlayer;
  final bool keepPlayerVisible;
  final bool dismissDialog;
  final bool fireAdClosed;
  final bool showStaticCompanionEndCard;
  final bool showHtmlCompanionEndCard;
  final bool showManualCloseButton;

  const FullscreenPostVideoAction({
    this.removeSkipOverlay = false,
    this.releasePlayer = false,
    this.hidePlayer = false,
    this.keepPlayerVisible = false,
    this.dismissDialog = false,
    this.fireAdClosed = false,
    this.showStaticCompanionEndCard = false,
    this.showHtmlCompanionEndCard = false,
    this.showManualCloseButton = false,
  });

  static const FullscreenPostVideoAction noop = FullscreenPostVideoAction();

  bool get isNoop =>
      !removeSkipOverlay &&
      !releasePlayer &&
      !hidePlayer &&
      !keepPlayerVisible &&
      !dismissDialog &&
      !fireAdClosed &&
      !showStaticCompanionEndCard &&
      !showHtmlCompanionEndCard &&
      !showManualCloseButton;

  FullscreenPostVideoAction copyWith({
    bool? removeSkipOverlay,
    bool? releasePlayer,
    bool? hidePlayer,
    bool? keepPlayerVisible,
    bool? dismissDialog,
    bool? fireAdClosed,
    bool? showStaticCompanionEndCard,
    bool? showHtmlCompanionEndCard,
    bool? showManualCloseButton,
  }) {
    return FullscreenPostVideoAction(
      removeSkipOverlay: removeSkipOverlay ?? this.removeSkipOverlay,
      releasePlayer: releasePlayer ?? this.releasePlayer,
      hidePlayer: hidePlayer ?? this.hidePlayer,
      keepPlayerVisible: keepPlayerVisible ?? this.keepPlayerVisible,
      dismissDialog: dismissDialog ?? this.dismissDialog,
      fireAdClosed: fireAdClosed ?? this.fireAdClosed,
      showStaticCompanionEndCard:
          showStaticCompanionEndCard ?? this.showStaticCompanionEndCard,
      showHtmlCompanionEndCard:
          showHtmlCompanionEndCard ?? this.showHtmlCompanionEndCard,
      showManualCloseButton:
          showManualCloseButton ?? this.showManualCloseButton,
    );
  }
}
