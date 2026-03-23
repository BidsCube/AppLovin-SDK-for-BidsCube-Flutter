import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:interactive_media_ads/interactive_media_ads.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// IMA VAST Video Ad View Widget
/// Uses Google's Interactive Media Ads SDK for proper VAST video ad handling
class ImaVastVideoAdView extends StatefulWidget {
  /// Placement ID for the ad
  final String placementId;

  /// Ad callback handler
  final AdCallback? callback;

  /// Ad width
  final double width;

  /// Ad height
  final double height;

  /// Base URL for ad requests
  final String baseUrl;

  /// Ad type
  final AdType adType;

  /// Ad position
  final AdPosition position;

  /// Optional border radius for the ad view
  final double? borderRadius;

  const ImaVastVideoAdView({
    super.key,
    required this.placementId,
    this.callback,
    this.width = 320,
    this.height = 240,
    this.baseUrl = Constants.baseURL,
    this.adType = AdType.video,
    this.position = AdPosition.unknown,
    this.borderRadius,
  });

  @override
  State<ImaVastVideoAdView> createState() => _ImaVastVideoAdViewState();
}

class _ImaVastVideoAdViewState extends State<ImaVastVideoAdView>
    with WidgetsBindingObserver {
  // IMA SDK components
  late final AdDisplayContainer _adDisplayContainer;
  AdsLoader? _adsLoader;
  AdsManager? _adsManager;

  // Content video player
  VideoPlayerController? _contentVideoController;
  bool _shouldShowContentVideo = false;
  Timer? _contentProgressTimer;

  // State management
  bool _isLoading = true;
  bool _hasError = false;
  AdPosition _currentPosition = AdPosition.unknown;

  // Content progress provider for mid-roll ads
  final ContentProgressProvider _contentProgressProvider =
      ContentProgressProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAdContainer();
    _loadVastAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contentProgressTimer?.cancel();
    _contentVideoController?.dispose();
    _adsManager?.destroy();
    super.dispose();
  }

  void _initializeAdContainer() {
    _adDisplayContainer = AdDisplayContainer(
      onContainerAdded: (AdDisplayContainer container) {
        _adsLoader = AdsLoader(
          container: container,
          onAdsLoaded: (OnAdsLoadedData data) {
            final AdsManager manager = data.manager;
            _adsManager = data.manager;

            manager.setAdsManagerDelegate(
              AdsManagerDelegate(
                onAdEvent: (AdEvent event) {
                  SDKLogger.info(
                    'IMA AdEvent: ${event.type} => ${event.adData}',
                  );

                  switch (event.type) {
                    case AdEventType.loaded:
                      widget.callback?.onAdLoaded(widget.placementId);
                      manager.start();
                      widget.callback?.onAdDisplayed(widget.placementId);
                    case AdEventType.contentPauseRequested:
                      _pauseContent();
                    case AdEventType.contentResumeRequested:
                      _resumeContent();
                    case AdEventType.allAdsCompleted:
                      manager.destroy();
                      _adsManager = null;
                      widget.callback?.onVideoAdCompleted(widget.placementId);
                    case AdEventType.clicked:
                      widget.callback?.onAdClicked(widget.placementId);
                    case AdEventType.complete:
                      widget.callback?.onVideoAdCompleted(widget.placementId);
                    case _:
                  }
                },
                onAdErrorEvent: (AdErrorEvent event) {
                  SDKLogger.error(
                    'IMA AdErrorEvent: ${event.error.message}',
                    null,
                  );
                  widget.callback?.onAdFailed(
                    widget.placementId,
                    'IMA_ERROR',
                    event.error.message ?? 'Unknown IMA error',
                  );
                  _resumeContent();
                },
              ),
            );

            manager.init(
              settings: AdsRenderingSettings(enablePreloading: true),
            );
          },
          onAdsLoadError: (AdsLoadErrorData data) {
            SDKLogger.error('IMA AdsLoadError: ${data.error.message}', null);
            widget.callback?.onAdFailed(
              widget.placementId,
              'IMA_LOAD_ERROR',
              data.error.message ?? 'Unknown IMA load error',
            );
            _resumeContent();
          },
        );
      },
    );
  }

  Future<void> _loadVastAd() async {
    widget.callback?.onAdLoading(widget.placementId);
    String vastXml = '';
    try {
      SDKLogger.info('Loading VAST video ad: ${widget.placementId}');

      // First, try to get VAST XML from the API using URLBuilder
      final apiURL = await URLBuilder.buildAdRequestURL(
        placementId: widget.placementId,
        adType: widget.adType,
        position: widget.position,
        baseURL: widget.baseUrl,
      );

      if (apiURL == null) {
        throw Exception('Failed to build API URL for VAST request');
      }

      // Make direct HTTP request to the built URL
      final response = await http.get(
        Uri.parse(apiURL),
        headers: await _requestHeaders(),
      );

      SDKLogger.info('VAST response: ${response.statusCode}');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        // Check if response is JSON with adm parameter
        try {
          final jsonResponse = json.decode(response.body);
          if (jsonResponse is Map<String, dynamic>) {
            // Extract position from server response if available
            if (jsonResponse['position'] != null) {
              final positionValue = jsonResponse['position'] as int;
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

            if (jsonResponse['adm'] != null) {
              // Preserve adm and serialize if needed
              final dynamic admValue = jsonResponse['adm'];
              final String admString =
                  admValue is String ? admValue : json.encode(admValue);

              // If host app provided onAdRenderOverride, call it and skip SDK rendering
              if (widget.callback?.onAdRenderOverride != null) {
                SDKLogger.info(
                  'Calling onAdRenderOverride for placement ${widget.placementId} (VAST)',
                );
                try {
                  widget.callback?.onAdRenderOverride!(
                    widget.placementId,
                    admString,
                    _currentPosition,
                  );
                  return; // Skip SDK rendering
                } catch (e) {
                  SDKLogger.error('Error in onAdRenderOverride callback', e);
                }

                // Host app will render the ad. Mark loading finished and notify lifecycle callbacks.
                if (mounted) setState(() => _isLoading = false);
                widget.callback?.onAdLoaded(widget.placementId);
                widget.callback?.onAdDisplayed(widget.placementId);

                // Do not proceed with internal IMA request; leave vastXml empty
                vastXml = '';
              } else {
                vastXml = admString;
              }
            } else {
              // Response is direct VAST XML
              vastXml = response.body;
            }
          } else {
            // Response is direct VAST XML
            vastXml = response.body;
          }
        } catch (e) {
          // Response is not JSON, treat as direct VAST XML
          vastXml = response.body;
        }

        setState(() {
          _isLoading = false;
        });

        // Request ads through IMA SDK using the original API URL
        // The IMA SDK expects a URL that returns VAST XML, not the XML content itself
        // Add a small delay to ensure AdsLoader is ready
        await Future.delayed(const Duration(milliseconds: 500));
        // Only request ads when host did not provide an override
        if (widget.callback?.onAdRenderOverride == null) {
          await _requestAds(_adDisplayContainer, vastXml);
        }
      } else {
        throw Exception('No VAST XML received from server');
      }
    } catch (e) {
      SDKLogger.error('VAST ad request failed', e);
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      widget.callback?.onAdFailed(
        widget.placementId,
        'LOAD_ERROR',
        e.toString(),
      );
    }
  }

  Future<void> _requestAds(AdDisplayContainer container, String vastXml) async {
    try {
      await _adsLoader?.requestAds(
        AdsRequest.withAdsResponse(
          adsResponse: vastXml,
          contentProgressProvider: _contentProgressProvider,
        ),
      );
    } catch (e) {
      SDKLogger.error('Failed to request ads', e);
      widget.callback?.onAdFailed(
        widget.placementId,
        'REQUEST_ERROR',
        e.toString(),
      );
    }
  }

  Future<Map<String, String>> _requestHeaders() async {
    final userAgent = await URLBuilder.buildBrowserUserAgent();
    return {'User-Agent': userAgent, 'Accept': '*/*'};
  }

  Future<void> _resumeContent() async {
    setState(() {
      _shouldShowContentVideo = true;
    });

    if (_adsManager != null) {
      _contentProgressTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (Timer timer) async {
          if (_contentVideoController?.value.isInitialized == true) {
            final Duration? progress = await _contentVideoController!.position;
            if (progress != null) {
              await _contentProgressProvider.setProgress(
                progress: progress,
                duration: _contentVideoController!.value.duration,
              );
            }
          }
        },
      );
    }

    await _contentVideoController?.play();
  }

  Future<void> _pauseContent() {
    setState(() {
      _shouldShowContentVideo = false;
    });
    _contentProgressTimer?.cancel();
    _contentProgressTimer = null;
    return _contentVideoController?.pause() ?? Future.value();
  }

  BidscubePositionStyle _getPositionBasedStyle() {
    switch (_currentPosition) {
      case AdPosition.unknown:
        return BidscubePositionStyle(
          backgroundColor: Colors.white,
          borderRadius: widget.borderRadius ?? 0.0,
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
          borderRadius: widget.borderRadius ?? 0.0,
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
          borderRadius: widget.borderRadius ?? 0.0,
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
          borderRadius: widget.borderRadius ?? 0.0,
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
          borderRadius: widget.borderRadius ?? 0.0,
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
          borderRadius: widget.borderRadius ?? 0.0,
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
          borderRadius: widget.borderRadius ?? 0.0,
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
          borderRadius: widget.borderRadius ?? 0.0,
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

  @override
  Widget build(BuildContext context) {
    // If host provided an override callback, do not render SDK UI here
    if (widget.callback?.onAdRenderOverride != null) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    final positionStyle = _getPositionBasedStyle();

    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: positionStyle.backgroundColor,
          borderRadius: BorderRadius.circular(positionStyle.borderRadius ?? 0),
          border: positionStyle.border,
          boxShadow: positionStyle.boxShadow,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: positionStyle.backgroundColor,
          borderRadius: BorderRadius.circular(positionStyle.borderRadius ?? 0),
          border: positionStyle.border,
          boxShadow: positionStyle.boxShadow,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, color: Colors.grey, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Ad not loaded or placement ID does not exist',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 0.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 0.0),
        child: Stack(
          children: <Widget>[
            // The display container must be on screen before any Ads can be loaded
            _adDisplayContainer,
            if (_shouldShowContentVideo &&
                _contentVideoController?.value.isInitialized == true)
              VideoPlayer(_contentVideoController!),
          ],
        ),
      ),
    );
  }
}
