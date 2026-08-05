import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/companion_ad.dart';

/// Renders VAST HTML or IFrame companion resources in a fullscreen end card.
class VastHtmlCompanionView extends StatefulWidget {
  final CompanionAd companion;
  final VoidCallback onClose;
  final VoidCallback? onTap;

  const VastHtmlCompanionView({
    super.key,
    required this.companion,
    required this.onClose,
    this.onTap,
  });

  @override
  State<VastHtmlCompanionView> createState() => _VastHtmlCompanionViewState();
}

class _VastHtmlCompanionViewState extends State<VastHtmlCompanionView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF2F2F2));

    final companion = widget.companion;
    if (companion.resourceType == CompanionResourceType.html) {
      _controller.loadHtmlString(companion.resource);
    } else {
      _controller.loadRequest(Uri.parse(companion.resource));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F2F2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: WebViewWidget(controller: _controller),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: 12,
            child: Material(
              color: const Color(0x99000000),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: widget.onClose,
                borderRadius: BorderRadius.circular(18),
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
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
            ),
          ),
        ],
      ),
    );
  }
}
