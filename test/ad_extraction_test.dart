import 'dart:developer';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ad Content Extraction Tests', () {
    test('Extract HTML from document.write with unquoted content', () {
      final adm =
          r'''document.write(<div style=\"position: relative; width:300px; height:250px; overflow: hidden;\"><div style=\"width:300px; height: 250px; margin-left: -150px; margin-top: -125px; position: absolute; top: 50%; left: 50%;\"><span id=\"banner_test\">https://wegetads.com/creatives/test?cid=123\\<script type=\"application/javascript\" src=\"https://s110.bcc-ssp.com/cdata?key=test\"><\/script><img src=\"https://s110.bcc-ssp.com/?c=b&m=i&h=test\" width=\"1\" height=\"1\" alt=\"\" style=\"position: absolute\"><script type=\"application/javascript\">(function () { let wrapper = document.getElementById(\"banner_test\"); wrapper.addEventListener(\"click\", function () { let s = document.createElement(\"script\"); s.type = \"text/javascript\"; s.async = true; s.src = \"https://s110.bcc-ssp.com/?c=b&m=c&h=test\"; document.body.appendChild(s); }); })();<\/script></span></div></div>);''';

      // Simulated extraction
      var content = adm.trim();
      if (content.startsWith('document.write(') && content.endsWith(');')) {
        content = content.substring(
          'document.write('.length,
          content.length - 2,
        );
      }

      // Unescape
      content = content
          .replaceAll(r'\"', '"')
          .replaceAll(r"\'", "'")
          .replaceAll(r'\/', '/');

      // Check that HTML tags are present
      expect(content.contains('<div'), true);
      expect(content.contains('<script'), true);
      expect(content.contains('</div>'), true);

      // Check that escaped quotes are unescaped
      expect(content.contains('style="'), true);

      // Check that URL should be present (will be removed in cleanup)
      expect(content.contains('https://wegetads.com'), true);

      log('Extracted content preview: ${content.substring(0, 200)}');
    });

    test('Clean up URL text node before script tag', () {
      final content =
          r'<span id="banner_test">https://wegetads.com/test\<script type="text/javascript">alert("test");</script></span>';

      final urlBeforeScriptRegex = RegExp(
        r'(<span[^>]*>)(https?://[^\s<>"\\]+)(\\+)(<script)',
        caseSensitive: false,
      );

      final cleaned = content.replaceAllMapped(urlBeforeScriptRegex, (match) {
        return '${match.group(1)}${match.group(4)}';
      });

      expect(cleaned.contains('https://wegetads.com'), false);
      expect(cleaned.contains('<span id="banner_test"><script'), true);

      log('Cleaned content: $cleaned');
    });
  });
}
