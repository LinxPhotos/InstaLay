import 'dart:convert';

/// Stable marketing-site feed: `https://instalay.linx.photos/updates/latest.json`
const kDefaultUpdateFeedUrl = 'https://instalay.linx.photos/updates/latest.json';

/// One platform artifact in the update feed.
class UpdatePlatformArtifact {
  const UpdatePlatformArtifact({
    required this.url,
    required this.sha256,
    required this.installerKind,
    this.signature,
    this.size,
  });

  final String url;
  final String sha256;
  /// Reserved for Authenticode / Apple notarization / EdDSA later. Null = unset.
  final String? signature;
  /// `exe-setup` | `zip-app` | `dmg` | `msix` | `zip` | `unknown`
  final String installerKind;
  final int? size;

  bool get hasSignature =>
      signature != null && signature!.trim().isNotEmpty;

  factory UpdatePlatformArtifact.fromJson(Map<String, dynamic> json) {
    return UpdatePlatformArtifact(
      url: (json['url'] as String?)?.trim() ?? '',
      sha256: ((json['sha256'] as String?) ?? '').trim().toLowerCase(),
      signature: (json['signature'] as String?)?.trim(),
      installerKind:
          ((json['installerKind'] as String?) ?? 'unknown').trim().toLowerCase(),
      size: json['size'] is int
          ? json['size'] as int
          : int.tryParse('${json['size'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'sha256': sha256,
        if (signature != null) 'signature': signature,
        'installerKind': installerKind,
        if (size != null) 'size': size,
      };
}

/// Root update feed document.
class UpdateFeed {
  const UpdateFeed({
    required this.schemaVersion,
    required this.version,
    required this.channel,
    required this.publishedAt,
    required this.platforms,
    this.notes,
    this.notesUrl,
    this.mandatory = false,
  });

  final int schemaVersion;
  final String version;
  final String channel;
  final DateTime? publishedAt;
  final String? notes;
  final String? notesUrl;
  final bool mandatory;
  final Map<String, UpdatePlatformArtifact> platforms;

  UpdatePlatformArtifact? platform(String key) => platforms[key];

  factory UpdateFeed.fromJson(Map<String, dynamic> json) {
    final rawPlatforms = json['platforms'];
    final platforms = <String, UpdatePlatformArtifact>{};
    if (rawPlatforms is Map) {
      rawPlatforms.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          platforms['$key'] = UpdatePlatformArtifact.fromJson(value);
        } else if (value is Map) {
          platforms['$key'] = UpdatePlatformArtifact.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }
    DateTime? published;
    final publishedRaw = json['publishedAt'];
    if (publishedRaw is String && publishedRaw.isNotEmpty) {
      published = DateTime.tryParse(publishedRaw);
    }
    return UpdateFeed(
      schemaVersion: json['schemaVersion'] is int
          ? json['schemaVersion'] as int
          : int.tryParse('${json['schemaVersion'] ?? 1}') ?? 1,
      version: ((json['version'] as String?) ?? '').trim(),
      channel: ((json['channel'] as String?) ?? 'stable').trim(),
      publishedAt: published,
      notes: (json['notes'] as String?)?.trim(),
      notesUrl: (json['notesUrl'] as String?)?.trim(),
      mandatory: json['mandatory'] == true,
      platforms: platforms,
    );
  }

  static UpdateFeed parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Update feed root must be a JSON object');
    }
    return UpdateFeed.fromJson(Map<String, dynamic>.from(decoded));
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'version': version,
        'channel': channel,
        if (publishedAt != null) 'publishedAt': publishedAt!.toUtc().toIso8601String(),
        if (notes != null) 'notes': notes,
        if (notesUrl != null) 'notesUrl': notesUrl,
        'mandatory': mandatory,
        'platforms': {
          for (final e in platforms.entries) e.key: e.value.toJson(),
        },
      };
}
