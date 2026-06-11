import 'package:flutter/material.dart';

import '../core/video_interstitial_defaults.dart';

/// Post-roll end card — mirrors Android [VideoInterstitialUiHelper.showEndCard].
class VastEndCardView extends StatelessWidget {
  final String previewUrl;
  final String? clickUrl;
  final String appTitle;
  final double rating;
  final String downloadCount;
  final String priceText;
  final String ctaText;
  final VoidCallback onClose;
  final VoidCallback? onTap;

  const VastEndCardView({
    super.key,
    required this.previewUrl,
    this.clickUrl,
    this.appTitle = VideoInterstitialDefaults.appTitle,
    this.rating = VideoInterstitialDefaults.rating,
    this.downloadCount = VideoInterstitialDefaults.downloadCount,
    this.priceText = VideoInterstitialDefaults.priceText,
    this.ctaText = VideoInterstitialDefaults.ctaText,
    required this.onClose,
    this.onTap,
  });

  static const _bg = Color(0xFFF2F2F2);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textSecondary = Color(0xFF9E9E9E);
  static const _ctaBlue = Color(0xFF007AFF);
  static const _star = Color(0xFFFF9800);
  static const _imagePlaceholder = Color(0xFF5C4B8A);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return ColoredBox(
      color: _bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: screenHeight * 0.64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: onTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: ColoredBox(
                        color: _imagePlaceholder,
                        child: Image.network(
                          previewUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: _imagePlaceholder,
                            child: Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: Colors.white54,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _OverlayCloseButton(onPressed: onClose),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              appTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _RatingRow(rating: rating),
            const SizedBox(height: 4),
            Text(
              downloadCount,
              style: const TextStyle(fontSize: 13, color: _textSecondary),
            ),
            const SizedBox(height: 40),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Price',
                        style: TextStyle(fontSize: 13, color: _textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        priceText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: _ctaBlue,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 14,
                      ),
                      child: Text(
                        ctaText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayCloseButton extends StatelessWidget {
  const _OverlayCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x99000000),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          child: const Center(
            child: Text(
              '✕',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final clamped = rating.clamp(0.0, 5.0);
    return Row(
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final Color color;
        if (clamped >= starIndex) {
          color = VastEndCardView._star;
        } else if (clamped >= starIndex - 0.5) {
          color = const Color(0x66FF9800);
        } else {
          color = const Color(0x33FF9800);
        }
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Text('★', style: TextStyle(fontSize: 18, color: color)),
        );
      }),
    );
  }
}
