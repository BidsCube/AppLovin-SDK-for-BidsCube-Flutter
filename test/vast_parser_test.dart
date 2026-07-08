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
    expect(vast.clickThroughUrl, 'https://www.google.com');
    expect(vast.videoUrl, contains('big_buck_bunny.mp4'));
  });

  test('parses DoorDash fixture without companion preview', () async {
    final vast = await VastParser.parseVast(QaVastFixtures.vastNoCompanion);
    expect(vast, isNotNull);
    expect(vast!.companionPreviewUrl, isNull);
    expect(vast.companionClickThroughUrl, isNull);
    expect(vast.videoUrl, contains('Doordash-35min-burger'));
    expect(vast.skipOffsetSeconds, lessThan(0));
  });
}
