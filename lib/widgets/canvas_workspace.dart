import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/canvas_config.dart';
import '../models/instagram_limits.dart';
import '../models/project.dart';
import '../layout/responsive.dart';
import '../theme/app_theme.dart';
import 'export_destination_dialog.dart';
import 'interactive_batch_strip.dart';
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
    required this.onExportLayout,
    required this.tapestryControllers,
    this.selectedTextId,
    this.onSelectText,
    this.exportEnabled = true,
  });

  final List<LayoutCanvas> layouts;
  final String? activeLayoutId;
  final Map<String, ui.Image> sourceImages;
  final String? selectedPhotoId;
  final String? selectedTextId;
  final bool loading;
  final bool locked;
  final bool exportEnabled;
  final ValueChanged<String> onSelectLayout;
  final ValueChanged<String?> onSelectPhoto;
  final ValueChanged<String?>? onSelectText;
  final void Function(LayoutCanvas layout) onUpdateLayout;
  final VoidCallback onAddLayout;
  final ValueChanged<String> onDeleteLayout;
  final ValueChanged<String> onExportLayout;
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
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final wideHeader = isWideWidth(headerConstraints.maxWidth);
                final title = Column(
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
                          : 'Live batch · scroll · drag to reorder',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.muted(context, 0.5),
                      ),
                    ),
                  ],
                );
                final toolbar = (isTapestry && active != null)
                    ? _TapestryToolbar(
                        controller: activeController,
                        locked: locked,
                        slideCount: active.slideCount,
                        compact: !wideHeader,
                        onAddText: locked
                            ? null
                            : () {
                                final stripW =
                                    CanvasLayout.canvasSize(active!.config)
                                            .width *
                                        active.slideCount;
                                final stripH = CanvasLayout.canvasSize(
                                  active.config,
                                ).height;
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
                      )
                    : null;
                if (!wideHeader && toolbar != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: toolbar,
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: title),
                    ?toolbar,
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                      onExport: exportEnabled
                          ? () => onExportLayout(layout.id)
                          : null,
                      onDelete: layouts.length > 1
                          ? () => onDeleteLayout(layout.id)
                          : null,
                      onLayoutModeChanged: (mode) => onUpdateLayout(
                        layout.copyWith(
                          config: layout.config.copyWith(layoutMode: mode),
                        ),
                      ),
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
    this.compact = false,
  });

  final TapestryCanvasController? controller;
  final bool locked;
  final int slideCount;
  final ValueChanged<int>? onSlideCountChanged;
  final VoidCallback? onAddText;
  final bool compact;

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

    final slideControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconBtn(
            icon: Icons.text_fields,
            tip: 'Add text',
            onPressed: onAddText,
          ),
          slideControls,
          PopupMenuButton<String>(
            tooltip: 'Align & arrange',
            enabled: !locked,
            icon: const Icon(Icons.more_horiz, size: 20),
            onSelected: (action) {
              switch (action) {
                case 'alignLeft':
                  controller?.align(TapestryAlign.left);
                case 'alignCenterH':
                  controller?.align(TapestryAlign.centerH);
                case 'alignRight':
                  controller?.align(TapestryAlign.right);
                case 'alignTop':
                  controller?.align(TapestryAlign.top);
                case 'alignCenterV':
                  controller?.align(TapestryAlign.centerV);
                case 'alignBottom':
                  controller?.align(TapestryAlign.bottom);
                case 'snapSlide':
                  controller?.align(TapestryAlign.snapSlide);
                case 'sendBack':
                  controller?.zOrder(TapestryZOrder.sendToBack);
                case 'lower':
                  controller?.zOrder(TapestryZOrder.lower);
                case 'raise':
                  controller?.zOrder(TapestryZOrder.raise);
                case 'bringFront':
                  controller?.zOrder(TapestryZOrder.bringToFront);
                case 'rotateLeft':
                  controller?.rotate(-15);
                case 'rotateRight':
                  controller?.rotate(15);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'alignLeft', child: Text('Align left')),
              PopupMenuItem(value: 'alignCenterH', child: Text('Align center')),
              PopupMenuItem(value: 'alignRight', child: Text('Align right')),
              PopupMenuItem(value: 'alignTop', child: Text('Align top')),
              PopupMenuItem(value: 'alignCenterV', child: Text('Align middle')),
              PopupMenuItem(value: 'alignBottom', child: Text('Align bottom')),
              PopupMenuItem(
                value: 'snapSlide',
                child: Text('Snap to slide edge'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(value: 'sendBack', child: Text('Send to back')),
              PopupMenuItem(value: 'lower', child: Text('Lower')),
              PopupMenuItem(value: 'raise', child: Text('Raise')),
              PopupMenuItem(value: 'bringFront', child: Text('Bring to front')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'rotateLeft', child: Text('Rotate −15°')),
              PopupMenuItem(value: 'rotateRight', child: Text('Rotate +15°')),
            ],
          ),
        ],
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
        slideControls,
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
    this.onExport,
    this.selectedTextId,
    this.onSelectText,
    this.onDelete,
    this.onLayoutModeChanged,
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
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  /// Switches this layout between batch and tapestry. Shown only while the
  /// layout is selected, beside Remove layout.
  final ValueChanged<LayoutMode>? onLayoutModeChanged;

  @override
  State<_LayoutCell> createState() => _LayoutCellState();
}

