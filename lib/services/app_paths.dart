import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk app data folder (lowercase). Visible product name remains InstaLay.
const appDataFolderName = 'instalay';

/// Pre-rename folder; migrated once into [appDataFolderName].
const legacyAppDataFolderName = 'insta_lay';

/// Rewrite absolute paths that still point at the pre-rename app data folder.
///
/// Folder migration renames `insta_lay/` → `instalay/`, but project JSON keeps
/// absolute `sourcePath` / thumb paths — those must be rewritten or media look
/// missing even though files still exist under the new folder.
String rewriteLegacyAppDataPath(String path) {
  if (!path.contains(legacyAppDataFolderName)) return path;
  // Path-segment only (avoid rewriting unrelated folder names).
  return path.replaceAllMapped(
    RegExp(
      '(^|[/\\\\])${RegExp.escape(legacyAppDataFolderName)}(?=[/\\\\]|\$)',
    ),
    (match) => '${match[1]}$appDataFolderName',
  );
}

/// Application-documents root for projects, templates, palettes, etc.
Future<Directory> appDataRoot() async {
  if (kIsWeb) {
    throw UnsupportedError('Local app data is not available on web yet.');
  }
  return _ensureNamedRoot(await getApplicationDocumentsDirectory());
}

/// Application-support root for thumb / source bitmap caches.
Future<Directory> appSupportRoot() async {
  if (kIsWeb) {
    throw UnsupportedError('Local app data is not available on web yet.');
  }
  return _ensureNamedRoot(await getApplicationSupportDirectory());
}

Future<Directory> _ensureNamedRoot(Directory base) async {
  final next = Directory(p.join(base.path, appDataFolderName));
  final legacy = Directory(p.join(base.path, legacyAppDataFolderName));
  if (!await next.exists() && await legacy.exists()) {
    try {
      await legacy.rename(next.path);
    } catch (_) {
      await _copyDir(legacy, next);
    }
  }
  if (!await next.exists()) {
    await next.create(recursive: true);
  }
  return next;
}

Future<void> _copyDir(Directory from, Directory to) async {
  await to.create(recursive: true);
  await for (final entity in from.list(recursive: false)) {
    final name = p.basename(entity.path);
    final dest = p.join(to.path, name);
    if (entity is Directory) {
      await _copyDir(entity, Directory(dest));
    } else if (entity is File) {
      await entity.copy(dest);
    }
  }
}
