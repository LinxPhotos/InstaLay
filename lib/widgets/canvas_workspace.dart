import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/instagram_limits.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import 'interactive_tapestry_canvas.dart';
import 'live_canvas.dart';

/// Main canvas area: header + toolbar, then a scrollable list of layout cells
/// (batch and tapestry may coexist in one project).
class CanvasWorkspace extends StatelessWidget {
  const CanvasWorkspace({
    super.key,
    required this.layouts,
    required this.activeLayoutId,
    required this.sourceImages,
    required this.selectedPhotoId,
    required this.loading,
    required this.locked,
    required this.onSelectLayout,
    required this.onSelectPhoto,
    required this.onUpdateLayout,
    required this.onAddLayout,
    required this.onDeleteLayout,
    required this.tapestryControllers,
    this.selectedTextId,
    this.onSelectText,
  });

  final List<LayoutCanvas> layouts;
  final String? activeLayoutId;
  final Map<String, ui.Image> sourceImages;
  final String? selectedPhotoId;
  final String? selectedTextId;
  final bool loading;
  final bool locked;
  final ValueChanged<String> onSelectLayout;
  final ValueChanged<String?> onSelectPhoto;
  final ValueChanged<String?>? onSelectText;
  final void Function(LayoutCanvas layout) onUpdateLayout;
  final VoidCallback onAddLayout;
  final ValueChanged<String> onDeleteLayout;
  final Map<String, TapestryCanvasController> tapestryControllers;

