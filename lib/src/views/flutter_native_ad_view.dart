import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Flutter Native Ad View Widget
/// Renders native ads using pure Flutter widgets without native code dependencies
class FlutterNativeAdView extends StatefulWidget {
  /// Placement ID for the ad
  final String placementId;

  /// Ad callback handler
  final AdCallback? callback;

  /// Ad width
  final double width;

  /// Ad height
  final double height;

  /// Custom ad template style
  final NativeAdStyle? style;

  /// Ad type
  final AdType adType;

  /// Ad position
  final AdPosition position;

  /// Optional border radius for the ad view
  final double? borderRadius;

  const FlutterNativeAdView({
    super.key,
    required this.placementId,
    this.callback,
    this.width = 320,
    this.height = 240,
    this.style,
    this.adType = AdType.native,
    this.position = AdPosition.unknown,
    this.borderRadius,
  });

  @override
  State<FlutterNativeAdView> createState() => _FlutterNativeAdViewState();
}

class _FlutterNativeAdViewState extends State<FlutterNativeAdView> {
  bool _isLoading = true;
  bool _hasError = false;
  NativeAdData? _adData;
  AdPosition _currentPosition = AdPosition.unknown;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.position;
    _loadNativeAd();
  }

  Future<void> _loadNativeAd() async {
    widget.callback?.onAdLoading(widget.placementId);

    try {
      // Request native ad from Bidscube API
      final adData = await _requestNativeAd();

      if (adData != null) {
        setState(() {
          _adData = adData;
          _isLoading = false;
        });

        widget.callback?.onAdLoaded(widget.placementId);
        widget.callback?.onAdDisplayed(widget.placementId);

        // Native ad loaded successfully
        SDKLogger.info('Native ad loaded: ${_adData!.title}');
        SDKLogger.info(
          '[IMP_TRACK] placement=${widget.placementId} trackers=${_adData?.impressionTrackers?.length ?? 0}',
        );

        // Track impressions
        _trackImpressions();
      } else {
        throw Exception('No native ad available');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      widget.callback?.onAdFailed(
        widget.placementId,
        'NATIVE_AD_ERROR',
        e.toString(),
      );
    }
  }

  Future<NativeAdData?> _requestNativeAd() async {
    try {
      // Build the proper API URL using URL Builder
      final apiURL = await URLBuilder.buildAdRequestURL(
        placementId: widget.placementId,
        adType: widget.adType,
        position: widget.position,
      );

      if (apiURL == null) {
        throw Exception('Failed to build API URL');
      }

      final response = await http.get(
        Uri.parse(apiURL),
        headers: await _requestHeaders(),
      );

      SDKLogger.info('Native ad request: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Check if response is JSON
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('application/json')) {
          try {
            final data = json.decode(response.body);

            // Extract position from server response if available
            if (data['position'] != null) {
              final positionValue = data['position'] as int;
              final serverPosition = AdPositionExtension.fromValue(
                positionValue,
              );
              SDKLogger.info('Position: ${serverPosition.value}');

              // Update current position and trigger re-render
              if (mounted) {
                setState(() {
                  _currentPosition = serverPosition;
                });
              }
            }

            // Check if the response has an 'adm' field with nested JSON
            if (data['adm'] != null) {
              final admData = json.decode(data['adm']);

              // If host app provided an override callback, call it and skip SDK rendering
              if (widget.callback?.onAdRenderOverride != null) {
                SDKLogger.info(
                  'Calling onAdRenderOverride for placement ${widget.placementId} (native)',
                );
                try {
                  final admString = data['adm'] != null
                      ? (data['adm'] is String
                          ? data['adm'] as String
                          : json.encode(admData))
                      : json.encode(data);
                  widget.callback?.onAdRenderOverride!(
                    widget.placementId,
                    admString,
                    _currentPosition,
                  );
                  // Host app will render; skip SDK rendering by returning null
                  return null;
                } catch (e) {
                  SDKLogger.error('Error in onAdRenderOverride callback', e);
                }

                // Host app will render the ad. Mark loading finished and notify lifecycle callbacks.
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
                widget.callback?.onAdLoaded(widget.placementId);
                widget.callback?.onAdDisplayed(widget.placementId);

                // Return null to indicate SDK should not render
                return null;
              }

              // Extract native ad data from the nested structure
              final nativeAdData = _parseNativeAdFromAdm(
                admData as Map<String, dynamic>,
              );
              return nativeAdData;
            } else {
              // Direct native ad data
              return NativeAdData.fromJson(data);
            }
          } catch (e) {
            SDKLogger.error('JSON parsing failed', e);
            throw Exception('Invalid JSON response: ${e.toString()}');
          }
        } else {
          // Server returned HTML instead of JSON (likely 404 page)
          SDKLogger.error('Server returned HTML instead of JSON');
          throw Exception(
            'Server returned HTML instead of JSON. Content-Type: $contentType',
          );
        }
      } else {
        SDKLogger.error(
          'HTTP request failed with status: ${response.statusCode}',
        );
        throw Exception('Failed to load native ad: ${response.statusCode}');
      }
    } catch (e) {
      // Re-throw the error instead of returning mock data
      rethrow;
    }
  }

  void _onAdClicked() {
    widget.callback?.onAdClicked(widget.placementId);

    // Track clicks
    _trackClicks();

    if (_adData?.clickUrl != null) {
      // Handle click URL opening
      // In a real implementation, you would use url_launcher
      SDKLogger.info('Opening URL: ${_adData!.clickUrl}');
    }
  }

  void _onImageClicked() {
    widget.callback?.onAdClicked(widget.placementId);

    // Track clicks
    _trackClicks();

    if (_adData?.imageClickUrl != null) {
      // Handle image click URL opening
      SDKLogger.info('Opening image URL: ${_adData!.imageClickUrl}');
    }
  }

  Future<void> _trackImpressions() async {
    final trackers = _adData?.impressionTrackers;
    if (trackers == null || trackers.isEmpty) {
      SDKLogger.warning(
        '[IMP_TRACK] placement=${widget.placementId} no impression trackers to send',
      );
      return;
    }

    for (var i = 0; i < trackers.length; i++) {
      final tracker = trackers[i];
      try {
        final uri = Uri.parse(tracker);
        SDKLogger.info(
          '[IMP_TRACK] send placement=${widget.placementId} index=$i url=$tracker',
        );
        final response =
            await http.get(uri, headers: await _requestHeaders()).timeout(
                  const Duration(seconds: 10),
                );
        final bodyPreview = _short(response.body, 180);
        SDKLogger.info(
          '[IMP_TRACK] result placement=${widget.placementId} index=$i status=${response.statusCode} body="$bodyPreview"',
        );
      } catch (e, st) {
        SDKLogger.error(
          '[IMP_TRACK] failed placement=${widget.placementId} index=$i url=$tracker',
          e,
          st,
        );
      }
    }
  }

  Future<void> _trackClicks() async {
    if (_adData?.clickTrackers != null) {
      for (final tracker in _adData!.clickTrackers!) {
        try {
          final uri = Uri.parse(tracker);
          final response = await http.get(
            uri,
            headers: await _requestHeaders(),
          );
          SDKLogger.info(
            'Tracked click: $tracker (status: ${response.statusCode})',
          );
        } catch (e) {
          SDKLogger.error('Failed to track click: $tracker', e);
        }
      }
    }
  }

  NativeAdData _parseNativeAdFromAdm(Map<String, dynamic> admData) {
    // Extract native ad data from the complex nested structure
    final native = admData['native'];
    if (native == null) {
      throw Exception('No native ad data found in adm structure');
    }

    String title = '';
    String description = '';
    String? imageUrl;
    String? clickUrl;
    List<String> impressionTrackers = [];

    // Extract title from assets
    final assets = native['assets'] as List<dynamic>?;
    if (assets != null) {
      for (final asset in assets) {
        if (asset['id'] == 2 && asset['title'] != null) {
          title = asset['title']['text'] ?? '';
        } else if (asset['id'] == 4 && asset['img'] != null) {
          imageUrl = asset['img']['url'];
        } else if (asset['id'] == 6 && asset['data'] != null) {
          // This could be price or description
          final value = asset['data']['value'] ?? '';
          if (value.startsWith('\$')) {
            // This is a price
            description = 'Price: $value';
          } else {
            description = value;
          }
        }
      }
    }

    // Extract click URL
    if (native['link'] != null) {
      clickUrl = native['link']['url'];
    }

    // Extract impression trackers
    if (native['imptrackers'] != null) {
      impressionTrackers = List<String>.from(native['imptrackers']);
      SDKLogger.info(
        '[IMP_TRACK] parsed placement=${widget.placementId} imptrackers=${impressionTrackers.length}',
      );
    } else {
      final eventTrackers = native['eventtrackers'];
      final eventTrackersCount =
          eventTrackers is List ? eventTrackers.length : 0;
      SDKLogger.warning(
        '[IMP_TRACK] parsed placement=${widget.placementId} imptrackers=0 eventtrackers=$eventTrackersCount',
      );
    }

    return NativeAdData(
      title: title,
      description: description,
      imageUrl: imageUrl,
      clickUrl: clickUrl,
      callToAction: 'Learn More',
      advertiser: 'Sponsored',
      impressionTrackers:
          impressionTrackers.isNotEmpty ? impressionTrackers : null,
    );
  }

  String _short(String value, int max) {
    if (value.length <= max) {
      return value;
    }
    return '${value.substring(0, max)}...';
  }

  Future<Map<String, String>> _requestHeaders() async {
    final userAgent = await URLBuilder.buildBrowserUserAgent();
    return {'User-Agent': userAgent, 'Accept': '*/*'};
  }

  @override
  Widget build(BuildContext context) {
    // If host app provided override, don't render SDK UI here.
    if (widget.callback?.onAdRenderOverride != null) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    final positionStyle = _getPositionBasedStyle();

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        border: positionStyle.border,
        borderRadius: BorderRadius.circular(positionStyle.borderRadius ?? 0.0),
        color: positionStyle.backgroundColor,
        boxShadow: positionStyle.boxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(positionStyle.borderRadius ?? 0.0),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Loading native ad...'),
                  ],
                ),
              )
            : _hasError
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.block, color: Colors.grey, size: 48),
                        const SizedBox(height: 8),
                        const Text(
                          'Ad not loaded or placement ID does not exist',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadNativeAd,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _adData != null
                    ? _buildNativeAdContent()
                    : const Center(child: Text('No ad data available')),
      ),
    );
  }

  BidscubePositionStyle _getPositionBasedStyle() {
    switch (_currentPosition) {
      case AdPosition.unknown:
        return BidscubePositionStyle(
          backgroundColor: Colors.white,
          borderRadius: widget.borderRadius ?? 8.0,
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
      case AdPosition.aboveTheFold:
        return BidscubePositionStyle(
          backgroundColor: Colors.blue[50]!,
          borderRadius: widget.borderRadius ?? 12.0,
          border: Border.all(color: Colors.blue[200]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withAlpha(51),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case AdPosition.belowTheFold:
        return BidscubePositionStyle(
          backgroundColor: Colors.green[50]!,
          borderRadius: widget.borderRadius ?? 10.0,
          border: Border.all(color: Colors.green[200]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withAlpha(51),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        );
      case AdPosition.header:
        return BidscubePositionStyle(
          backgroundColor: Colors.orange[50]!,
          borderRadius: widget.borderRadius ?? 6.0,
          border: Border.all(color: Colors.orange[200]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withAlpha(51),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
      case AdPosition.footer:
        return BidscubePositionStyle(
          backgroundColor: Colors.purple[50]!,
          borderRadius: widget.borderRadius ?? 6.0,
          border: Border.all(color: Colors.purple[200]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withAlpha(51),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
      case AdPosition.sidebar:
        return BidscubePositionStyle(
          backgroundColor: Colors.teal[50]!,
          borderRadius: widget.borderRadius ?? 8.0,
          border: Border.all(color: Colors.teal[200]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withAlpha(51),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        );
      case AdPosition.fullScreen:
        return BidscubePositionStyle(
          backgroundColor: Colors.red[50]!,
          borderRadius: widget.borderRadius ?? 16.0,
          border: Border.all(color: Colors.red[200]!, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withAlpha(77),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case AdPosition.dependOnTheScreenSize:
        return BidscubePositionStyle(
          backgroundColor: Colors.amber[50]!,
          borderRadius: widget.borderRadius ?? 10.0,
          border: Border.all(color: Colors.amber[200]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withAlpha(51),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        );
    }
  }

  Widget _buildNativeAdContent() {
    final style = widget.style ?? NativeAdStyle.defaultStyle();
    final adData = _adData!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 300;
        final isMediumScreen = constraints.maxWidth < 500;

        return GestureDetector(
          onTap: _onAdClicked,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and advertiser
              _buildAdHeader(adData, style, isSmallScreen),

              // Main content - responsive layout
              Expanded(
                child: isSmallScreen
                    ? _buildSmallScreenLayout(adData, style)
                    : _buildLargeScreenLayout(adData, style, isMediumScreen),
              ),

              // Call to action button
              if (adData.callToAction != null)
                _buildCallToActionButton(adData, style, isSmallScreen),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdHeader(
    NativeAdData adData,
    NativeAdStyle style,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      child: Row(
        children: [
          // Advertiser icon
          if (adData.iconUrl != null)
            Container(
              width: isSmallScreen ? 32 : 40,
              height: isSmallScreen ? 32 : 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                image: DecorationImage(
                  image: NetworkImage(adData.iconUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          SizedBox(width: isSmallScreen ? 6 : 8),
          // Advertiser name
          Expanded(
            child: Text(
              adData.advertiser ?? 'Sponsored',
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 12,
                color: style.secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Ad indicator
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 4 : 6,
              vertical: isSmallScreen ? 1 : 2,
            ),
            decoration: BoxDecoration(
              color: style.accentColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Ad',
              style: TextStyle(
                fontSize: isSmallScreen ? 8 : 10,
                color: style.accentTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallScreenLayout(NativeAdData adData, NativeAdStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            adData.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: style.primaryTextColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Description
          Text(
            adData.description,
            style: TextStyle(fontSize: 12, color: style.secondaryTextColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Image with price overlay and click handling
          if (adData.imageUrl != null)
            Expanded(
              child: GestureDetector(
                onTap: _onImageClicked,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    image: DecorationImage(
                      image: NetworkImage(adData.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Image price overlay
                      if (adData.imagePrice != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(179),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              adData.imagePrice!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLargeScreenLayout(
    NativeAdData adData,
    NativeAdStyle style,
    bool isMediumScreen,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Text content
          Expanded(
            flex: isMediumScreen ? 3 : 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  adData.title,
                  style: TextStyle(
                    fontSize: isMediumScreen ? 15 : 16,
                    fontWeight: FontWeight.bold,
                    color: style.primaryTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Description
                Text(
                  adData.description,
                  style: TextStyle(
                    fontSize: isMediumScreen ? 13 : 14,
                    color: style.secondaryTextColor,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Rating and price row
                _buildRatingAndPrice(adData, style, isMediumScreen),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Image with price overlay and click handling
          if (adData.imageUrl != null)
            GestureDetector(
              onTap: _onImageClicked,
              child: Container(
                width: isMediumScreen ? 80 : 100,
                height: isMediumScreen ? 80 : 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(adData.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    // Image price overlay
                    if (adData.imagePrice != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(179),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            adData.imagePrice!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMediumScreen ? 10 : 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingAndPrice(
    NativeAdData adData,
    NativeAdStyle style,
    bool isMediumScreen,
  ) {
    return Row(
      children: [
        if (adData.rating != null) ...[
          Icon(
            Icons.star,
            size: isMediumScreen ? 14 : 16,
            color: style.accentColor,
          ),
          const SizedBox(width: 4),
          Text(
            adData.rating!.toString(),
            style: TextStyle(
              fontSize: isMediumScreen ? 11 : 12,
              color: style.secondaryTextColor,
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (adData.price != null)
          Text(
            adData.price!,
            style: TextStyle(
              fontSize: isMediumScreen ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: style.accentColor,
            ),
          ),
      ],
    );
  }

  Widget _buildCallToActionButton(
    NativeAdData adData,
    NativeAdStyle style,
    bool isSmallScreen,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(isSmallScreen ? 8 : 12),
      child: ElevatedButton(
        onPressed: _onAdClicked,
        style: ElevatedButton.styleFrom(
          backgroundColor: style.accentColor,
          foregroundColor: style.accentTextColor,
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 8 : 12,
            horizontal: isSmallScreen ? 12 : 16,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          adData.callToAction!,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 12 : 14,
          ),
        ),
      ),
    );
  }
}

/// Native ad data structure
class NativeAdData {
  final String title;
  final String description;
  final String? imageUrl;
  final String? iconUrl;
  final String? callToAction;
  final String? clickUrl;
  final String? advertiser;
  final double? rating;
  final String? price;
  final String? store;
  final String? imagePrice; // Price displayed on the image
  final String? imageClickUrl; // URL to redirect when image is clicked
  final List<String>? impressionTrackers; // URLs to track impressions
  final List<String>? clickTrackers; // URLs to track clicks

  NativeAdData({
    required this.title,
    required this.description,
    this.imageUrl,
    this.iconUrl,
    this.callToAction,
    this.clickUrl,
    this.advertiser,
    this.rating,
    this.price,
    this.store,
    this.imagePrice,
    this.imageClickUrl,
    this.impressionTrackers,
    this.clickTrackers,
  });

  factory NativeAdData.fromJson(Map<String, dynamic> json) {
    return NativeAdData(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'],
      iconUrl: json['iconUrl'],
      callToAction: json['callToAction'],
      clickUrl: json['clickUrl'],
      advertiser: json['advertiser'],
      rating: json['rating']?.toDouble(),
      price: json['price'],
      store: json['store'],
      imagePrice: json['imagePrice'],
      imageClickUrl: json['imageClickUrl'],
      impressionTrackers: json['impressionTrackers'] != null
          ? List<String>.from(json['impressionTrackers'])
          : null,
      clickTrackers: json['clickTrackers'] != null
          ? List<String>.from(json['clickTrackers'])
          : null,
    );
  }
}

/// Native ad style configuration
class NativeAdStyle {
  final Color backgroundColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color accentColor;
  final Color accentTextColor;

  const NativeAdStyle({
    required this.backgroundColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.accentTextColor,
  });

  factory NativeAdStyle.defaultStyle() {
    return const NativeAdStyle(
      backgroundColor: Colors.white,
      primaryTextColor: Colors.black87,
      secondaryTextColor: Colors.grey,
      accentColor: Colors.blue,
      accentTextColor: Colors.white,
    );
  }

  factory NativeAdStyle.darkStyle() {
    return const NativeAdStyle(
      backgroundColor: Colors.black87,
      primaryTextColor: Colors.white,
      secondaryTextColor: Colors.grey,
      accentColor: Colors.blue,
      accentTextColor: Colors.white,
    );
  }

  factory NativeAdStyle.lightStyle() {
    return NativeAdStyle(
      backgroundColor: Colors.grey[50] ?? Colors.white,
      primaryTextColor: Colors.black87,
      secondaryTextColor: Colors.grey[600]!,
      accentColor: Colors.green,
      accentTextColor: Colors.white,
    );
  }
}
