import 'package:bidscube_sdk_flutter/bidscube_sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/scheduler.dart';

/// WebView-based Image Ad View Widget
/// Renders image ads using WebView without native code dependencies
class WebViewImageAdView extends StatefulWidget {
  /// Placement ID for the ad
  final String placementId;

  /// Ad callback handler
  final AdCallback? callback;

  /// Ad width
  final double width;

  /// Ad height
  final double height;

  /// Ad type for URL building
  final AdType adType;

  /// Ad position for URL building
  final AdPosition position;

  /// Position change callback
  final Function(AdPosition)? onPositionChanged;

  /// Optional border radius for the ad view
  final double? borderRadius;

  const WebViewImageAdView({
    super.key,
    required this.placementId,
    this.callback,
    this.width = 320,
    this.height = 240,
    this.adType = AdType.banner,
    this.position = AdPosition.unknown,
    this.onPositionChanged,
    this.borderRadius,
  });

  @override
  State<WebViewImageAdView> createState() => _WebViewImageAdViewState();
}

class _WebViewImageAdViewState extends State<WebViewImageAdView> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _adClickUrl;
  AdPosition _currentPosition = AdPosition.unknown;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.position;
    _initializeWebView();
    _loadAd();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Allow initial load of data: URLs and about:blank
            if (request.url.startsWith('data:') ||
                request.url == 'about:blank') {
              return NavigationDecision.navigate;
            }

            // Open all other URLs in external browser
            _openInExternalBrowser(request.url);
            widget.callback?.onAdClicked(widget.placementId);
            return NavigationDecision.prevent;
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            widget.callback?.onAdLoaded(widget.placementId);
            widget.callback?.onAdDisplayed(widget.placementId);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
            widget.callback?.onAdFailed(
              widget.placementId,
              'WEBVIEW_ERROR',
              error.description,
            );
          },
        ),
      );
  }

  Future<void> _openInExternalBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        SDKLogger.error('Could not launch URL: $url', null);
      }
    } catch (e) {
      SDKLogger.error('Error launching URL: $url', e);
    }
  }

  Future<void> _loadAd() async {
    // Avoid calling host callbacks synchronously during initState/build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      widget.callback?.onAdLoading(widget.placementId);
    });

    try {
      // Request the actual ad data from the API
      final adData = await _requestAd();

      if (adData != null && adData['adm'] != null) {
        // If host app provided onAdRenderOverride, call it and skip loading the WebView
        if (widget.callback?.onAdRenderOverride != null) {
          SDKLogger.info(
            'Calling onAdRenderOverride for placement ${widget.placementId} (WebView)',
          );
          try {
            widget.callback?.onAdRenderOverride!(
              widget.placementId,
              adData['adm'] ?? '',
              _currentPosition,
            );
            return; // Skip SDK rendering
          } catch (e) {
            SDKLogger.error('Error in onAdRenderOverride callback', e);
          }

          // Host app will render. Update UI state and lifecycle callbacks.
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          widget.callback?.onAdLoaded(widget.placementId);
          widget.callback?.onAdDisplayed(widget.placementId);
        } else {
          // Create HTML content with the actual ad data and load it
          final htmlContent = _createAdHTML(adData);
          await _controller.loadHtmlString(htmlContent);
        }
      } else {
        // No ad available - show error placeholder
        throw Exception('Ad not loaded or placement ID does not exist');
      }
    } catch (e) {
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

  Future<Map<String, dynamic>?> _requestAd() async {
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

              // Notify parent widget about position change
              widget.onPositionChanged?.call(serverPosition);
            }

            return data;
          } catch (e) {
            throw Exception('Invalid JSON response: ${e.toString()}');
          }
        } else {
          // Server returned HTML instead of JSON (likely 404 page)
          throw Exception(
            'Server returned HTML instead of JSON. Content-Type: $contentType',
          );
        }
      } else {
        throw Exception('Failed to load ad: ${response.statusCode}');
      }
    } catch (e) {
      SDKLogger.error('Failed to load ad', e);
      // Re-throw the error instead of returning mock data
      rethrow;
    }
  }

  String _createAdHTML(Map<String, dynamic> adData) {
    final adm = adData['adm'] as String? ?? '';
    final clickUrl = adData['clickUrl'] as String? ?? '';
    final title = adData['title'] as String? ?? 'Advertisement';
    final description = adData['description'] as String? ?? '';

    // Extract HTML from document.write() if present
    String cleanedAdm = adm;
    if (adm.contains('document.write(')) {
      cleanedAdm = _extractFromDocumentWrite(adm);
      SDKLogger.info('Cleaned HTML: $cleanedAdm');
    }

    // Check if adm contains HTML content (has HTML tags)
    final hasHtmlTags = cleanedAdm.contains('<') && cleanedAdm.contains('>');
    final hasDoctype = cleanedAdm.toLowerCase().contains('<!doctype');

    if (hasHtmlTags && !hasDoctype) {
      // adm contains HTML without DOCTYPE, wrap it properly
      return _wrapHtml(cleanedAdm);
    } else if (hasDoctype) {
      // adm already contains full HTML with DOCTYPE, use it directly
      return cleanedAdm;
    } else {
      // adm is just an image URL or plain text, create full HTML structure
      return _createImageAdHTML(cleanedAdm, title, description, clickUrl);
    }
  }

  /// Extract HTML content from document.write() statement
  String _extractFromDocumentWrite(String adm) {
    try {
      String content = adm.trim();

      // Pattern 1: document.write(<html content>); - unquoted HTML
      // This is what the ad server returns
      if (content.startsWith('document.write(') && content.endsWith(');')) {
        content = content.substring(
          'document.write('.length,
          content.length - 2,
        );
        content = content.trim();

        // Unescape the content
        content = _unescapeHtml(content);

        // Remove the URL text node from span if present
        content = _cleanupAdContent(content);

        SDKLogger.info('Extracted HTML from document.write (unquoted)');
        return content;
      }

      // Pattern 2: document.write("quoted html") or document.write('quoted html')
      final writeRegex = RegExp(
        r'document\.write\s*\(\s*['
        "\"'"
        r'](.+?)['
        "\"'"
        r']\s*\)\s*;?\s*$',
        dotAll: true,
      );
      final match = writeRegex.firstMatch(content);

      if (match != null) {
        content = match.group(1) ?? content;
        content = _unescapeHtml(content);
        content = _cleanupAdContent(content);

        SDKLogger.info('Extracted HTML from document.write (quoted)');
        return content;
      }

      SDKLogger.info('No document.write pattern found, returning original');
      return adm;
    } catch (e) {
      SDKLogger.error('Error extracting from document.write', e);
      return adm;
    }
  }

  /// Unescape HTML entities and special characters
  String _unescapeHtml(String content) {
    return content
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\/', '/')
        .replaceAll(r'\\n', '\n')
        .replaceAll(r'\\t', '\t')
        .replaceAll(r'\\', '\\');
  }

  /// Clean up ad content by removing URL text nodes from span elements
  String _cleanupAdContent(String content) {
    // Pattern: <span id="banner_xxx">https://url...\<script>
    // We need to remove the URL text and the backslash before <script>
    final urlBeforeScriptRegex = RegExp(
      r'(<span[^>]*>)(https?://[^\s<>"\\]+)(\\+)(<script)',
      caseSensitive: false,
    );

    content = content.replaceAllMapped(urlBeforeScriptRegex, (match) {
      // Keep the opening span tag and the script tag, remove URL and backslashes
      return '${match.group(1)}${match.group(4)}';
    });

    return content;
  }

  /// Wrap HTML content in a proper HTML structure
  String _wrapHtml(String htmlContent) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            margin: 0;
            padding: 0;
            overflow: hidden;
            background: transparent;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        * {
            box-sizing: border-box;
        }
        img {
            max-width: 100%;
            height: auto;
            display: block;
        }
        a {
            cursor: pointer;
        }
    </style>
