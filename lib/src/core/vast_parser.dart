import 'package:xml/xml.dart';

import 'companion_ad.dart';

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
    CompanionAd? companion;
    int skipOffsetSeconds = -1;
    String? videoUrl;
    String? clickThroughUrl;
    final clickTrackingUrls = <String>[];

    for (final creativeElement in inlineElement.findAllElements('Creative')) {
      final linear = creativeElement.findAllElements('Linear').firstOrNull;
      if (linear != null) {
        skipOffsetSeconds = _maxSkipOffset(
          skipOffsetSeconds,
          _parseSkipOffset(linear.getAttribute('skipoffset')),
        );
      }
    }

    companion = selectPostVideoCompanionFromDocument(inlineElement);
    if (companion != null) {
      companionPreviewUrl = companion.isStaticImage ? companion.resource : null;
      companionClickThroughUrl = companion.clickThroughUrl;
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
      companion: companion,
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

  static CompanionAd? selectPostVideoCompanion(String vastXml) {
    try {
      final document = XmlDocument.parse(vastXml);
      final inline = document
          .findAllElements('InLine')
          .firstOrNull;
      if (inline == null) return null;
      return selectPostVideoCompanionFromDocument(inline);
    } catch (_) {
      return null;
    }
  }

  static CompanionAd? selectPostVideoCompanionFromDocument(XmlElement inline) {
    final companions = <CompanionAd>[];
    for (final creative in inline.findAllElements('Creative')) {
      for (final companionElement in _companionElements(creative)) {
        final parsed = _parseCompanionElement(companionElement);
        if (parsed != null) {
          companions.add(parsed);
        }
      }
    }
    if (companions.isEmpty) return null;
    companions.sort(
      (a, b) => _companionPriority(b.resourceType)
          .compareTo(_companionPriority(a.resourceType)),
    );
    return companions.first;
  }

  static bool hasCompanionPreview(String vastXml) {
    final companion = selectPostVideoCompanion(vastXml);
    return companion?.isStaticImage ?? false;
  }

  static bool hasHtmlCompanion(String vastXml) {
    final companion = selectPostVideoCompanion(vastXml);
    return companion?.isInteractive ?? false;
  }

  static Iterable<XmlElement> _companionElements(XmlElement creative) {
    return [
      ...creative.findAllElements('Companion'),
      ...creative
          .findAllElements('CompanionAds')
          .expand((ads) => ads.findAllElements('Companion')),
    ];
  }

  static int _companionPriority(CompanionResourceType type) {
    switch (type) {
      case CompanionResourceType.html:
        return 3;
      case CompanionResourceType.iframe:
        return 2;
      case CompanionResourceType.staticImage:
        return 1;
    }
  }

  static CompanionAd? _parseCompanionElement(XmlElement companion) {
    final html = _firstTagText(companion, 'HTMLResource');
    final iframe = _firstTagText(companion, 'IFrameResource');
    final staticUrl = _firstStaticResourceUrl(companion);

    final CompanionResourceType resourceType;
    final String resource;
    if (html != null && html.isNotEmpty) {
      resourceType = CompanionResourceType.html;
      resource = html;
    } else if (iframe != null && iframe.isNotEmpty) {
      resourceType = CompanionResourceType.iframe;
      resource = iframe;
    } else if (staticUrl != null && staticUrl.isNotEmpty) {
      resourceType = CompanionResourceType.staticImage;
      resource = staticUrl;
    } else {
      return null;
    }

    final width =
        int.tryParse(companion.getAttribute('width') ?? '') ?? 0;
    final height =
        int.tryParse(companion.getAttribute('height') ?? '') ?? 0;
    final clickThrough = _firstTagText(companion, 'CompanionClickThrough');
    final clickTracking = _allTagTexts(companion, 'CompanionClickTracking');
    final trackingEvents =
        companion.findAllElements('TrackingEvents').firstOrNull;
    final creativeView = trackingEvents == null
        ? <String>[]
        : trackingEvents
            .findAllElements('Tracking')
            .where((t) => (t.getAttribute('event') ?? '') == 'creativeView')
            .map((t) => t.innerText.trim())
            .where((url) => url.isNotEmpty)
            .toList();

    return CompanionAd(
      resourceType: resourceType,
      resource: resource,
      width: width,
      height: height,
      clickThroughUrl: clickThrough,
      clickTrackingUrls: clickTracking,
      creativeViewTrackingUrls: creativeView,
    );
  }

  static String? _firstTagText(XmlElement parent, String tag) {
    final element = parent.findAllElements(tag).firstOrNull;
    if (element == null) return null;
    return _extractCdataOrText(element.innerText);
  }

  static List<String> _allTagTexts(XmlElement parent, String tag) {
    return parent
        .findAllElements(tag)
        .map((element) => _extractCdataOrText(element.innerText))
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
  }

  static String? _firstStaticResourceUrl(XmlElement companion) {
    final staticResource =
        companion.findAllElements('StaticResource').firstOrNull;
    if (staticResource == null) return null;
    return _extractCdataOrText(staticResource.innerText);
  }

  static String? _extractCdataOrText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final cdataMatch = RegExp(
      r'<!\[CDATA\[(.*?)\]\]>',
      dotAll: true,
    ).firstMatch(trimmed);
    if (cdataMatch != null) {
      return cdataMatch.group(1)?.trim();
    }
    return trimmed;
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

  static const int defaultSkipSeconds = 15;

  /// VAST `Duration` in milliseconds, or `-1` when absent / unparsable.
  static int getDurationMs(String vastXml) {
    try {
      final document = XmlDocument.parse(vastXml);
      final duration =
          document.findAllElements('Duration').firstOrNull?.innerText.trim();
      if (duration == null || duration.isEmpty) return -1;
      return _parseTimeToMs(duration);
    } catch (_) {
      return -1;
    }
  }

  /// VAST `Linear@skipoffset` in milliseconds, or `-1` when absent / unparsable.
  static int getSkipOffsetMs(String vastXml) {
    try {
      final document = XmlDocument.parse(vastXml);
      final linear = document.findAllElements('Linear').firstOrNull;
      if (linear == null) return -1;
      final skipOffset = linear.getAttribute('skipoffset')?.trim();
      if (skipOffset == null || skipOffset.isEmpty) return -1;
      return _parseSkipOffsetToMs(skipOffset, vastXml: vastXml);
    } catch (_) {
      return -1;
    }
  }

  /// Skip countdown: VAST `Linear@skipoffset` when present, else [defaultSeconds] (15).
  static int resolveSkipSeconds(
    String? vastXml, {
    int defaultSeconds = defaultSkipSeconds,
  }) {
    if (vastXml == null || vastXml.trim().isEmpty) {
      return defaultSeconds;
    }
    final skipMs = getSkipOffsetMs(vastXml);
    if (skipMs > 0) {
      return (skipMs / 1000).ceil().clamp(1, 999999);
    }
    return defaultSeconds;
  }

  static int _parseSkipOffsetToMs(String raw, {String? vastXml}) {
    final value = raw.trim();
    if (value.endsWith('%')) {
      final percent = double.tryParse(
        value.substring(0, value.length - 1).trim(),
      );
      if (percent == null) return -1;
      final durationMs = vastXml != null ? getDurationMs(vastXml) : -1;
      if (durationMs <= 0) return -1;
      return (durationMs * (percent / 100)).round();
    }
    return _parseTimeToMs(value);
  }

  static int _parseTimeToMs(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.endsWith('s')) {
      final seconds = double.tryParse(value.substring(0, value.length - 1));
      if (seconds == null) return -1;
      return (seconds * 1000).round();
    }

    final direct = int.tryParse(value);
    if (direct != null) return direct * 1000;

    final parts = value.split(':');
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final seconds = double.tryParse(parts[2]) ?? 0;
      return ((hours * 3600 + minutes * 60 + seconds) * 1000).round();
    }
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = double.tryParse(parts[1]) ?? 0;
      return ((minutes * 60 + seconds) * 1000).round();
    }
    return -1;
  }

  static int _maxSkipOffset(int current, int next) {
    if (next < 0) return current;
    if (current < 0) return next;
    return current < next ? current : next;
  }
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
  final CompanionAd? companion;
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
    this.companion,
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
