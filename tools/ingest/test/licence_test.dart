import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ingest/licence.dart';
import 'package:ingest/sources.dart';
import 'package:test/test.dart';

/// The gate is the whole point of this tool, so it is tested against responses
/// rather than against a network. Every path that is not a positive statement
/// of a redistributable licence must refuse — including the paths where the
/// check simply could not be made.
http.Response ok(Object body) => http.Response(jsonEncode(body), 200);

YouTubeSource youtube(http.Response Function(Uri) respond) =>
    YouTubeSource(apiKey: 'test-key', get: (url) async => respond(url));

ArchiveSource archive(http.Response Function(Uri) respond) =>
    ArchiveSource(get: (url) async => respond(url));

Map<String, dynamic> video(String licence) => {
  'items': [
    {
      'status': {'license': licence},
      'snippet': {'title': 'A Reading', 'channelTitle': 'Someone'},
    },
  ],
};

void main() {
  group('YouTube', () {
    test('creativeCommon is allowed, with attribution captured', () async {
      final verdict = await youtube((_) => ok(video('creativeCommon')))
          .check('abc');

      expect(verdict.allowed, isTrue);
      // The compiler refuses a reference without attribution, so an ingest that
      // could not determine one would produce unbuildable content.
      expect(verdict.attribution, contains('A Reading'));
      expect(verdict.attribution, contains('Someone'));
      expect(
        verdict.licenceUrl,
        contains('creativecommons.org/licenses/by/3.0'),
      );
    });

    test('the standard YouTube licence is refused', () async {
      // The default. Most of the platform.
      final verdict = await youtube((_) => ok(video('youtube'))).check('abc');

      expect(verdict.allowed, isFalse);
      expect(verdict.reason, contains('youtube'));
    });

    test('an unknown video is refused', () async {
      final verdict = await youtube((_) => ok({'items': []})).check('abc');
      expect(verdict.allowed, isFalse);
    });

    test('an API error refuses rather than assuming', () async {
      final verdict = await youtube((_) => http.Response('nope', 403))
          .check('abc');

      expect(verdict.allowed, isFalse);
      expect(verdict.reason, contains('403'));
    });

    test('an unreachable API refuses — failing closed', () async {
      // The property that matters most. A check that could not run is not
      // permission, and a tool that downloaded anyway would be worse than no
      // tool.
      final source = YouTubeSource(
        apiKey: 'k',
        get: (_) async => throw const SocketExceptionStub(),
      );

      final verdict = await source.check('abc');
      expect(verdict.allowed, isFalse);
      expect(verdict.reason, contains('could not reach'));
    });

    test('a malformed response refuses', () async {
      final verdict = await youtube((_) => http.Response('<html>', 200))
          .check('abc');
      expect(verdict.allowed, isFalse);
    });
  });

  group('archive.org', () {
    Map<String, dynamic> item({
      String? licenceUrl,
      List<String> collections = const [],
      String? rights,
    }) => {
      'metadata': {
        'title': 'An Old Book',
        'creator': 'A Reader',
        if (licenceUrl != null) 'licenseurl': licenceUrl,
        if (rights != null) 'rights': rights,
        'collection': collections,
      },
    };

    test('LibriVox items are allowed as public domain', () async {
      // The bulk source: real human readings, redistributable outright, and a
      // better fit for scoring than a clipped film scene.
      final verdict = await archive(
        (_) => ok(item(collections: ['librivoxaudio'])),
      ).check('some-book');

      expect(verdict.allowed, isTrue);
      expect(verdict.attribution, contains('A Reader'));
      expect(verdict.licence, contains('Public domain'));
    });

    test('CC BY and CC0 are allowed', () async {
      for (final url in [
        'https://creativecommons.org/licenses/by/4.0/',
        'http://creativecommons.org/publicdomain/zero/1.0/',
        'https://creativecommons.org/licenses/by-sa/3.0/',
      ]) {
        final verdict = await archive((_) => ok(item(licenceUrl: url)))
            .check('x');
        expect(verdict.allowed, isTrue, reason: url);
      }
    });

    test('NonCommercial is refused, with the reason named', () async {
      // Looks permissive; is not. The app has a paid tier.
      final verdict = await archive(
        (_) => ok(
          item(licenceUrl: 'https://creativecommons.org/licenses/by-nc/4.0/'),
        ),
      ).check('x');

      expect(verdict.allowed, isFalse);
      expect(verdict.reason, contains('NonCommercial'));
    });

    test('NoDerivatives is refused — clipping is a derivative', () async {
      final verdict = await archive(
        (_) => ok(
          item(licenceUrl: 'https://creativecommons.org/licenses/by-nd/4.0/'),
        ),
      ).check('x');

      expect(verdict.allowed, isFalse);
      expect(verdict.reason, contains('NoDerivatives'));
    });

    test('a missing licence is refused, not assumed public domain', () async {
      final verdict = await archive(
        (_) => ok(item(rights: 'Copyright the author')),
      ).check('x');

      expect(verdict.allowed, isFalse);
      expect(verdict.reason, contains('Copyright the author'));
    });

    test('an unknown item is refused', () async {
      final verdict = await archive((_) => ok({})).check('x');
      expect(verdict.allowed, isFalse);
    });
  });

  group('the allow list itself', () {
    test('permits only the four families it names', () {
      expect(
        Licences.permits('https://creativecommons.org/licenses/by/4.0/'),
        isTrue,
      );
      expect(
        Licences.permits('https://creativecommons.org/publicdomain/zero/1.0/'),
        isTrue,
      );
      expect(Licences.permits('https://example.com/my-own-licence'), isFalse);
      expect(Licences.permits(''), isFalse);
    });

    test('refuses NC and ND even though they start with an allowed prefix', () {
      // by-nc/ and by-nd/ both begin with ".../licenses/by", so a naive prefix
      // match would let them through.
      expect(
        Licences.permits('https://creativecommons.org/licenses/by-nc/4.0/'),
        isFalse,
      );
      expect(
        Licences.permits('https://creativecommons.org/licenses/by-nd/4.0/'),
        isFalse,
      );
    });
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'network down';
}
