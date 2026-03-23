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

      final adElement = vastElement.findElements('Ad').firstOrNull;
      if (adElement == null) {
        throw Exception('No Ad element found in VAST XML');
      }

      final inlineElement = adElement.findElements('InLine').firstOrNull;
      if (inlineElement == null) {
        throw Exception('No InLine element found in VAST XML');
      }

      return _parseInlineAd(inlineElement);
    } catch (e) {
      throw Exception('Failed to parse VAST XML: $e');
    }
  }

  static VastAd _parseInlineAd(XmlElement inlineElement) {
    // Parse ad system
    final adSystem =
        inlineElement.findElements('AdSystem').firstOrNull?.innerText ??
            'Unknown';

    // Parse ad title
    final adTitle =
        inlineElement.findElements('AdTitle').firstOrNull?.innerText ?? '';

    // Parse description
    final description =
        inlineElement.findElements('Description').firstOrNull?.innerText ?? '';

    // Parse creatives
    final creatives = <VastCreative>[];
    final creativeElements = inlineElement.findElements('Creative');

    for (final creativeElement in creativeElements) {
      final creative = _parseCreative(creativeElement);
      if (creative != null) {
        creatives.add(creative);
      }
    }

    // Parse tracking events
    final trackingEvents = <String, List<String>>{};
    for (final creative in creatives) {
      if (creative is VastLinearCreative) {
        for (final tracking in creative.trackingEvents) {
          trackingEvents[tracking.event] = trackingEvents[tracking.event] ?? [];
          trackingEvents[tracking.event]!.add(tracking.url);
        }
      }
    }

    return VastAd(
      adSystem: adSystem,
      adTitle: adTitle,
      description: description,
      creatives: creatives,
      trackingEvents: trackingEvents,
    );
  }

  static VastCreative? _parseCreative(XmlElement creativeElement) {
    final linearElement = creativeElement.findElements('Linear').firstOrNull;
    if (linearElement != null) {
      return _parseLinearCreative(linearElement);
    }

    final nonLinearElement =
        creativeElement.findElements('NonLinear').firstOrNull;
    if (nonLinearElement != null) {
      return _parseNonLinearCreative(nonLinearElement);
    }

    return null;
  }

  static VastLinearCreative _parseLinearCreative(XmlElement linearElement) {
    // Parse duration
    final duration =
        linearElement.findElements('Duration').firstOrNull?.innerText ??
            '00:00:30';

    // Parse media files
    final mediaFiles = <VastMediaFile>[];
    final mediaFileElements = linearElement.findElements('MediaFile');

    for (final mediaFileElement in mediaFileElements) {
      final mediaFile = VastMediaFile(
        url: mediaFileElement.innerText,
        type: mediaFileElement.getAttribute('type') ?? '',
        width: int.tryParse(mediaFileElement.getAttribute('width') ?? '0') ?? 0,
        height:
            int.tryParse(mediaFileElement.getAttribute('height') ?? '0') ?? 0,
        delivery: mediaFileElement.getAttribute('delivery') ?? 'progressive',
      );
      mediaFiles.add(mediaFile);
    }

    // Parse tracking events
    final trackingEvents = <VastTrackingEvent>[];
    final trackingElement =
        linearElement.findElements('TrackingEvents').firstOrNull;
    if (trackingElement != null) {
      final trackingEventElements = trackingElement.findElements('Tracking');
      for (final trackingEventElement in trackingEventElements) {
        final event = trackingEventElement.getAttribute('event') ?? '';
        final url = trackingEventElement.innerText;
        if (event.isNotEmpty && url.isNotEmpty) {
          trackingEvents.add(VastTrackingEvent(event: event, url: url));
        }
      }
    }

    // Parse video clicks
    final videoClicks = <VastVideoClick>[];
    final videoClicksElement =
        linearElement.findElements('VideoClicks').firstOrNull;
    if (videoClicksElement != null) {
      final clickThroughElement =
          videoClicksElement.findElements('ClickThrough').firstOrNull;
      if (clickThroughElement != null) {
        videoClicks.add(
          VastVideoClick(
            type: 'ClickThrough',
            url: clickThroughElement.innerText,
          ),
        );
      }

      final clickTrackingElements = videoClicksElement.findElements(
        'ClickTracking',
      );
      for (final clickTrackingElement in clickTrackingElements) {
        videoClicks.add(
          VastVideoClick(
            type: 'ClickTracking',
            url: clickTrackingElement.innerText,
          ),
        );
      }
    }

    return VastLinearCreative(
      duration: duration,
      mediaFiles: mediaFiles,
      trackingEvents: trackingEvents,
      videoClicks: videoClicks,
    );
  }

  static VastNonLinearCreative _parseNonLinearCreative(
    XmlElement nonLinearElement,
  ) {
    // Parse non-linear ad resources
    final staticResources = <VastStaticResource>[];
    final staticResourceElements = nonLinearElement.findElements(
      'StaticResource',
    );

    for (final staticResourceElement in staticResourceElements) {
      final staticResource = VastStaticResource(
        url: staticResourceElement.innerText,
        creativeType: staticResourceElement.getAttribute('creativeType') ?? '',
      );
      staticResources.add(staticResource);
    }

    // Parse tracking events for non-linear ads
    final trackingEvents = <VastTrackingEvent>[];
    final trackingElement =
        nonLinearElement.findElements('TrackingEvents').firstOrNull;
    if (trackingElement != null) {
      final trackingEventElements = trackingElement.findElements('Tracking');
      for (final trackingEventElement in trackingEventElements) {
        final event = trackingEventElement.getAttribute('event') ?? '';
        final url = trackingEventElement.innerText;
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
}

/// VAST Ad data structure
class VastAd {
  final String adSystem;
  final String adTitle;
  final String description;
  final List<VastCreative> creatives;
  final Map<String, List<String>> trackingEvents;

  VastAd({
    required this.adSystem,
    required this.adTitle,
    required this.description,
    required this.creatives,
    required this.trackingEvents,
  });
}

/// Base class for VAST creatives
abstract class VastCreative {}

/// Linear creative (video ads)
class VastLinearCreative extends VastCreative {
  final String duration;
  final List<VastMediaFile> mediaFiles;
  final List<VastTrackingEvent> trackingEvents;
  final List<VastVideoClick> videoClicks;

  VastLinearCreative({
    required this.duration,
    required this.mediaFiles,
    required this.trackingEvents,
    required this.videoClicks,
  });
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
