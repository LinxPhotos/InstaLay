import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Result of a user-facing "save export to disk" action.
class ExportSaveResult {
  const ExportSaveResult({
    required this.destinationLabel,
    required this.fileCount,
  });

  /// Single file path, or the folder path when multiple files were written.
  final String destinationLabel;
  final int fileCount;
}

/// Writes already-rendered export files to a user-chosen location via native
/// save / folder dialogs ([FilePicker]).
class ExportSave {
  /// Single file → save-file dialog. Multiple files → pick a folder and copy
  /// each slide with its existing basename (`frame_001.jpg`, …).
  ///
  /// Returns `null` if the user cancels.
  Future<ExportSaveResult?> saveExports({
    required List<String> sourcePaths,
    String? suggestedBaseName,
  }) async {
    if (sourcePaths.isEmpty) {
      throw ArgumentError('No files to save');
    }

    if (sourcePaths.length == 1) {
      return _saveSingle(
        sourcePaths.first,
        suggestedBaseName: suggestedBaseName,
      );
    }
    return _saveMany(sourcePaths);
  }

  Future<ExportSaveResult?> _saveSingle(
    String sourcePath, {
    String? suggestedBaseName,
  }) async {
    final ext = p.extension(sourcePath).replaceFirst('.', '');
    final fileName = _suggestedFileName(
      sourcePath,
      suggestedBaseName: suggestedBaseName,
    );
    final bytes = await File(sourcePath).readAsBytes();

    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save export',
      fileName: fileName,
      bytes: bytes,
      type: ext.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: ext.isEmpty ? null : [ext],
      lockParentWindow: true,
    );
    if (saved == null) return null;
    return ExportSaveResult(destinationLabel: saved, fileCount: 1);
  }

  Future<ExportSaveResult?> _saveMany(List<String> sourcePaths) async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Save exports to folder',
      lockParentWindow: true,
    );
    if (dir == null) return null;

    for (final src in sourcePaths) {
      final dest = p.join(dir, p.basename(src));
      await File(src).copy(dest);
    }
    return ExportSaveResult(
      destinationLabel: dir,
      fileCount: sourcePaths.length,
    );
  }

  static String _suggestedFileName(
    String sourcePath, {
    String? suggestedBaseName,
  }) {
    final ext = p.extension(sourcePath);
    final base = (suggestedBaseName ?? '').trim();
    if (base.isEmpty) return p.basename(sourcePath);
    final safe = base
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (safe.isEmpty) return p.basename(sourcePath);
    if (p.extension(safe).isNotEmpty) return safe;
    return '$safe$ext';
  }
}
