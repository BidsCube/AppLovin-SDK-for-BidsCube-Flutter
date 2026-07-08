import 'package:xml/xml.dart';

/// VAST (Video Ad Serving Template) parser for handling video ads
class VastParser {
  /// Parse VAST XML and extract video ad information
  static Future<VastAd?> parseVast(String vastXml) async {
    try {
      final document = XmlDocument.parse(vastXml);
      final vastElement = document.rootElement;

      if (vastElement.name.local != 'VAST') {
        throw Exception('Invalid VAST XML: Root element must be VAST');
      }

      final adElement = vastElement.findAllElements('Ad').firstOrNull;
      if (adElement == null) {
        throw Exception('No Ad element found in VAST XML');
      }

      final inlineElement = adElement.findAllElements('InLine').firstOrNull;
      if (inlineElement == null) {
        throw Exception('No InLine element found in VAST XML');
      }

      return _parseInlineAd(inlineElement);
    } catch (e) {
      throw Exception('Failed to parse VAST XML: $e');
    }
  }

  static VastAd _parseInlineAd(XmlElement inlineElement) {
    final adSystem =
        inlineElement.findAllElements('AdSystem').firstOrNull?.innerText ??
            'Unknown';
    final adTitle =
        inlineElement.findAllElements('AdTitle').firstOrNull?.innerText ?? '';
    final description =
        inlineElement.findAllElements('Description').firstOrNull?.innerText ??
            '';

    final creatives = <VastCreative>[];
    for (final creativeElement in inlineElement.findAllElements('Creative')) {
      final creative = _parseCreative(creativeElement);
      if (creative != null) {
        creatives.add(creative);
      }
    }

    final trackingEvents = <String, List<String>>{};
    final impressionUrls = <String>[];
    for (final impressionElement in inlineElement.findAllElements(
      'Impression',
    )) {
      final url = impressionElement.innerText.trim();
      if (url.isNotEmpty) {
        impressionUrls.add(url);
      }
    }
    if (impressionUrls.isNotEmpty) {
      trackingEvents['impression'] = impressionUrls;
    }

    for (final creative in creatives) {
      if (creative is VastLinearCreative) {
        for (final tracking in creative.trackingEvents) {
          trackingEvents[tracking.event] = trackingEvents[tracking.event] ?? [];
          trackingEvents[tracking.event]!.add(tracking.url);
        }
      }
    }

    String? companionPreviewUrl;
    String? companionClickThroughUrl;
    int skipOffsetSeconds = -1;
    String? videoUrl;
    String? clickThroughUrl;
    final clickTrackingUrls = <String>[];

    for (final creativeElement in inlineElement.findAllElements('Creative')) {
      final companion = _parseCompanion(creativeElement);
      companionPreviewUrl ??= companion.previewUrl;
      companionClickThroughUrl ??= companion.clickThroughUrl;

      final linear = creativeElement.findAllElements('Linear').firstOrNull;
      if (linear != null) {
        skipOffsetSeconds = _maxSkipOffset(
          skipOffsetSeconds,
          _parseSkipOffset(linear.getAttribute('skipoffset')),
        );
      }
    }

    for (final creative in creatives) {
      if (creative is VastLinearCreative) {
        if (skipOffsetSeconds < 0 && creative.skipOffsetSeconds >= 0) {
          skipOffsetSeconds = creative.skipOffsetSeconds;
        }
        videoUrl ??= creative.bestVideoUrl;
        for (final click in creative.videoClicks) {
          if (click.type == 'ClickThrough' && clickThroughUrl == null) {
            clickThroughUrl = click.url.trim();
          } else if (click.type == 'ClickTracking') {
            clickTrackingUrls.add(click.url.trim());
          }
        }
      }
    }

    return VastAd(
      adSystem: adSystem,
      adTitle: adTitle,
      description: description,
      creatives: creatives,
      trackingEvents: trackingEvents,
      companionPreviewUrl: companionPreviewUrl,
      companionClickThroughUrl: companionClickThroughUrl,
      skipOffsetSeconds: skipOffsetSeconds,
      videoUrl: videoUrl,
      clickThroughUrl: clickThroughUrl,
      clickTrackingUrls: clickTrackingUrls,
    );
  }

