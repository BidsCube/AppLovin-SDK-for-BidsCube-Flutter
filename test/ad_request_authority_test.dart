import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeAdRequestAuthority', () {
    test('defaults for empty and whitespace', () {
      expect(
        normalizeAdRequestAuthority(null),
        Constants.defaultAdRequestAuthority,
      );
      expect(
        normalizeAdRequestAuthority(''),
        Constants.defaultAdRequestAuthority,
      );
      expect(
        normalizeAdRequestAuthority('   '),
        Constants.defaultAdRequestAuthority,
      );
    });

    test('strips scheme, path, query', () {
      expect(
        normalizeAdRequestAuthority('https://example.com/sdk'),
        'example.com',
      );
      expect(
        normalizeAdRequestAuthority('HTTP://Example.COM/path'),
        'Example.COM',
      );
      expect(
        normalizeAdRequestAuthority('https://example.com?foo=1'),
        'example.com',
      );
    });

    test('percent-decoding up to 3 iterations', () {
      expect(
        normalizeAdRequestAuthority('example.com%3A8080'),
        'example.com:8080',
      );
    });

    test('127.0.0.1:8787 preserved for URI builder', () {
      expect(normalizeAdRequestAuthority('127.0.0.1:8787'), '127.0.0.1:8787');
    });
  });

  group('buildSdkBaseUri / ports', () {
    test('127.0.0.1:8787 uses port 8787, no encoded colon in host', () {
      final u = buildSdkBaseUri('127.0.0.1:8787');
      expect(u.scheme, 'https');
      expect(u.host, '127.0.0.1');
      expect(u.port, 8787);
      expect(u.path, '/sdk');
      expect(u.toString(), 'https://127.0.0.1:8787/sdk');
      expect(u.toString().contains('%3A'), isFalse);
    });

    test('IPv6 with port', () {
      final u = buildSdkBaseUri('[::1]:8787');
      expect(u.scheme, 'https');
      expect(u.host, '::1');
      expect(u.port, 8787);
      expect(u.path, '/sdk');
    });

    test('default authority', () {
      expect(
        defaultSdkBaseUrlString(),
        Constants.defaultSdkBaseUrl,
      );
    });
  });

  group('typed query maps', () {
    test('image / banner keys', () {
      final m = ImageAdUrlBuilder.build(
        placementId: 'p1',
        bundle: 'com.app',
        name: 'App',
        appStoreUrl: 'https://play.google.com/...',
        language: 'en',
        deviceWidth: '1080',
        deviceHeight: '1920',
        ua: 'Mozilla/5.0',
        ifa: '',
        dnt: '0',
      );
      expect(m['c'], 'b');
      expect(m['m'], 'api');
      expect(m['res'], 'js');
      expect(m['placementId'], 'p1');
      expect(m.containsKey('gdpr'), isFalse);
    });

    test('video keys', () {
      final m = VideoAdUrlBuilder.build(
        placementId: 'v1',
        bundle: 'com.app',
        name: 'App',
        appVersion: '1.0',
        ifa: 'x',
        dnt: '0',
        appStoreUrl: 'u',
        ua: 'Mozilla/5.0',
        language: 'en',
        deviceWidth: '1080',
        deviceHeight: '1920',
        screenWidth: '1080',
        screenHeight: '1920',
      );
      expect(m['c'], 'v');
      expect(m['m'], 'xml');
      expect(m['id'], 'v1');
    });

    test('native keys and null literals', () {
      final m = NativeAdUrlBuilder.build(
        placementId: 'n1',
        bundle: '',
        name: '',
        appVersion: '',
        ifa: '',
        dnt: '0',
        appStoreUrl: '',
        ua: '',
        gdpr: '0',
        gdprConsent: '0',
        usPrivacy: '1',
        ccpa: '0',
        coppa: '0',
        language: '',
        deviceWidth: '1080',
        deviceHeight: '1920',
        logicalWidth: '320',
        logicalHeight: '240',
      );
      expect(m['c'], 'n');
      expect(m['m'], 's');
      expect(m['bundle'], 'null');
      expect(m['gdpr'], '0');
    });
  });
}
