/// Parsed Linx → InstaLay launch intent (deep link / handoff query).
///
/// Example: `instalay://import?albumId=…&variantIds=a,b`
class LinxLaunchIntent {
  const LinxLaunchIntent({
    this.albumId,
    this.itemId,
    this.variantIds = const [],
  });

  final String? albumId;
  final String? itemId;
  final List<String> variantIds;

  bool get hasWork =>
      variantIds.isNotEmpty || (albumId != null && albumId!.isNotEmpty);

  static LinxLaunchIntent? tryParse(Uri? uri) {
    if (uri == null) return null;
    final hostOrPath = '${uri.host}${uri.path}'.toLowerCase();
    final isImport =
        hostOrPath.contains('import') ||
        uri.queryParameters.containsKey('variantIds') ||
        uri.queryParameters.containsKey('albumId');
    if (!isImport && uri.scheme != 'instalay') {
      // Allow https handoff pages that only carry query params
      if (uri.queryParameters.isEmpty) return null;
    }

    final variants = (uri.queryParameters['variantIds'] ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final albumId = uri.queryParameters['albumId']?.trim();
    final itemId = uri.queryParameters['itemId']?.trim();
    final intent = LinxLaunchIntent(
      albumId: (albumId == null || albumId.isEmpty) ? null : albumId,
      itemId: (itemId == null || itemId.isEmpty) ? null : itemId,
      variantIds: variants,
    );
    return intent.hasWork ? intent : null;
  }
}