  @override
  Widget build(BuildContext context) {
    final panel = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.elevatedDark
        : const Color(0xFFF0EFEC);

    LayoutCanvas? active;
    for (final layout in layouts) {
      if (layout.id == activeLayoutId) {
        active = layout;
        break;
      }
    }
    active ??= layouts.isEmpty ? null : layouts.first;
    final isTapestry = active?.isTapestry ?? false;
    final activeController =
        active == null ? null : tapestryControllers[active.id];

    return ColoredBox(
      color: panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Canvases',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTapestry
                            ? 'Live tapestry · drag · right-click menu · handles'
                            : 'Live canvas · edits apply instantly',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted(context, 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isTapestry && active != null)
                  _TapestryToolbar(
                    controller: activeController,
                    locked: locked,
                    slideCount: active.slideCount,
                    onAddText: locked
                        ? null
                        : () {
                            final stripW = CanvasLayout.canvasSize(active!.config)
                                    .width *
                                active.slideCount;
                            final stripH =
                                CanvasLayout.canvasSize(active.config).height;
                            final z = TapestryLayerOrder.nextZIndex(
                              active.photos,
                              active.texts,
                            );
                            final id =
                                'text-${DateTime.now().microsecondsSinceEpoch}';
                            final item = TextItem(
                              id: id,
                              text: 'Text',
                              offsetX: stripW * 0.35,
                              offsetY: stripH * 0.35,
                              zIndex: z,
                            );
                            onUpdateLayout(
                              active.copyWith(
                                texts: [...active.texts, item],
                              ),
                            );
                            onSelectText?.call(id);
                            onSelectPhoto(null);
                          },
                    onSlideCountChanged: locked
                        ? null
                        : (n) => onUpdateLayout(
                              active!.copyWith(tapestrySlideCount: n),
                            ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  itemCount: layouts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == layouts.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: OutlinedButton.icon(
                          onPressed: locked ? null : onAddLayout,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add layout'),
                        ),
                      );
                    }
                    final layout = layouts[index];
                    return _LayoutCell(
                      key: ValueKey(layout.id),
                      layout: layout,
                      selected: layout.id == active?.id,
                      sourceImages: sourceImages,
                      selectedPhotoId: selectedPhotoId,
                      selectedTextId: selectedTextId,
                      locked: locked,
                      controller: tapestryControllers.putIfAbsent(
                        layout.id,
                        () => TapestryCanvasController(),
                      ),
                      onSelect: () => onSelectLayout(layout.id),
                      onSelectPhoto: onSelectPhoto,
                      onSelectText: onSelectText,
                      onUpdate: onUpdateLayout,
                      onDelete: layouts.length > 1
                          ? () => onDeleteLayout(layout.id)
                          : null,
                    );
                  },
                ),
                if (loading)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.35),
                      child: const Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TapestryToolbar extends StatelessWidget {
  const _TapestryToolbar({
    required this.controller,
    required this.locked,
    required this.slideCount,
    required this.onSlideCountChanged,
    this.onAddText,
  });

  final TapestryCanvasController? controller;
  final bool locked;
  final int slideCount;
  final ValueChanged<int>? onSlideCountChanged;
  final VoidCallback? onAddText;

  @override
  Widget build(BuildContext context) {
    Widget iconBtn({
      required IconData icon,
      required String tip,
      required VoidCallback? onPressed,
    }) {
      return IconButton(
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        onPressed: locked ? null : onPressed,
        icon: Icon(icon),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconBtn(
          icon: Icons.align_horizontal_left,
          tip: 'Align left',
          onPressed: () => controller?.align(TapestryAlign.left),
        ),
        iconBtn(
          icon: Icons.align_horizontal_center,
          tip: 'Align center',
          onPressed: () => controller?.align(TapestryAlign.centerH),
        ),
        iconBtn(
          icon: Icons.align_horizontal_right,
          tip: 'Align right',
          onPressed: () => controller?.align(TapestryAlign.right),
        ),
        iconBtn(
          icon: Icons.align_vertical_top,
          tip: 'Align top',
          onPressed: () => controller?.align(TapestryAlign.top),
        ),
        iconBtn(
          icon: Icons.align_vertical_center,
          tip: 'Align middle',
          onPressed: () => controller?.align(TapestryAlign.centerV),
        ),
        iconBtn(
          icon: Icons.align_vertical_bottom,
          tip: 'Align bottom',
          onPressed: () => controller?.align(TapestryAlign.bottom),
        ),
        iconBtn(
          icon: Icons.vertical_distribute,
          tip: 'Snap to slide edge',
          onPressed: () => controller?.align(TapestryAlign.snapSlide),
        ),
        const SizedBox(width: 4),
        iconBtn(
          icon: Icons.flip_to_back,
          tip: 'Send to back',
          onPressed: () => controller?.zOrder(TapestryZOrder.sendToBack),
        ),
        iconBtn(
          icon: Icons.keyboard_arrow_down,
          tip: 'Lower [',
          onPressed: () => controller?.zOrder(TapestryZOrder.lower),
        ),
        iconBtn(
          icon: Icons.keyboard_arrow_up,
          tip: 'Raise ]',
          onPressed: () => controller?.zOrder(TapestryZOrder.raise),
        ),
        iconBtn(
          icon: Icons.flip_to_front,
          tip: 'Bring to front',
          onPressed: () => controller?.zOrder(TapestryZOrder.bringToFront),
        ),
        const SizedBox(width: 4),
        iconBtn(
          icon: Icons.rotate_left,
          tip: 'Rotate −15°',
          onPressed: () => controller?.rotate(-15),
        ),
        iconBtn(
          icon: Icons.rotate_right,
          tip: 'Rotate +15°',
          onPressed: () => controller?.rotate(15),
        ),
        const SizedBox(width: 4),
        iconBtn(
          icon: Icons.text_fields,
          tip: 'Add text',
          onPressed: onAddText,
        ),
        const SizedBox(width: 8),
        Text(
          '$slideCount / ${InstagramLimits.maxCarouselSlides}',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.muted(context, 0.55),
          ),
        ),
        IconButton(
          tooltip: 'Fewer slides',
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: locked || slideCount <= InstagramLimits.minCarouselSlides
              ? null
              : () => onSlideCountChanged?.call(slideCount - 1),
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          tooltip: 'More slides',
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: locked || slideCount >= InstagramLimits.maxCarouselSlides
              ? null
              : () => onSlideCountChanged?.call(slideCount + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _LayoutCell extends StatefulWidget {
  const _LayoutCell({
    super.key,
    required this.layout,
    required this.selected,
    required this.sourceImages,
    required this.selectedPhotoId,
    required this.locked,
    required this.controller,
    required this.onSelect,
    required this.onSelectPhoto,
    required this.onUpdate,
    this.selectedTextId,
    this.onSelectText,
    this.onDelete,
  });

  final LayoutCanvas layout;
  final bool selected;
  final Map<String, ui.Image> sourceImages;
  final String? selectedPhotoId;
  final String? selectedTextId;
  final bool locked;
  final TapestryCanvasController controller;
  final VoidCallback onSelect;
  final ValueChanged<String?> onSelectPhoto;
  final ValueChanged<String?>? onSelectText;
  final void Function(LayoutCanvas layout) onUpdate;
  final VoidCallback? onDelete;

  @override
  State<_LayoutCell> createState() => _LayoutCellState();
}

class _LayoutCellState extends State<_LayoutCell> {
  double? _resizeOriginHeight;
  double _resizeAccumDy = 0;

  LayoutCanvas get layout => widget.layout;
  bool get selected => widget.selected;
  bool get locked => widget.locked;

  @override
  Widget build(BuildContext context) {
    final chrome = AppTheme.chrome(context);
    final height = layout.previewHeight.clamp(160.0, 720.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: widget.onSelect,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          layout.name,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          layout.isTapestry ? 'Tapestry' : 'Batch',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted(context, 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (layout.isTapestry)
                Text(
                  '${layout.slideCount} slide${layout.slideCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.muted(context, 0.5),
                  ),
                ),
              if (widget.onDelete != null)
                IconButton(
                  tooltip: 'Remove layout',
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  onPressed: locked ? null : widget.onDelete,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          Container(
            height: height,
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? AppTheme.accent : chrome,
                width: selected ? 2 : 1,
              ),
              color: AppTheme.artboardPasteboard(
                Theme.of(context).brightness,
              ),
            ),
            // Do NOT wrap the interactive tapestry in GestureDetector — a parent
            // TapRecognizer competes with Listener/scroll/drag and can swallow
            // clicks. Layout selection happens via chrome tap + photo/text select.
            child: Padding(
              // Room for soft artboard lift shadows without clipping.
              padding: const EdgeInsets.all(12),
              child: layout.isTapestry
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 44,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onSelect,
                            child: Center(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Text(
                                  '${CanvasLayout.canvasSize(layout.config).height.round()} px',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.muted(context, 0.55),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: _buildPreview(context)),
                      ],
                    )
                  : GestureDetector(
                      onTap: widget.onSelect,
                      child: _buildPreview(context),
                    ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeRow,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: locked
                  ? null
                  : (_) {
                      _resizeOriginHeight = layout.previewHeight;
                      _resizeAccumDy = 0;
                    },
              onVerticalDragUpdate: locked
                  ? null
                  : (d) {
                      final origin =
                          _resizeOriginHeight ?? layout.previewHeight;
                      _resizeAccumDy += d.delta.dy;
                      widget.onUpdate(
                        layout.copyWith(
                          previewHeight:
                              (origin + _resizeAccumDy).clamp(160.0, 720.0),
                        ),
                      );
                    },
              onVerticalDragEnd: locked
                  ? null
                  : (_) {
                      _resizeOriginHeight = null;
                      _resizeAccumDy = 0;
                    },
              onVerticalDragCancel: locked
                  ? null
                  : () {
                      _resizeOriginHeight = null;
                      _resizeAccumDy = 0;
                    },
              child: SizedBox(
                height: 8,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (layout.isTapestry) {
      return InteractiveTapestryCanvas(
        layout: layout,
        images: {
          for (final p in layout.photos)
            if (widget.sourceImages[p.id] != null)
              p.id: widget.sourceImages[p.id]!,
        },
        selectedPhotoId: selected ? widget.selectedPhotoId : null,
        selectedTextId: selected ? widget.selectedTextId : null,
        controller: selected ? widget.controller : null,
        onSelectPhoto: (id) {
          widget.onSelect();
          widget.onSelectPhoto(id);
        },
        onSelectText: (id) {
          widget.onSelect();
          widget.onSelectText?.call(id);
        },
        onPhotosChanged: (photos) =>
            widget.onUpdate(layout.copyWith(photos: photos)),
        onTextsChanged: (texts) =>
            widget.onUpdate(layout.copyWith(texts: texts)),
        onAddText: () {
          widget.onSelect();
          final stripW =
              CanvasLayout.canvasSize(layout.config).width * layout.slideCount;
          final stripH = CanvasLayout.canvasSize(layout.config).height;
          final z = TapestryLayerOrder.nextZIndex(layout.photos, layout.texts);
          final id = 'text-${DateTime.now().microsecondsSinceEpoch}';
          final item = TextItem(
            id: id,
            text: 'Text',
            offsetX: stripW * 0.35,
            offsetY: stripH * 0.35,
            zIndex: z,
          );
          widget.onUpdate(layout.copyWith(texts: [...layout.texts, item]));
          widget.onSelectText?.call(id);
          widget.onSelectPhoto(null);
        },
        onSlideCountChanged: (n) =>
            widget.onUpdate(layout.copyWith(tapestrySlideCount: n)),
        locked: locked,
      );
    }

    PhotoItem? photo;
    for (final p in layout.photos) {
      if (p.id == widget.selectedPhotoId) {
        photo = p;
        break;
      }
    }
    photo ??= layout.photos.isEmpty ? null : layout.photos.first;
    if (photo == null) {
      return Center(
        child: Text(
          'Select a photo',
          style: TextStyle(color: AppTheme.muted(context, 0.4)),
        ),
      );
    }
    return LiveFramedCanvas(
      config: layout.config,
      image: widget.sourceImages[photo.id],
      photo: photo,
      fit: BoxFit.contain,
    );
  }
}
