import 'package:path/path.dart' as p;

/// Ensures [displayName] keeps an extension when one is present; otherwise
/// appends an extension derived from [mimeType].
String displayFileNameWithExtension(String displayName, String mimeType) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) {
    final ext = extensionForMimeType(mimeType);
    return ext.isEmpty ? 'shared' : 'shared.$ext';
  }
  if (p.extension(trimmed).isNotEmpty) return trimmed;
  final ext = extensionForMimeType(mimeType);
  if (ext.isEmpty) return trimmed;
  return '$trimmed.$ext';
}

/// File extension without a leading dot, or empty when unknown.
String extensionForMimeType(String mimeType) {
  final mime = mimeType.toLowerCase().split(';').first.trim();
  return switch (mime) {
    'image/jpeg' || 'image/jpg' || 'image/pjpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/avif' => 'avif',
    'image/jxl' || 'image/jxlp' => 'jxl',
    'image/gif' => 'gif',
    'image/heic' || 'image/heif' => 'heic',
    'video/mp4' || 'video/mpeg4' => 'mp4',
    'video/quicktime' => 'mov',
    'video/3gpp' => '3gp',
    'video/webm' => 'webm',
    'video/x-matroska' => 'mkv',
    _ => _mimeMapFallback(mime),
  };
}

String _mimeMapFallback(String mime) {
  final slash = mime.indexOf('/');
  if (slash < 0 || slash >= mime.length - 1) return '';
  final subtype = mime.substring(slash + 1);
  if (subtype == 'jpeg') return 'jpg';
  if (subtype.contains('jpeg')) return 'jpg';
  if (subtype.startsWith('x-')) {
    return subtype.substring(2);
  }
  return subtype;
}