  static VastCreative? _parseCreative(XmlElement creativeElement) {
    final linearElement = creativeElement.findAllElements('Linear').firstOrNull;
    if (linearElement != null) {
      return _parseLinearCreative(linearElement);
    }

    final nonLinearElement =
        creativeElement.findAllElements('NonLinear').firstOrNull;
    if (nonLinearElement != null) {
      return _parseNonLinearCreative(nonLinearElement);
    }

    return null;
  }

  static VastLinearCreative _parseLinearCreative(XmlElement linearElement) {
    final duration =
        linearElement.findAllElements('Duration').firstOrNull?.innerText ??
            '00:00:30';

    final mediaFiles = <VastMediaFile>[];
    for (final mediaFileElement in linearElement.findAllElements('MediaFile')) {
      mediaFiles.add(
        VastMediaFile(
          url: mediaFileElement.innerText.trim(),
          type: mediaFileElement.getAttribute('type') ?? '',
          width:
              int.tryParse(mediaFileElement.getAttribute('width') ?? '0') ?? 0,
          height:
              int.tryParse(mediaFileElement.getAttribute('height') ?? '0') ?? 0,
          delivery: mediaFileElement.getAttribute('delivery') ?? 'progressive',
        ),
      );
    }

    final trackingEvents = <VastTrackingEvent>[];
    final trackingElement =
        linearElement.findAllElements('TrackingEvents').firstOrNull;
    if (trackingElement != null) {
      for (final trackingEventElement in trackingElement.findAllElements(
        'Tracking',
      )) {
        final event = trackingEventElement.getAttribute('event') ?? '';
        final url = trackingEventElement.innerText.trim();
        if (event.isNotEmpty && url.isNotEmpty) {
          trackingEvents.add(VastTrackingEvent(event: event, url: url));
        }
      }
    }

    final videoClicks = <VastVideoClick>[];
    final videoClicksElement =
        linearElement.findAllElements('VideoClicks').firstOrNull;
    if (videoClicksElement != null) {
      final clickThroughElement =
          videoClicksElement.findAllElements('ClickThrough').firstOrNull;
      if (clickThroughElement != null) {
        videoClicks.add(
          VastVideoClick(
            type: 'ClickThrough',
            url: clickThroughElement.innerText.trim(),
          ),
        );
      }

      for (final clickTrackingElement in videoClicksElement.findAllElements(
        'ClickTracking',
      )) {
        videoClicks.add(
          VastVideoClick(
            type: 'ClickTracking',
            url: clickTrackingElement.innerText.trim(),
          ),
        );
      }
    }

    return VastLinearCreative(
      duration: duration,
      mediaFiles: mediaFiles,
      trackingEvents: trackingEvents,
      videoClicks: videoClicks,
      skipOffsetSeconds: _parseSkipOffset(
        linearElement.getAttribute('skipoffset'),
      ),
    );
  }

  static VastNonLinearCreative _parseNonLinearCreative(
    XmlElement nonLinearElement,
  ) {
    final staticResources = <VastStaticResource>[];
    for (final staticResourceElement in nonLinearElement.findAllElements(
      'StaticResource',
    )) {
      staticResources.add(
        VastStaticResource(
          url: staticResourceElement.innerText.trim(),
          creativeType:
              staticResourceElement.getAttribute('creativeType') ?? '',
        ),
      );
    }

    final trackingEvents = <VastTrackingEvent>[];
    final trackingElement =
        nonLinearElement.findAllElements('TrackingEvents').firstOrNull;
    if (trackingElement != null) {
      for (final trackingEventElement in trackingElement.findAllElements(
        'Tracking',
      )) {
        final event = trackingEventElement.getAttribute('event') ?? '';
        final url = trackingEventElement.innerText.trim();
        if (event.isNotEmpty && url.isNotEmpty) {
          trackingEvents.add(VastTrackingEvent(event: event, url: url));
        }
      }
    }

    return VastNonLinearCreative(
      staticResources: staticResources,
      trackingEvents: trackingEvents,
    );
  }