class _LayoutCellState extends State<_LayoutCell> {
  double? _resizeOriginHeight;
  double _resizeAccumDy = 0;
  var _showInstagramWarnings = false;

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
          _buildHeader(context),
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
                  ? LayoutBuilder(
                      builder: (context, cellConstraints) {
                        final showHeightRail =
                            isWideWidth(cellConstraints.maxWidth);
                        final preview = _buildPreview(context);
                        if (!showHeightRail) return preview;
                        return Row(
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
                            Expanded(child: preview),
                          ],
                        );
                      },
                    )
                  : _buildPreview(context),
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

  Widget _buildHeader(BuildContext context) {
    final onModeChanged = widget.onLayoutModeChanged;
    // Phones get 48px segments; desktop keeps the compact header height.
    final touch = !isWideLayout(context);
    final typeSelector = selected && onModeChanged != null
        ? LayoutTypeSelector(
            mode: layout.config.layoutMode,
            touch: touch,
            onChanged: locked ? null : onModeChanged,
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Inline beside Export and Remove layout when the row has room,
        // otherwise on its own row right under the layout name.
        final inlineSelector = !touch &&
                constraints.maxWidth >= _kInlineLayoutTypeMinWidth
            ? typeSelector
            : null;
        final row = Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.onSelect,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          layout.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                      if (typeSelector == null) ...[
                        const SizedBox(width: 8),
                        Text(
                          layout.isTapestry ? 'Tapestry' : 'Batch',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted(context, 0.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (inlineSelector != null) ...[
              inlineSelector,
              const SizedBox(width: 8),
            ],
            if (layout.isTapestry)
              Text(
                '${layout.slideCount} slide${layout.slideCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted(context, 0.5),
                ),
              )
            else
              Text(
                '${layout.photos.length} / ${InstagramLimits.maxCarouselSlides}',
                style: TextStyle(
                  fontSize: 11,
                  color: layout.photos.length >
                          InstagramLimits.maxCarouselSlides
                      ? AppTheme.warn
                      : AppTheme.muted(context, 0.5),
                ),
              ),
            if (InstagramLimits.layoutExceedsCarouselLimit(layout))
              IconButton(
                tooltip: _showInstagramWarnings
                    ? InstagramLimits.hideInstagramWarningsTooltip
                    : InstagramLimits.showInstagramWarningsTooltip,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(
                  () => _showInstagramWarnings = !_showInstagramWarnings,
                ),
                icon: Icon(
                  Icons.warning_amber_rounded,
                  color: _showInstagramWarnings
                      ? AppTheme.warn
                      : AppTheme.muted(context, 0.45),
                ),
              ),
            IconButton(
              tooltip: 'Export this layout',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: widget.onExport,
              icon: Icon(
                exportPrefersSaveFirst
                    ? Icons.save_alt_outlined
                    : Icons.ios_share_outlined,
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
        );
        if (typeSelector == null || inlineSelector != null) return row;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: typeSelector,
              ),
            ),
          ],
        );
      },
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
        onPhotosChanged: (photos, {config}) => widget.onUpdate(
              layout.copyWith(
                photos: photos,
                config: config ?? layout.config,
              ),
            ),
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
        showInstagramWarnings: _showInstagramWarnings,
      );
    }

    return InteractiveBatchStrip(
      layout: layout,
      sourceImages: widget.sourceImages,
      selected: selected,
      selectedPhotoId: widget.selectedPhotoId,
      locked: locked,
      onSelectLayout: widget.onSelect,
      onSelectPhoto: widget.onSelectPhoto,
      onPhotosChanged: (photos) => widget.onUpdate(
        layout.copyWith(photos: photos),
      ),
      showInstagramWarnings: _showInstagramWarnings,
    );
  }
}

/// Header width at which the layout type switch fits inline with the layout
/// name, slide count, Export, and Remove layout.
const double _kInlineLayoutTypeMinWidth = 480;

/// Batch / Tapestry switch for the selected layout. Sits with Add layout and
/// Remove layout in the canvas workspace so a layout is changed where it is
/// managed.
class LayoutTypeSelector extends StatelessWidget {
  const LayoutTypeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
    this.touch = false,
  });

  final LayoutMode mode;

  /// Null disables the switch (frozen version).
  final ValueChanged<LayoutMode>? onChanged;

  /// 48px segments for phones; compact otherwise.
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return SegmentedButton<LayoutMode>(
      style: touch
          ? const ButtonStyle(
              visualDensity: VisualDensity.standard,
              minimumSize: WidgetStatePropertyAll(Size(48, 48)),
              tapTargetSize: MaterialTapTargetSize.padded,
            )
          : const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
      segments: const [
        ButtonSegment(
          value: LayoutMode.batch,
          label: Text('Batch'),
          icon: Icon(Icons.grid_view_outlined, size: 16),
        ),
        ButtonSegment(
          value: LayoutMode.tapestry,
          label: Text('Tapestry'),
          icon: Icon(Icons.view_carousel_outlined, size: 16),
        ),
      ],
      selected: {mode},
      onSelectionChanged:
          onChanged == null ? null : (s) => onChanged(s.first),
    );
  }
}