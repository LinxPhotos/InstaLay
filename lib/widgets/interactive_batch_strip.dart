import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/project.dart';
import '../theme/app_theme.dart';
import 'horizontal_canvas_viewport.dart';
import 'live_canvas.dart';

/// Batch layout cell: framed photos left-to-right with horizontal overflow
/// scroll (scrollbar + wheel). Desktop: click-drag reorders. Touch: long-press
/// then slide to reorder.
class InteractiveBatchStrip extends StatefulWidget {
  const InteractiveBatchStrip({
    super.key,
    required this.layout,
    required this.sourceImages,
    required this.selected,
    required this.selectedPhotoId,
    required this.locked,
    required this.onSelectLayout,
    required this.onSelectPhoto,
    required this.onPhotosChanged,
  });

  final LayoutCanvas layout;
  final Map<String, ui.Image> sourceImages;
  final bool selected;
  final String? selectedPhotoId;
  final bool locked;
  final VoidCallback onSelectLayout;
  final ValueChanged<String?> onSelectPhoto;
  final ValueChanged<List<PhotoItem>> onPhotosChanged;

  static const double gap = 10;

  @override
  State<InteractiveBatchStrip> createState() => _InteractiveBatchStripState();
}

class _InteractiveBatchStripState extends State<InteractiveBatchStrip> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _rowKey = GlobalKey();

  int? _dragFromIndex;
  int? _dragToIndex;
  var _reorderActive = false;

  bool get _mobileHost {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  List<PhotoItem> get _ordered {
    final list = [...widget.layout.photos]
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _frameWidth(double viewportHeight) {
    final logical = CanvasLayout.canvasSize(widget.layout.config);
    final aspect = logical.width / logical.height;
    return viewportHeight * aspect;
  }

  double _stride(double frameW) => frameW + InteractiveBatchStrip.gap;

  int _indexForContentX(double contentX, double frameW, int count) {
    if (count <= 0) return 0;
    final stride = _stride(frameW);
    return (contentX / stride).floor().clamp(0, count - 1);
  }

  void _clearReorder() {
    _dragFromIndex = null;
    _dragToIndex = null;
    _reorderActive = false;
  }

  void _commitReorder(int from, int to) {
    final ordered = _ordered;
    if (from < 0 || from >= ordered.length) return;
    var dest = to;
    if (dest > from) dest -= 1;
    if (dest < 0 || dest >= ordered.length || dest == from) return;

    final next = [...ordered];
    final item = next.removeAt(from);
    next.insert(dest, item);
    widget.onPhotosChanged([
      for (var i = 0; i < next.length; i++) next[i].copyWith(order: i),
    ]);
  }

  void _startReorder(int fromIndex) {
    if (widget.locked) return;
    _reorderActive = true;
    _dragFromIndex = fromIndex;
    _dragToIndex = fromIndex;
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _updateHoverFromGlobal(Offset global, double frameW, int count) {
    final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global);
    final scroll = _scrollController.hasClients ? _scrollController.offset : 0;
    final contentX = scroll + local.dx;
    final hover = _indexForContentX(contentX, frameW, count);
    if (hover != _dragToIndex) {
      setState(() => _dragToIndex = hover);
    }
  }

  void _finishReorder() {
    final wasActive = _reorderActive;
    final from = _dragFromIndex;
    final to = _dragToIndex;
    _clearReorder();
    setState(() {});
    if (wasActive && from != null && to != null) {
      _commitReorder(from, to);
    }
  }

  List<PhotoItem> _displayPhotos(List<PhotoItem> ordered) {
    final from = _dragFromIndex;
    final to = _dragToIndex;
    if (!_reorderActive || from == null || to == null || from == to) {
      return ordered;
    }
    final next = [...ordered];
    final item = next.removeAt(from);
    var insert = to;
    if (insert > from) insert -= 1;
    insert = insert.clamp(0, next.length);
    next.insert(insert, item);
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered;
    if (ordered.isEmpty) {
      return GestureDetector(
        onTap: widget.onSelectLayout,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(
            'Include photos from Sources',
            style: TextStyle(color: AppTheme.muted(context, 0.4)),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final frameW = _frameWidth(h);
        final contentW = ordered.length * frameW +
            (ordered.length - 1) * InteractiveBatchStrip.gap;

        final displayPhotos = _displayPhotos(ordered);

        return HorizontalCanvasViewport(
          controller: _scrollController,
          viewportHeight: h,
          contentWidth: contentW,
          child: Row(
            key: _rowKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var displayIndex = 0;
                  displayIndex < displayPhotos.length;
                  displayIndex++)
                _buildFrame(
                  context,
                  displayPhotos[displayIndex],
                  displayIndex,
                  frameW,
                  h,
                  ordered.length,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFrame(
    BuildContext context,
    PhotoItem photo,
    int displayIndex,
    double frameW,
    double h,
    int count,
  ) {
    final sourceIndex = _ordered.indexWhere((p) => p.id == photo.id);
    final isSelected = widget.selected && widget.selectedPhotoId == photo.id;
    final isDragging = _reorderActive && sourceIndex == _dragFromIndex;

    void select() {
      widget.onSelectLayout();
      widget.onSelectPhoto(photo.id);
    }

    return Padding(
      padding: EdgeInsets.only(
        right: displayIndex < count - 1 ? InteractiveBatchStrip.gap : 0,
      ),
      child: Listener(
        onPointerMove: widget.locked || !_mobileHost || !_reorderActive
            ? null
            : (e) =>
                _updateHoverFromGlobal(e.position, frameW, count),
        onPointerUp: widget.locked || !_mobileHost || !_reorderActive
            ? null
            : (_) => _finishReorder(),
        onPointerCancel: widget.locked || !_mobileHost || !_reorderActive
            ? null
            : (_) => _finishReorder(),
        child: GestureDetector(
          onTap: widget.locked ? null : select,
          onLongPress: widget.locked || !_mobileHost
              ? null
              : () {
                  select();
                  _startReorder(sourceIndex);
                },
          onHorizontalDragStart: widget.locked || _mobileHost
              ? null
              : (_) {
                  select();
                  _startReorder(sourceIndex);
                },
          onHorizontalDragUpdate: widget.locked || !_reorderActive
              ? null
              : (d) =>
                  _updateHoverFromGlobal(d.globalPosition, frameW, count),
          onHorizontalDragEnd: widget.locked || !_reorderActive
              ? null
              : (_) => _finishReorder(),
          onHorizontalDragCancel: widget.locked || !_reorderActive
              ? null
              : _finishReorder,
          child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: isDragging ? 0.55 : 1,
          child: Transform.translate(
            offset: isDragging ? const Offset(0, -6) : Offset.zero,
            child: SizedBox(
              width: frameW,
              height: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                  boxShadow: isDragging
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: LiveFramedCanvas(
                  config: widget.layout.config,
                  image: widget.sourceImages[photo.id],
                  photo: photo,
                  fit: BoxFit.contain,
                  alignment: Alignment.topLeft,
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Reorder helper for tests.
List<PhotoItem> reorderBatchPhotos(
  List<PhotoItem> ordered,
  int from,
  int to,
) {
  if (from < 0 || from >= ordered.length) return ordered;
  var dest = to;
  if (dest > from) dest -= 1;
  if (dest < 0 || dest >= ordered.length || dest == from) return ordered;
  final next = [...ordered];
  final item = next.removeAt(from);
  next.insert(dest, item);
  return [for (var i = 0; i < next.length; i++) next[i].copyWith(order: i)];
}
