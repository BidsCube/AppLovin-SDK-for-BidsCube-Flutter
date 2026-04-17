import 'package:flutter/widgets.dart';

import 'ad_position.dart';
import 'callbacks.dart';

/// Context passed to the host when building a **custom video ad player** instead of the
/// default IMA-based video widget shipped with this SDK.
class BidscubeVideoPlayerBuildContext {
  const BidscubeVideoPlayerBuildContext({
    required this.placementId,
    required this.baseUrl,
    required this.position,
    this.callback,
    this.width = 320,
    this.height = 240,
    this.borderRadius,
  });

  final String placementId;
  final String baseUrl;
  final AdPosition position;
  final AdCallback? callback;
  final double width;
  final double height;
  final double? borderRadius;
}

/// Host-provided builder for **direct / Flutter-only** video placements.
///
/// Return a widget that loads/plays VAST or progressive video using your own player.
/// When set on [SDKConfig.customVideoPlayerBuilder], the Flutter-only path uses it
/// instead of the default IMA stack for [BidscubeSDK.getVideoAdView].
typedef BidscubeCustomVideoPlayerBuilder =
    Widget Function(BidscubeVideoPlayerBuildContext context);
