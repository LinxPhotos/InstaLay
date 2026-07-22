import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Where to send a finished export.
enum ExportDestination { save, share }

/// Exporting (Save or Share) must never freeze the version.
///
/// Freezing means "I posted this to Instagram — lock editing." That is an
/// explicit user action (`showMarkAsPostedDialog` / AppBar), not a side effect
/// of writing files or opening the system share sheet.
bool shouldFreezeAfterExport(ExportDestination destination) => false;

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

/// After a successful export, optionally mark the version as posted (freeze).
///
/// Returns `true` only when the user explicitly chooses Mark as posted.
/// Default / dismiss / Keep editing → `false` (project stays editable).
Future<bool> showMarkAsPostedDialog({
  required BuildContext context,
  required String deliveryLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mark as posted?'),
      content: Text(
        '$deliveryLabel\n\n'
        'Exporting does not lock the project. Only mark as posted if you '
        'actually posted to Instagram — that freezes this version so you '
        'cannot edit it by mistake.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Mark as posted'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep editing'),
        ),
      ],
    ),
  );
  return result == true;
}

/// Confirm unlocking a frozen ("posted") version.
Future<bool> showUnfreezeConfirmDialog({required BuildContext context}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Unlock this version?'),
      content: const Text(
        'This clears the posted lock so you can keep editing the same version. '
        'Use this if the project was frozen by mistake (for example after a '
        'local export that never went to Instagram).',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Unlock'),
        ),
      ],
    ),
  );
  return result == true;
}
