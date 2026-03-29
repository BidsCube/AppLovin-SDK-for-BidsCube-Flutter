import 'ad_request_authority_normalizer.dart';
import 'constants.dart';

/// Parsed host and optional port from an authority string (parity with Android
/// `SspAdUriHelper`).
class SspParsedAuthority {
  const SspParsedAuthority(this.host, [this.port]);

  final String host;
  final int? port;
}

/// Splits [authority] into host and port without mis-encoding `:` in IPv6 or
/// spurious ports (parity with Android `SspAdUriHelper`).
SspParsedAuthority parseSspAuthority(String authority) {
  final s = authority.trim();
  if (s.startsWith('[')) {
    final close = s.indexOf(']');
    if (close > 0) {
      final inner = s.substring(1, close);
      if (close + 1 < s.length && s[close + 1] == ':') {
        final portStr = s.substring(close + 2);
        if (RegExp(r'^\d{1,5}$').hasMatch(portStr)) {
          final port = int.tryParse(portStr);
          if (port != null && port >= 0 && port <= 65535) {
            return SspParsedAuthority(inner, port);
          }
        }
      }
      return SspParsedAuthority(inner);
    }
  }

  final lastColon = s.lastIndexOf(':');
  if (lastColon > 0) {
    final hostPart = s.substring(0, lastColon);
    final portPart = s.substring(lastColon + 1);
    if (!hostPart.contains(':') && !hostPart.contains(']')) {
      if (RegExp(r'^\d{1,5}$').hasMatch(portPart)) {
        final port = int.tryParse(portPart);
        if (port != null && port >= 0 && port <= 65535) {
          return SspParsedAuthority(hostPart, port);
        }
      }
    }
  }

  return SspParsedAuthority(s);
}

/// Builds `https://…/sdk` from a **normalized** authority (see
/// [normalizeAdRequestAuthority]).
Uri buildSdkBaseUri(String normalizedAuthority) {
  final a = normalizeAdRequestAuthority(normalizedAuthority);
  final p = parseSspAuthority(a);
  if (p.port != null) {
    return Uri(
      scheme: 'https',
      host: p.host,
      port: p.port,
      path: '/sdk',
    );
  }
  return Uri(scheme: 'https', host: p.host, path: '/sdk');
}

/// Same as [buildSdkBaseUri] but returns a string for maps and HTTP clients.
String buildSdkBaseUrlString(String normalizedAuthority) {
  return buildSdkBaseUri(normalizedAuthority).toString();
}

/// Default production base URL (`https` + [Constants.defaultAdRequestAuthority] + `/sdk`).
String defaultSdkBaseUrlString() {
  return buildSdkBaseUrlString(Constants.defaultAdRequestAuthority);
}
