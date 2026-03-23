import 'package:flutter/material.dart';

/// Position-based styling for ad views
class BidscubePositionStyle {
  final Color backgroundColor;
  final double? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const BidscubePositionStyle({
    required this.backgroundColor,
    this.borderRadius,
    this.border,
    this.boxShadow,
  });
}
