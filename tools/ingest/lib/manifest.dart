import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// One ingested file's provenance.
///
/// The manifest is the only committed record of what was fetched. Media itself
/// is gitignored — it is large, and the repository already claims it is
/// "reproducible from the manifests in content/references/". That claim had
/// nothing behind it until this existed: there was no manifest format and no
/// way to restore, so a fresh clone silently had no reference audio.
class ReferenceRecord {
  const ReferenceRecord({
    required this.id,
    required this.source,
    required this.sourceId,
    required this.licence,
    required this.licenceUrl,
    required this.attribution,
    required this.title,
    required this.assetPath,
    required this.sha256,
    required this.bytes,
    required this.fetchedAt,
    required this.approvedBy,
  });

  /// Stable local id, used in curriculum YAML.
  final String id;

  /// 'youtube' or 'archive'.
  final String source;
  final String sourceId;

  final String licence;
  final String licenceUrl;

  /// Shown in the app wherever the clip plays. The curriculum compiler refuses
  /// a reference without one.
  final String attribution;
  final String title;

  /// Relative to the repo root.
  final String assetPath;

  /// So a restore can prove it fetched the same bytes, and so a silently
  /// re-uploaded source is detectable rather than assumed identical.
  final String sha256;
  final int bytes;

  final String fetchedAt;

  /// Who accepted this into the curriculum. A licence check is a machine
  /// decision; whether a clip is *appropriate* is not.
  final String approvedBy;

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'source_id': sourceId,
    'licence': licence,
    'licence_url': licenceUrl,
    'attribution': attribution,
    'title': title,
    'asset_path': assetPath,
    'sha256': sha256,
    'bytes': bytes,
    'fetched_at': fetchedAt,
    'approved_by': approvedBy,
  };

  factory ReferenceRecord.fromJson(Map<String, dynamic> json) =>
      ReferenceRecord(
        id: json['id'] as String,
        source: json['source'] as String,
        sourceId: json['source_id'] as String,
        licence: json['licence'] as String,
        licenceUrl: json['licence_url'] as String,
        attribution: json['attribution'] as String,
        title: json['title'] as String,
        assetPath: json['asset_path'] as String,
        sha256: json['sha256'] as String,
        bytes: json['bytes'] as int,
        fetchedAt: json['fetched_at'] as String,
        approvedBy: json['approved_by'] as String,
      );
}

class ReferenceManifest {
  ReferenceManifest(this.records);

  final List<ReferenceRecord> records;

  static const fileName = 'content/references/manifest.json';

  static ReferenceManifest load(String repoRoot) {
    final file = File('$repoRoot/$fileName');
    if (!file.existsSync()) return ReferenceManifest([]);

    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final items = decoded['references'] as List<dynamic>? ?? const [];
    return ReferenceManifest([
      for (final item in items)
        ReferenceRecord.fromJson(item as Map<String, dynamic>),
    ]);
  }

  void save(String repoRoot) {
    final file = File('$repoRoot/$fileName')
      ..parent.createSync(recursive: true);
    // Sorted so two people ingesting different clips do not produce a conflict
    // over line order.
    final sorted = [...records]..sort((a, b) => a.id.compareTo(b.id));
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        'references': [for (final r in sorted) r.toJson()],
      })}\n',
    );
  }

  ReferenceRecord? byId(String id) {
    for (final record in records) {
      if (record.id == id) return record;
    }
    return null;
  }

  void add(ReferenceRecord record) {
    records.removeWhere((r) => r.id == record.id);
    records.add(record);
  }
}

String hashOf(List<int> bytes) => sha256.convert(bytes).toString();
