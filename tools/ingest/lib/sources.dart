import 'dart:convert';

import 'package:http/http.dart' as http;

import 'licence.dart';

/// Fetches licence metadata. Injectable so the gate can be tested without a
/// network, which matters because the gate is the part that must not be wrong.
typedef HttpGet = Future<http.Response> Function(Uri url);

Future<http.Response> _realGet(Uri url) => http.get(url);

/// Asks YouTube what licence a video carries.
///
/// Uses the Data API rather than scraping, because the `license` field is the
/// only authoritative statement of it — a video's description saying "CC BY"
/// means nothing, and yt-dlp will happily download either way.
class YouTubeSource {
  YouTubeSource({required this.apiKey, HttpGet? get}) : _get = get ?? _realGet;

  final String apiKey;
  final HttpGet _get;

  Future<LicenceVerdict> check(String videoId) async {
    final url = Uri.https('www.googleapis.com', '/youtube/v3/videos', {
      'part': 'status,snippet',
      'id': videoId,
      'key': apiKey,
    });

    final http.Response response;
    try {
      response = await _get(url);
    } catch (error) {
      // Fails closed. An unreachable check is not permission.
      return LicenceVerdict.refuse('could not reach the YouTube API: $error');
    }

    if (response.statusCode != 200) {
      return LicenceVerdict.refuse(
        'YouTube API returned ${response.statusCode}',
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return LicenceVerdict.refuse('unreadable YouTube API response');
    }

    final items = body['items'] as List<dynamic>? ?? const [];
    if (items.isEmpty) {
      return LicenceVerdict.refuse('no such video, or it is not public');
    }

    final item = items.first as Map<String, dynamic>;
    final status = item['status'] as Map<String, dynamic>? ?? const {};
    final snippet = item['snippet'] as Map<String, dynamic>? ?? const {};
    final licence = status['license'] as String? ?? 'unknown';

    if (licence != Licences.youtubeCreativeCommons) {
      return LicenceVerdict.refuse(
        'licence is "$licence", not creativeCommon',
        licence: licence,
      );
    }

    final channel = snippet['channelTitle'] as String? ?? 'unknown channel';
    final title = snippet['title'] as String? ?? videoId;

    return LicenceVerdict.allow(
      licence: 'CC BY 3.0',
      // YouTube's CC option is CC BY 3.0 specifically, and attribution is a
      // condition of it — so the credit is captured at ingest, not left for
      // someone to reconstruct later.
      attribution: '"$title" by $channel, licensed CC BY 3.0',
      licenceUrl: 'https://creativecommons.org/licenses/by/3.0/',
      title: title,
    );
  }
}

/// Asks archive.org what licence an item carries.
///
/// The bulk source: LibriVox publishes there, and its recordings are public
/// domain outright — real human readings, redistributable, and a far better
/// fit for scoring than a clipped film scene ever was.
class ArchiveSource {
  ArchiveSource({HttpGet? get}) : _get = get ?? _realGet;

  final HttpGet _get;

  Future<LicenceVerdict> check(String identifier) async {
    final url = Uri.https('archive.org', '/metadata/$identifier');

    final http.Response response;
    try {
      response = await _get(url);
    } catch (error) {
      return LicenceVerdict.refuse('could not reach archive.org: $error');
    }

    if (response.statusCode != 200) {
      return LicenceVerdict.refuse(
        'archive.org returned ${response.statusCode}',
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return LicenceVerdict.refuse('unreadable archive.org response');
    }

    final metadata = body['metadata'] as Map<String, dynamic>?;
    if (metadata == null) {
      return LicenceVerdict.refuse('no such archive.org item');
    }

    final title = metadata['title']?.toString() ?? identifier;
    final creator = metadata['creator']?.toString() ?? 'unknown';
    final licenceUrl = metadata['licenseurl']?.toString() ?? '';
    final rights = metadata['rights']?.toString() ?? '';

    // LibriVox items are public domain but frequently carry no licenseurl —
    // they state it in `rights` or in the collection instead. Accepting the
    // collection is safe; accepting free text would not be.
    final collections = (metadata['collection'] is List)
        ? (metadata['collection'] as List).map((e) => '$e').toList()
        : [if (metadata['collection'] != null) '${metadata['collection']}'];

    if (collections.contains('librivoxaudio')) {
      return LicenceVerdict.allow(
        licence: 'Public domain (LibriVox)',
        attribution: '"$title", read by $creator. Public domain via LibriVox.',
        licenceUrl: 'https://librivox.org/pages/public-domain/',
        title: title,
      );
    }

    if (licenceUrl.isEmpty) {
      return LicenceVerdict.refuse(
        'no licenseurl and not a LibriVox item'
        '${rights.isEmpty ? '' : ' (rights says: "$rights")'}',
      );
    }

    final refusal = Licences.refusalReason(licenceUrl);
    if (refusal != null) {
      return LicenceVerdict.refuse(refusal, licence: licenceUrl);
    }

    if (!Licences.permits(licenceUrl)) {
      return LicenceVerdict.refuse(
        'licence "$licenceUrl" is not on the allow list',
        licence: licenceUrl,
      );
    }

    return LicenceVerdict.allow(
      licence: licenceUrl,
      attribution: '"$title" by $creator, licensed $licenceUrl',
      licenceUrl: licenceUrl,
      title: title,
    );
  }
}
