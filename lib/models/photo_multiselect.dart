/// Desktop multiselect helpers for ordered photo lists (batch strip, sources).
abstract final class PhotoMultiselect {
  static Set<String> applyTap({
    required Set<String> current,
    required String? photoId,
    required List<String> orderedIds,
    required bool additive,
    required bool range,
    required String? rangeAnchorId,
  }) {
    if (photoId == null) return {};
    if (range && rangeAnchorId != null) {
      final a = orderedIds.indexOf(rangeAnchorId);
      final b = orderedIds.indexOf(photoId);
      if (a >= 0 && b >= 0) {
        final lo = a < b ? a : b;
        final hi = a < b ? b : a;
        return {for (var i = lo; i <= hi; i++) orderedIds[i]};
      }
    }
    if (additive) {
      final next = {...current};
      if (next.contains(photoId)) {
        next.remove(photoId);
      } else {
        next.add(photoId);
      }
      return next;
    }
    return {photoId};
  }
}

/// Move a contiguous block of [movingIds] in [ordered] (batch carousel order).
List<T> reorderBatchGroup<T>({
  required List<T> ordered,
  required Set<String> movingIds,
  required String Function(T item) idOf,
  required int dragFromIndex,
  required int hoverIndex,
  required T Function(T item, int order) withOrder,
}) {
  if (ordered.isEmpty) return ordered;
  if (movingIds.isEmpty || movingIds.length == 1) {
    return _reorderSingle(
      ordered: ordered,
      idOf: idOf,
      from: dragFromIndex,
      to: hoverIndex,
      withOrder: withOrder,
    );
  }
  if (dragFromIndex < 0 ||
      dragFromIndex >= ordered.length ||
      !movingIds.contains(idOf(ordered[dragFromIndex]))) {
    return _reorderSingle(
      ordered: ordered,
      idOf: idOf,
      from: dragFromIndex,
      to: hoverIndex,
      withOrder: withOrder,
    );
  }

  final block = [
    for (final item in ordered)
      if (movingIds.contains(idOf(item))) item,
  ];
  final rest = [
    for (final item in ordered)
      if (!movingIds.contains(idOf(item))) item,
  ];

  var insert = 0;
  for (var i = 0; i < hoverIndex && i < ordered.length; i++) {
    if (!movingIds.contains(idOf(ordered[i]))) insert++;
  }
  if (hoverIndex > dragFromIndex) {
    insert = insert.clamp(0, rest.length);
  } else {
    insert = insert.clamp(0, rest.length);
  }

  final next = [...rest];
  next.insertAll(insert, block);
  return [for (var i = 0; i < next.length; i++) withOrder(next[i], i)];
}

List<T> _reorderSingle<T>({
  required List<T> ordered,
  required String Function(T item) idOf,
  required int from,
  required int to,
  required T Function(T item, int order) withOrder,
}) {
  if (from < 0 || from >= ordered.length) return ordered;
  var dest = to;
  if (dest > from) dest -= 1;
  if (dest < 0 || dest >= ordered.length || dest == from) return ordered;
  final next = [...ordered];
  final item = next.removeAt(from);
  next.insert(dest, item);
  return [for (var i = 0; i < next.length; i++) withOrder(next[i], i)];
}
