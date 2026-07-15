import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// Share exported frames toward Instagram (or the system share sheet).
class InstagramShare {
  /// Attempts Instagram share intent on mobile; falls back to share sheet.
  Future<ShareResult> shareExports(List<String> filePaths) async {
    if (filePaths.isEmpty) {
      throw ArgumentError('No files to share');
    }

    final files = filePaths.map(XFile.new).toList();

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Instagram consumes the share sheet / documents interaction.
      // Direct deep-link posting varies by OS & IG version; share sheet is reliable.
      return SharePlus.instance.share(
        ShareParams(
          files: files,
          text: 'Made with InstaLay',
        ),
      );
    }

    return SharePlus.instance.share(
      ShareParams(
        files: files,
        text: 'InstaLay export — ready for Instagram (${p.basename(filePaths.first)})',
      ),
    );
  }
}
