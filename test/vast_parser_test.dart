import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses companion preview and skip offset from QA fixture #2', () async {
    final vast = await VastParser.parseVast(QaVastFixtures.vastWithCompanion);
    expect(vast, isNotNull);
    expect(vast!.skipOffsetSeconds, 5);
    expect(
      vast.companionPreviewUrl,
      'https://www.gstatic.com/webp/gallery/3.jpg',
    );
    expect(vast.companionClickThroughUrl, 'https://www.google.com');
    expect(vast.companion?.resourceType, CompanionResourceType.staticImage);
    expect(vast.clickThroughUrl, 'https://www.google.com');
    expect(vast.videoUrl, contains('big_buck_bunny.mp4'));
  });

  test('parses DoorDash fixture without companion preview', () async {
    final vast = await VastParser.parseVast(QaVastFixtures.vastNoCompanion);
    expect(vast, isNotNull);
    expect(vast!.companionPreviewUrl, isNull);
    expect(vast.companionClickThroughUrl, isNull);
    expect(vast.companion, isNull);
    expect(vast.videoUrl, contains('Doordash-35min-burger'));
    expect(vast.skipOffsetSeconds, lessThan(0));
  });

  group('VastParser companion selection', () {
    const vastStatic = '''
<VAST><Ad><InLine><Creatives><Creative><CompanionAds>
<Companion width="300" height="250">
<StaticResource creativeType="image/jpeg"><![CDATA[https://example.com/static.jpg]]></StaticResource>
<CompanionClickThrough>https://click.example/static</CompanionClickThrough>
<CompanionClickTracking>https://track.example/click1</CompanionClickTracking>
</Companion></CompanionAds></Creative></Creatives></InLine></Ad></VAST>
''';

    const vastHtml = '''
<VAST><Ad><InLine><Creatives><Creative><CompanionAds>
<Companion width="320" height="480">
<HTMLResource><![CDATA[<a href='x'>html</a>]]></HTMLResource>
<CompanionClickThrough>https://click.example/html</CompanionClickThrough>
</Companion></CompanionAds></Creative></Creatives></InLine></Ad></VAST>
''';

    const vastIframe = '''
<VAST><Ad><InLine><Creatives><Creative><CompanionAds>
<Companion width="320" height="480">
<IFrameResource><![CDATA[https://example.com/frame.html]]></IFrameResource>
</Companion></CompanionAds></Creative></Creatives></InLine></Ad></VAST>
''';

    const vastMultiple = '''
<VAST><Ad><InLine><Creatives><Creative><CompanionAds>
<Companion width="300" height="250">
<StaticResource creativeType="image/jpeg"><![CDATA[https://example.com/static.jpg]]></StaticResource>
</Companion>
<Companion width="320" height="480">
<HTMLResource><![CDATA[<div>win</div>]]></HTMLResource>
</Companion>
</CompanionAds></Creative></Creatives></InLine></Ad></VAST>
''';

    test('static companion parses resource and click', () {
      final companion = VastParser.selectPostVideoCompanion(vastStatic);
      expect(companion?.resourceType, CompanionResourceType.staticImage);
      expect(companion?.resource, 'https://example.com/static.jpg');
      expect(companion?.clickThroughUrl, 'https://click.example/static');
      expect(companion?.clickTrackingUrls.length, 1);
      expect(VastParser.hasCompanionPreview(vastStatic), isTrue);
    });

    test('html companion parses html resource', () {
      final companion = VastParser.selectPostVideoCompanion(vastHtml);
      expect(companion?.resourceType, CompanionResourceType.html);
      expect(companion?.resource.contains('html'), isTrue);
      expect(VastParser.hasHtmlCompanion(vastHtml), isTrue);
    });

    test('iframe companion parses iframe resource', () {
      final companion = VastParser.selectPostVideoCompanion(vastIframe);
      expect(companion?.resourceType, CompanionResourceType.iframe);
      expect(companion?.resource, 'https://example.com/frame.html');
    });

    test('html preferred over static when multiple companions', () {
      final companion = VastParser.selectPostVideoCompanion(vastMultiple);
      expect(companion?.resourceType, CompanionResourceType.html);
    });
  });

  group('VastParser skip offset', () {
    test('resolveSkipSeconds uses Linear skipoffset when present', () {
      const vast = '''
<VAST><Ad><InLine><Creatives><Creative>
<Linear skipoffset="00:00:05"><Duration>00:00:30</Duration></Linear>
</Creative></Creatives></InLine></Ad></VAST>''';
      expect(VastParser.getSkipOffsetMs(vast), 5000);
      expect(VastParser.resolveSkipSeconds(vast), 5);
    });

    test('resolveSkipSeconds defaults to 15 when skipoffset absent', () {
      expect(
        VastParser.resolveSkipSeconds(QaVastFixtures.vastNoCompanion),
        15,
      );
      expect(VastParser.resolveSkipSeconds(null), 15);
    });

    test('resolveSkipSeconds parses percent skipoffset from duration', () {
      const vast = '''
<VAST><Ad><InLine><Creatives><Creative>
<Linear skipoffset="50%"><Duration>00:00:20</Duration></Linear>
</Creative></Creatives></InLine></Ad></VAST>''';
      expect(VastParser.getSkipOffsetMs(vast), 10000);
      expect(VastParser.resolveSkipSeconds(vast), 10);
    });
  });
}
