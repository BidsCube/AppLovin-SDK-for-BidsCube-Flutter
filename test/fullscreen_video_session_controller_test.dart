import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const vastNoCompanion = '''
<?xml version="1.0"?><VAST version="3.0"><Ad><InLine><Creatives>
<Creative><Linear><Duration>00:00:15</Duration><MediaFiles>
<MediaFile delivery="progressive" type="video/mp4">https://example.com/v.mp4</MediaFile>
</MediaFiles></Linear></Creative></Creatives></InLine></Ad></VAST>''';

  const vastStaticCompanion = '''
<?xml version="1.0"?><VAST version="3.0"><Ad><InLine><Creatives>
<Creative><Linear><Duration>00:00:15</Duration><MediaFiles>
<MediaFile delivery="progressive" type="video/mp4">https://example.com/v.mp4</MediaFile>
</MediaFiles></Linear><CompanionAds><Companion width="300" height="250">
<StaticResource creativeType="image/jpeg">https://example.com/end.jpg</StaticResource>
</Companion></CompanionAds></Creative></Creatives></InLine></Ad></VAST>''';

  const vastHtmlCompanion = '''
<?xml version="1.0"?><VAST version="3.0"><Ad><InLine><Creatives>
<Creative><Linear><Duration>00:00:15</Duration><MediaFiles>
<MediaFile delivery="progressive" type="video/mp4">https://example.com/v.mp4</MediaFile>
</MediaFiles></Linear><CompanionAds><Companion width="300" height="250">
<HTMLResource><![CDATA[<html><body>Play</body></html>]]></HTMLResource>
</Companion></CompanionAds></Creative></Creatives></InLine></Ad></VAST>''';

  group('FullscreenVideoSessionController', () {
    test('default autoClose=false without companion keeps player and close button',
        () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: false,
        vastXml: vastNoCompanion,
      );
      expect(session.shouldFireLinearCompleted(), isTrue);
      final action = session.onLinearCompleted();
      expect(action.dismissDialog, isFalse);
      expect(action.fireAdClosed, isFalse);
      expect(action.showManualCloseButton, isTrue);
      expect(action.keepPlayerVisible, isTrue);
      expect(action.releasePlayer, isFalse);
    });

    test('autoClose=true dismisses without companion', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: true,
        playerManagesPostVideo: false,
        vastXml: vastNoCompanion,
      );
      expect(session.shouldFireLinearCompleted(), isTrue);
      final action = session.onLinearCompleted();
      expect(action.dismissDialog, isTrue);
      expect(action.fireAdClosed, isTrue);
      expect(action.releasePlayer, isTrue);
      expect(action.showStaticCompanionEndCard, isFalse);
    });

    test('autoClose=true also dismisses with companion', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: true,
        playerManagesPostVideo: false,
        vastXml: vastStaticCompanion,
      );
      final action = session.onLinearCompleted();
      expect(action.dismissDialog, isTrue);
      expect(action.fireAdClosed, isTrue);
      expect(action.showStaticCompanionEndCard, isFalse);
    });

    test('autoClose=false with static companion shows end card', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: false,
        vastXml: vastStaticCompanion,
      );
      final action = session.onLinearCompleted();
      expect(action.showStaticCompanionEndCard, isTrue);
      expect(action.showManualCloseButton, isFalse);
      expect(action.dismissDialog, isFalse);
      expect(action.releasePlayer, isTrue);
    });

    test('IMA linear complete keeps player for post-video experience', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: true,
        vastXml: vastNoCompanion,
      );
      final action = session.onLinearCompleted();
      expect(action.keepPlayerVisible, isTrue);
      expect(action.releasePlayer, isFalse);
      expect(action.showManualCloseButton, isTrue);
      expect(action.dismissDialog, isFalse);
    });

    test('IMA session completed with HTML companion shows html end card', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: true,
        vastXml: vastHtmlCompanion,
      );
      session.onLinearCompleted();
      final action = session.onAdSessionCompleted();
      expect(action.releasePlayer, isTrue);
      expect(action.hidePlayer, isTrue);
      expect(action.showHtmlCompanionEndCard, isTrue);
      expect(action.showStaticCompanionEndCard, isFalse);
      expect(action.dismissDialog, isFalse);
    });

    test('IMA session completed with static companion shows static end card', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: true,
        vastXml: vastStaticCompanion,
      );
      session.onLinearCompleted();
      final action = session.onAdSessionCompleted();
      expect(action.releasePlayer, isTrue);
      expect(action.showStaticCompanionEndCard, isTrue);
      expect(action.showHtmlCompanionEndCard, isFalse);
    });

    test('IMA session completed without companion is noop after linear', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: true,
        vastXml: vastNoCompanion,
      );
      session.onLinearCompleted();
      final action = session.onAdSessionCompleted();
      expect(action.isNoop, isTrue);
    });

    test('non-IMA companion linear then session second action is noop', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: false,
        vastXml: vastStaticCompanion,
      );
      final linear = session.onLinearCompleted();
      expect(linear.showStaticCompanionEndCard, isTrue);
      expect(session.onAdSessionCompleted().isNoop, isTrue);
    });

    test('skip manual mode does not show companion', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: false,
        vastXml: vastStaticCompanion,
      );
      final action = session.onSkipped();
      expect(action.releasePlayer, isTrue);
      expect(action.hidePlayer, isTrue);
      expect(action.showManualCloseButton, isTrue);
      expect(action.showStaticCompanionEndCard, isFalse);
      expect(action.showHtmlCompanionEndCard, isFalse);
      expect(action.dismissDialog, isFalse);
    });

    test('duplicate completed does not duplicate callbacks', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: false,
        vastXml: vastNoCompanion,
      );
      expect(session.shouldFireLinearCompleted(), isTrue);
      expect(session.shouldFireLinearCompleted(), isFalse);
      final first = session.onLinearCompleted();
      final second = session.onLinearCompleted();
      expect(first.showManualCloseButton, isTrue);
      expect(second.isNoop, isTrue);
    });

    test('duplicate allAdsCompleted does not duplicate overlay', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: true,
        vastXml: vastHtmlCompanion,
      );
      session.onLinearCompleted();
      final first = session.onAdSessionCompleted();
      final second = session.onAdSessionCompleted();
      expect(first.showHtmlCompanionEndCard, isTrue);
      expect(second.isNoop, isTrue);
    });

    test('user close fires exactly once', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: true,
        vastXml: vastNoCompanion,
      );
      session.onLinearCompleted();
      final first = session.onUserClose();
      final second = session.onUserClose();
      expect(first.fireAdClosed, isTrue);
      expect(second.isNoop, isTrue);
    });

    test('skip does not fire linear completed after skip', () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: false,
        vastXml: vastNoCompanion,
      );
      expect(session.shouldFireSkipped(), isTrue);
      expect(session.shouldFireLinearCompleted(), isFalse);
    });

    test('mini-game IMA linear keeps player after session completes without companion',
        () {
      final session = FullscreenVideoSessionController.fromVast(
        autoClose: false,
        playerManagesPostVideo: true,
        vastXml: vastNoCompanion,
      );
      final linear = session.onLinearCompleted();
      expect(linear.keepPlayerVisible, isTrue);
      expect(linear.releasePlayer, isFalse);
      expect(linear.dismissDialog, isFalse);
      final sessionAction = session.onAdSessionCompleted();
      expect(sessionAction.isNoop, isTrue);
    });
  });
}
