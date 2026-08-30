/// Whether a piece of audio may be redistributed inside the app.
///
/// This is the whole reason the tool exists. Everything else — downloading,
/// hashing, manifests — is plumbing around this decision, and the decision
/// fails closed: anything not positively identified as redistributable is
/// refused, including anything the check could not reach.
library;

/// What a source says about its own licence.
class LicenceVerdict {
  const LicenceVerdict._({
    required this.allowed,
    required this.licence,
    required this.reason,
    this.attribution,
    this.licenceUrl,
    this.title,
  });

  const LicenceVerdict.allow({
    required String licence,
    required String attribution,
    required String licenceUrl,
    required String title,
  }) : this._(
         allowed: true,
         licence: licence,
         reason: 'redistributable',
         attribution: attribution,
         licenceUrl: licenceUrl,
         title: title,
       );

  const LicenceVerdict.refuse(String reason, {String licence = 'unknown'})
    : this._(allowed: false, licence: licence, reason: reason);

  final bool allowed;
  final String licence;
  final String reason;

  /// Required for anything allowed — the curriculum compiler rejects a
  /// reference without one, so an ingest that could not determine attribution
  /// would produce content that cannot be built.
  final String? attribution;
  final String? licenceUrl;
  final String? title;
}

/// The two licences this project will redistribute.
///
/// Deliberately short. "Creative Commons" alone is not a licence — NC and ND
/// variants are common on both platforms and neither is usable in an app that
/// will eventually charge for a tier.
class Licences {
  const Licences._();

  static const youtubeCreativeCommons = 'creativeCommon';

  /// Archive.org licence URLs that permit redistribution. Matched on prefix,
  /// because these carry version and jurisdiction suffixes.
  static const allowedPrefixes = <String>[
    'http://creativecommons.org/publicdomain/zero',
    'https://creativecommons.org/publicdomain/zero',
    'http://creativecommons.org/publicdomain/mark',
    'https://creativecommons.org/publicdomain/mark',
    'http://creativecommons.org/licenses/by/',
    'https://creativecommons.org/licenses/by/',
    'http://creativecommons.org/licenses/by-sa/',
    'https://creativecommons.org/licenses/by-sa/',
  ];

  /// Prefixes that look permissive and are not, kept explicit so a reviewer can
  /// see they were considered rather than missed.
  static const refusedPrefixes = <String, String>{
    'creativecommons.org/licenses/by-nc':
        'NonCommercial — unusable in an app with a paid tier',
    'creativecommons.org/licenses/by-nd':
        'NoDerivatives — clipping to an excerpt is a derivative',
  };

  static bool permits(String licenceUrl) {
    final url = licenceUrl.trim();
    for (final refused in refusedPrefixes.keys) {
      if (url.contains(refused)) return false;
    }
    return allowedPrefixes.any(url.startsWith);
  }

  static String? refusalReason(String licenceUrl) {
    for (final entry in refusedPrefixes.entries) {
      if (licenceUrl.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
