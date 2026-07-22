import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Where to send a finished export.
enum ExportDestination { save, share }

bool get exportPrefersSaveFirst {
  if (kIsWeb) return true;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

/// Asks whether to save to disk or open the system share sheet.
///
/// Desktop (and web): **Save to disk** is primary. Mobile: **Share** is primary.
Future<ExportDestination?> showExportDestinationDialog({
  required BuildContext context,
  required int fileCount,
  required String sizeLabel,
}) {
  final preferSave = exportPrefersSaveFirst;
  return showDialog<ExportDestination>(
    context: context,
    builder: (ctx) {
      final saveButton = preferSave
          ? FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, ExportDestination.save),
              icon: const Icon(Icons.save_alt_outlined),
              label: Text(fileCount > 1 ? 'Save to folder…' : 'Save to disk…'),
            )
          : TextButton.icon(
              onPressed: () => Navigator.pop(ctx, ExportDestination.save),
              icon: const Icon(Icons.save_alt_outlined),
              label: Text(fileCount > 1 ? 'Save to folder…' : 'Save to disk…'),
            );
      final shareButton = preferSave
          ? TextButton.icon(
              onPressed: () => Navigator.pop(ctx, ExportDestination.share),
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Share…'),
            )
          : FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, ExportDestination.share),
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Share…'),
            );

      return AlertDialog(
        title: const Text('Export ready'),
        content: Text(
          fileCount == 1
              ? '1 file ready ($sizeLabel). Choose where to send it.'
              : '$fileCount files ready ($sizeLabel). '
                  'Save them to a folder, or share via the system sheet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (preferSave) ...[shareButton, saveButton] else ...[
            saveButton,
            shareButton,
          ],
        ],
      );
    },
  );
}
