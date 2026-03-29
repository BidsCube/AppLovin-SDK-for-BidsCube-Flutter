import 'constants.dart';

/// Normalizes the SSP ad-request authority string (parity with Android
/// `SDKConfig` authority handling).
///
/// Do not pass a full URL with query — pass host, `host:port`, or a short
/// `https://host` prefix without path/query; the SDK appends `/sdk` and query.
String normalizeAdRequestAuthority(String? input) {
  var s = (input ?? '').trim();
  if (s.isEmpty) {
    return Constants.defaultAdRequestAuthority;
  }

  for (var i = 0; i < 3; i++) {
    try {
      final decoded = Uri.decodeComponent(s);
      if (decoded == s) break;
      s = decoded;
    } catch (_) {
      break;
    }
  }

  final lower = s.toLowerCase();
  if (lower.startsWith('https://')) {
    s = s.substring(8);
  } else if (lower.startsWith('http://')) {
    s = s.substring(7);
  }

  final slash = s.indexOf('/');
  if (slash >= 0) {
    s = s.substring(0, slash);
  }

  final q = s.indexOf('?');
  if (q >= 0) {
    s = s.substring(0, q);
  }

  s = s.trim();
  if (s.isEmpty) {
    return Constants.defaultAdRequestAuthority;
  }
  return s;
}