  static _CompanionData _parseCompanion(XmlElement creativeElement) {
    String? previewUrl;
    String? clickThroughUrl;

    final companionRoots = <XmlElement>[
      ...creativeElement.findAllElements('Companion'),
      ...creativeElement
          .findAllElements('CompanionAds')
          .expand((ads) => ads.findAllElements('Companion')),
    ];

    for (final companion in companionRoots) {
      if (previewUrl == null) {
        final staticResource =
            companion.findAllElements('StaticResource').firstOrNull;
        if (staticResource != null) {
          final url = staticResource.innerText.trim();
          if (url.isNotEmpty) {
            previewUrl = url;
          }
        }
      }

      if (clickThroughUrl == null) {
        final clickThrough =
            companion.findAllElements('CompanionClickThrough').firstOrNull;
        if (clickThrough != null) {
          final url = clickThrough.innerText.trim();
          if (url.isNotEmpty) {
            clickThroughUrl = url;
          }
        }
      }
    }

    return _CompanionData(
      previewUrl: previewUrl,
      clickThroughUrl: clickThroughUrl,
    );
  }

  static int _parseSkipOffset(String? raw) {
    if (raw == null || raw.trim().isEmpty) return -1;

    var value = raw.trim().toLowerCase();
    if (value.endsWith('s')) {
      value = value.substring(0, value.length - 1);
    }

    final direct = int.tryParse(value);
    if (direct != null) return direct;

    final parts = value.split(':');
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final seconds = double.tryParse(parts[2]) ?? 0;
      return (hours * 3600 + minutes * 60 + seconds).round();
    }
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = double.tryParse(parts[1]) ?? 0;
      return (minutes * 60 + seconds).round();
    }

    return -1;
  }

  static int _maxSkipOffset(int current, int next) {
    if (next < 0) return current;
    if (current < 0) return next;
    return current < next ? current : next;
  }
}

class _CompanionData {
  final String? previewUrl;
  final String? clickThroughUrl;

  const _CompanionData({this.previewUrl, this.clickThroughUrl});
}

/// VAST Ad data structure
class VastAd {
  final String adSystem;
  final String adTitle;
  final String description;
  final List<VastCreative> creatives;
  final Map<String, List<String>> trackingEvents;
  final String? companionPreviewUrl;
  final String? companionClickThroughUrl;
  final int skipOffsetSeconds;
  final String? videoUrl;
  final String? clickThroughUrl;
  final List<String> clickTrackingUrls;

  VastAd({
    required this.adSystem,
    required this.adTitle,
    required this.description,
    required this.creatives,
    required this.trackingEvents,
    this.companionPreviewUrl,
    this.companionClickThroughUrl,
    this.skipOffsetSeconds = -1,
    this.videoUrl,
    this.clickThroughUrl,
    this.clickTrackingUrls = const [],
  });

  List<String> get impressionUrls => trackingEvents['impression'] ?? [];
}

/// Base class for VAST creatives
abstract class VastCreative {}

/// Linear creative (video ads)
class VastLinearCreative extends VastCreative {
  final String duration;
  final List<VastMediaFile> mediaFiles;
  final List<VastTrackingEvent> trackingEvents;
  final List<VastVideoClick> videoClicks;
  final int skipOffsetSeconds;

  VastLinearCreative({
    required this.duration,
    required this.mediaFiles,
    required this.trackingEvents,
    required this.videoClicks,
    this.skipOffsetSeconds = -1,
  });

  String? get bestVideoUrl {
    for (final file in mediaFiles) {
      final url = file.url.trim();
      if (url.isEmpty) continue;
      if (file.type.contains('mp4') || url.endsWith('.mp4')) {
        return url;
      }
    }
    for (final file in mediaFiles) {
      final url = file.url.trim();
      if (url.isNotEmpty) return url;
    }
    return null;
  }
}

/// Non-linear creative (banner/image ads)
class VastNonLinearCreative extends VastCreative {
  final List<VastStaticResource> staticResources;
  final List<VastTrackingEvent> trackingEvents;

  VastNonLinearCreative({
    required this.staticResources,
    required this.trackingEvents,
  });
}

/// Media file information
class VastMediaFile {
  final String url;
  final String type;
  final int width;
  final int height;
  final String delivery;

  VastMediaFile({
    required this.url,
    required this.type,
    required this.width,
    required this.height,
    required this.delivery,
  });
}

/// Static resource information
class VastStaticResource {
  final String url;
  final String creativeType;

  VastStaticResource({required this.url, required this.creativeType});
}

/// Tracking event information
class VastTrackingEvent {
  final String event;
  final String url;

  VastTrackingEvent({required this.event, required this.url});
}

/// Video click information
class VastVideoClick {
  final String type;
  final String url;

  VastVideoClick({required this.type, required this.url});
}
