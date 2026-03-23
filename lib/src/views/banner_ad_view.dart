import 'package:flutter/material.dart';
import '../core/callbacks.dart';

/// Banner Ad View Widget
class BannerAdView extends StatefulWidget {
  /// Placement ID for the ad
  final String placementId;

  /// Ad callback handler
  final AdCallback? callback;

  /// Ad width
  final double width;

  /// Ad height
  final double height;

  const BannerAdView({
    super.key,
    required this.placementId,
    this.callback,
    this.width = 320,
    this.height = 50,
  });

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    widget.callback?.onAdLoading(widget.placementId);

    // Simulate ad loading failure to show error placeholder
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Ad not loaded or placement ID does not exist';
        });
        widget.callback?.onAdFailed(
          widget.placementId,
          'LOAD_ERROR',
          'Ad not loaded or placement ID does not exist',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block, color: Colors.grey, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ??
                            'Ad not loaded or placement ID does not exist',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : const Center(child: Text('No ad content available')),
    );
  }
}