</head>
<body>
    $htmlContent
</body>
</html>
''';
  }

  /// Create HTML for simple image ads
  String _createImageAdHTML(
    String imageUrl,
    String title,
    String description,
    String clickUrl,
  ) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ad Display</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .ad-container {
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
            max-width: 100%;
            width: 100%;
        }
        .ad-image {
            width: 100%;
            height: auto;
            display: block;
        }
        .ad-content {
            padding: 16px;
        }
        .ad-title {
            font-size: 18px;
            font-weight: 600;
            color: #333;
            margin: 0 0 8px 0;
        }
        .ad-description {
            font-size: 14px;
            color: #666;
            margin: 0 0 12px 0;
            line-height: 1.4;
        }
        .ad-cta {
            background: #007AFF;
            color: white;
            padding: 8px 16px;
            border-radius: 6px;
            text-decoration: none;
            display: inline-block;
            font-size: 14px;
            font-weight: 500;
        }
        .ad-cta:hover {
            background: #0056CC;
        }
        .ad-label {
            position: absolute;
            top: 8px;
            right: 8px;
            background: rgba(0,0,0,0.7);
            color: white;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="ad-container">
        <div class="ad-label">Ad</div>
        ${imageUrl.isNotEmpty ? '<img src="$imageUrl" alt="Advertisement" class="ad-image" />' : ''}
        <div class="ad-content">
            <h3 class="ad-title">$title</h3>
            ${description.isNotEmpty ? '<p class="ad-description">$description</p>' : ''}
            ${clickUrl.isNotEmpty ? '<a href="$clickUrl" class="ad-cta">Learn More</a>' : ''}
        </div>
    </div>
    <script>
        // Handle clicks
        document.addEventListener('click', function(e) {
            if (e.target.tagName === 'A' && e.target.href) {
                e.preventDefault();
                window.open(e.target.href, '_blank');
            }
        });
    </script>
</body>
</html>
''';
  }

  void _handleAdClick() {
    widget.callback?.onAdClicked(widget.placementId);
    if (_adClickUrl != null) {
      // Handle click URL opening
      _controller.loadRequest(Uri.parse(_adClickUrl!));
    }
  }

  Future<Map<String, String>> _requestHeaders() async {
    final userAgent = await URLBuilder.buildBrowserUserAgent();
    return {'User-Agent': userAgent, 'Accept': '*/*'};
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

  @override
  Widget build(BuildContext context) {
    final positionStyle = _getPositionBasedStyle();

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: positionStyle.backgroundColor,
        border: positionStyle.border,
        borderRadius: BorderRadius.circular(positionStyle.borderRadius ?? 0),
        boxShadow: positionStyle.boxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(positionStyle.borderRadius ?? 0),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Loading ad...'),
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
                          onPressed: _loadAd,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: _handleAdClick,
                    child: WebViewWidget(controller: _controller),
                  ),
      ),
    );
  }
}
