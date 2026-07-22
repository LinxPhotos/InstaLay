import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/canvas_config.dart';
import '../models/instagram_limits.dart';
import '../models/project.dart';
import '../services/text_rasterizer.dart';
import '../theme/app_theme.dart';
import 'live_canvas.dart';

/// Snap / align actions for the selected tapestry photo.
enum TapestryAlign {
  left,
  centerH,
  right,
  top,
  centerV,
  bottom,
  snapSlide,
}

/// Stacking-order actions for the selected tapestry photo.
enum TapestryZOrder {
  raise,
  lower,
  bringToFront,
  sendToBack,
}

enum _DragMode { none, move, resize, rotate }

enum _HandleMode { none, crop, rotate }

enum _ResizeEdge {
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Controller so the workspace toolbar can drive the interactive canvas.
class TapestryCanvasController {
  void Function(TapestryAlign align)? _align;
  void Function(double deg)? _rotate;
  void Function(TapestryZOrder action)? _zOrder;
  VoidCallback? _addText;

  void attach({
    required void Function(TapestryAlign align) align,
    required void Function(double deg) rotate,
    required void Function(TapestryZOrder action) zOrder,
    VoidCallback? addText,
  }) {
    _align = align;
    _rotate = rotate;
    _zOrder = zOrder;
    _addText = addText;
  }

  void detach() {
    _align = null;
    _rotate = null;
    _zOrder = null;
    _addText = null;
  }

  void align(TapestryAlign a) => _align?.call(a);
  void rotate(double deg) => _rotate?.call(deg);
  void zOrder(TapestryZOrder a) => _zOrder?.call(a);
  void addText() => _addText?.call();
}

/// Interactive tapestry strip: move / edge-resize / crop / rotate-handle mode
/// for photos and text, resize slide count via the right edge, fade division
/// lines on hover. Right-click opens a context menu. Middle-click toggles crop
/// handles (orange); Rotate menu enters rotate handles (purple).
class InteractiveTapestryCanvas extends StatefulWidget {
  const InteractiveTapestryCanvas({
    super.key,
    required this.layout,
    required this.images,
    required this.selectedPhotoId,
    required this.onSelectPhoto,
    required this.onPhotosChanged,
    required this.onSlideCountChanged,
    this.selectedTextId,
    this.onSelectText,
    this.onTextsChanged,
    this.onAddText,
    this.controller,
    this.locked = false,
  });

  final LayoutCanvas layout;
  final Map<String, ui.Image> images;
  final String? selectedPhotoId;
  final ValueChanged<String?> onSelectPhoto;
  final ValueChanged<List<PhotoItem>> onPhotosChanged;
  final ValueChanged<int> onSlideCountChanged;
  final String? selectedTextId;
  final ValueChanged<String?>? onSelectText;
  final ValueChanged<List<TextItem>>? onTextsChanged;
  final VoidCallback? onAddText;
  final TapestryCanvasController? controller;
  final bool locked;

  @override
  State<InteractiveTapestryCanvas> createState() =>
      _InteractiveTapestryCanvasState();
}

class _InteractiveTapestryCanvasState extends State<InteractiveTapestryCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _divisionsFade;
  final FocusNode _focusNode = FocusNode(debugLabel: 'tapestryCanvas');

  bool _draggingCanvasEdge = false;
  int _edgeDragStartSlides = 1;
  double _edgeDragDx = 0;
  /// Pending slide delta while dragging the canvas edge (−N…+N), 0 if under 50%.
  int _edgeDragPending = 0;

  _DragMode _dragMode = _DragMode.none;
  _ResizeEdge? _resizeEdge;
  String? _draggingPhotoId;
  String? _draggingTextId;
  Offset? _dragStartLocal;
  PhotoItem? _dragStartPhoto;
  TextItem? _dragStartText;
  Rect? _dragStartRect;
  double _rotateStartAngle = 0;
  double _rotateStartDeg = 0;
  int? _activePointer;
  double _viewScale = 1;
  /// Manual double-tap tracking (avoids GestureDetector arena fights).
  DateTime? _lastPrimaryTapAt;
  Offset? _lastPrimaryTapLocal;
  MouseCursor _hoverCursor = SystemMouseCursors.basic;
  /// Crop / rotate handle mode for the current selection.
  _HandleMode _handleMode = _HandleMode.none;
  /// Working photo/text lists while a pointer gesture is active. Parent is
  /// updated once on pointer-up so EditorScreen does not rebuild every move.
  final ValueNotifier<List<PhotoItem>?> _draftPhotos = ValueNotifier(null);
  final ValueNotifier<List<TextItem>?> _draftTexts = ValueNotifier(null);

  static const double _edgeHitPx = 12;
  static const double _minOverlap = 40;
  static const double _minCropDestPx = 24;
  static const double _scaleStep = 1.05;

  bool get _cropHandles =>
      _handleMode == _HandleMode.crop && widget.selectedPhotoId != null;

  bool get _rotateHandles =>
      _handleMode == _HandleMode.rotate &&
      (widget.selectedPhotoId != null || widget.selectedTextId != null);

  String? get _selectedId => widget.selectedPhotoId ?? widget.selectedTextId;

  @override
  void initState() {
    super.initState();
    _divisionsFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    widget.controller?.attach(
      align: applyAlign,
      rotate: applyRotate,
      zOrder: applyZOrder,
      addText: _defaultAddText,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _clampAllOffCanvas());
  }

  @override
  void didUpdateWidget(covariant InteractiveTapestryCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(
        align: applyAlign,
        rotate: applyRotate,
        zOrder: applyZOrder,
        addText: _defaultAddText,
      );
    }
    if ((widget.selectedPhotoId != null &&
            widget.selectedPhotoId != oldWidget.selectedPhotoId) ||
        (widget.selectedTextId != null &&
            widget.selectedTextId != oldWidget.selectedTextId)) {
      _focusNode.requestFocus();
    }
    if (_selectedId == null) {
      _handleMode = _HandleMode.none;
    } else if (widget.selectedPhotoId != oldWidget.selectedPhotoId ||
        widget.selectedTextId != oldWidget.selectedTextId) {
      // Leaving crop when selection changes; rotate stays only if same kind.
      if (_handleMode == _HandleMode.crop && widget.selectedPhotoId == null) {
        _handleMode = _HandleMode.none;
      }
    }
    if (_isDragging) return;
    // Drop local drafts once the parent has absorbed the commit.
    if (_draftPhotos.value != null &&
        oldWidget.layout.photos != widget.layout.photos) {
      _draftPhotos.value = null;
    }
    if (_draftTexts.value != null &&
        oldWidget.layout.texts != widget.layout.texts) {
      _draftTexts.value = null;
    }
    if (oldWidget.layout.photos != widget.layout.photos ||
        oldWidget.layout.tapestrySlideCount != widget.layout.tapestrySlideCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDragging) _clampAllOffCanvas();
      });
    }
  }

  bool get _isDragging =>
      _activePointer != null || _dragMode != _DragMode.none;

  @override
  void dispose() {
    widget.controller?.detach();
    _draftPhotos.dispose();
    _draftTexts.dispose();
    _divisionsFade.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _beginPhotoDraft() {
    _draftPhotos.value ??= List<PhotoItem>.from(widget.layout.photos);
  }

  void _beginTextDraft() {
    _draftTexts.value ??= List<TextItem>.from(widget.layout.texts);
  }

  List<PhotoItem> get _livePhotos =>
      _draftPhotos.value ?? widget.layout.photos;

  List<TextItem> get _liveTexts =>
      _draftTexts.value ?? widget.layout.texts;

  void _showDivisions() => _divisionsFade.forward();
  void _hideDivisions() {
    if (!_draggingCanvasEdge && _dragMode == _DragMode.none) {
      _divisionsFade.reverse();
    }
  }

  CanvasConfig get _config => widget.layout.config;
  int get _slides => widget.layout.slideCount;

  Size get _frameLogical => CanvasLayout.canvasSize(_config);

  Size get _stripLogical => Size(
        _frameLogical.width * _slides,
        _frameLogical.height,
      );

  double get _frameViewWidth => _frameLogical.width * _viewScale;

  /// Fractional slides dragged from the edge handle start.
  double get _edgeDragFraction =>
      _frameViewWidth <= 0 ? 0 : _edgeDragDx / _frameViewWidth;

  /// Pending ±slides while dragging (0 until the 50% mark of a slide width).
  int _pendingSlideDelta() {
    if (!_draggingCanvasEdge) return 0;
    final raw = _edgeDragFraction.round(); // ±0.5 crosses to next integer
    final next = InstagramLimits.clampSlideCount(_edgeDragStartSlides + raw);
    return next - _edgeDragStartSlides;
  }

  List<PhotoItem> get _ordered {
    final list = [..._livePhotos]
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  ({List<PhotoItem> photos, List<ui.Image> images}) _paired() {
    final images = <ui.Image>[];
    final photos = <PhotoItem>[];
    for (final photo in _ordered) {
      final image = widget.images[photo.id];
      if (image == null) continue;
      images.add(image);
      photos.add(photo);
    }
    return (photos: photos, images: images);
  }

  @override
  Widget build(BuildContext context) {
    final paired = _paired();
    final photos = paired.photos;
    final images = paired.images;
    final texts = _liveTexts;

    if (images.isEmpty && texts.isEmpty) {
      return Center(
        child: Text(
          'Add photos or text to the tapestry',
          style: TextStyle(color: AppTheme.muted(context, 0.4)),
        ),
      );
    }

    // Block directional-focus shortcuts so arrow keys move photos when focused.
    const arrowBlockers = <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowLeft):
          DoNothingAndStopPropagationIntent(),
      SingleActivator(LogicalKeyboardKey.arrowRight):
          DoNothingAndStopPropagationIntent(),
      SingleActivator(LogicalKeyboardKey.arrowUp):
          DoNothingAndStopPropagationIntent(),
      SingleActivator(LogicalKeyboardKey.arrowDown):
          DoNothingAndStopPropagationIntent(),
      SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
          DoNothingAndStopPropagationIntent(),
      SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
          DoNothingAndStopPropagationIntent(),
      SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
          DoNothingAndStopPropagationIntent(),
      SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
          DoNothingAndStopPropagationIntent(),
    };

    return Shortcuts(
      shortcuts: arrowBlockers,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKeyEvent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fitH =
                constraints.maxHeight / math.max(1.0, _stripLogical.height);
            final displayH = constraints.maxHeight;
            final frameViewW = _frameLogical.width * fitH;
            final displayW = frameViewW * _slides;
            _viewScale = fitH;

            final pending = _draggingCanvasEdge ? _edgeDragPending : 0;
            final liveEdge = displayW + (_draggingCanvasEdge ? _edgeDragDx : 0);
            const addBtnSlot = 44.0;
            final stackW = math.max(displayW, liveEdge) +
                16 +
                (widget.locked ? 0 : addBtnSlot);
            final addGhostW = math.max(0.0, liveEdge - displayW);
            final canAdd = !widget.locked &&
                _slides < InstagramLimits.maxCarouselSlides;
            final unoccupied = widget.locked
                ? const <int>[]
                : [
                    for (var i = 0; i < _slides; i++)
                      if (!_slideOccupied(i, photos, images)) i,
                  ];

            return MouseRegion(
              onEnter: (_) => _showDivisions(),
              onExit: (_) => _hideDivisions(),
              onHover: (_) => _showDivisions(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(stackW, constraints.maxWidth),
                  height: displayH,
                  child: Stack(
                    // Allow soft artboard lift to breathe past the strip bounds.
                    clipBehavior: Clip.none,
                    children: [
                      // Decorative lift/rim only — never participates in hits.
                      Positioned(
                        left: 0,
                        top: 0,
                        width: displayW,
                        height: displayH,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              boxShadow: AppTheme.artboardLift(
                                Theme.of(context).brightness,
                                _config.swatch.color,
                              ),
                              border: Border.fromBorderSide(
                                AppTheme.artboardRim(
                                  Theme.of(context).brightness,
                                  _config.swatch.color,
                                ),
                              ),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      // Interactive strip: Listener owns hit-testing (opaque).
                      Positioned(
                        left: 0,
                        top: 0,
                        width: displayW,
                        height: displayH,
                        child: MouseRegion(
                          opaque: true,
                          cursor: _hoverCursor,
                          onHover: widget.locked
                              ? null
                              : (e) {
                                  if (_isDragging) return;
                                  _updateHoverCursor(
                                    e.localPosition,
                                    photos,
                                    images,
                                    texts,
                                  );
                                },
                          onExit: (_) {
                            if (_hoverCursor != SystemMouseCursors.basic) {
                              setState(
                                () =>
                                    _hoverCursor = SystemMouseCursors.basic,
                              );
                            }
                          },
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: widget.locked
                                ? null
                                : (e) => _pointerDown(
                                      e,
                                      photos,
                                      images,
                                      texts,
                                    ),
                            onPointerMove:
                                widget.locked ? null : _pointerMove,
                            onPointerUp: widget.locked ? null : _pointerUp,
                            onPointerCancel:
                                widget.locked ? null : _pointerUp,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Paint-only; hits go to the opaque Listener.
                                IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: Listenable.merge([
                                      _divisionsFade,
                                      _draftPhotos,
                                      _draftTexts,
                                    ]),
                                    builder: (context, _) {
                                      final livePaired = _paired();
                                      final liveTexts = _liveTexts;
                                      final dragging = _isDragging ||
                                          _draftPhotos.value != null ||
                                          _draftTexts.value != null;
                                      return RepaintBoundary(
                                        child: CustomPaint(
                                          painter: _InteractiveStripPainter(
                                            config: _config,
                                            images: livePaired.images,
                                            photos: livePaired.photos,
                                            texts: liveTexts,
                                            slideCount: _slides,
                                            selectedPhotoId:
                                                widget.selectedPhotoId,
                                            selectedTextId:
                                                widget.selectedTextId,
                                            divisionsOpacity:
                                                _divisionsFade.value,
                                            pendingSlideDelta: pending,
                                            handleMode: _handleMode,
                                            fast: dragging,
                                          ),
                                          child: const SizedBox.expand(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Transparent hit target (guarantees size).
                                const ColoredBox(color: Color(0x00000000)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // − on empty slides — button-sized hit target only.
                      for (final slideIndex in unoccupied)
                        Positioned(
                          left: slideIndex * frameViewW +
                              (frameViewW - 32) / 2,
                          top: (displayH - 32) / 2,
                          width: 32,
                          height: 32,
                          child: _SlideChromeButton(
                            icon: Icons.remove,
                            tooltip: 'Remove empty slide',
                            onPressed: _slides <=
                                    InstagramLimits.minCarouselSlides
                                ? null
                                : () => _removeSlideAt(slideIndex),
                          ),
                        ),
                      if (addGhostW > 0.5)
                        Positioned(
                          left: displayW,
                          top: 0,
                          width: addGhostW,
                          height: displayH,
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _AddSlideGhostPainter(
                                committed: pending > 0,
                                frameViewWidth: frameViewW,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      // + after the last slide — button-sized hit target.
                      if (canAdd)
                        Positioned(
                          left: displayW + 4 + (addBtnSlot - 4 - 32) / 2,
                          top: (displayH - 32) / 2,
                          width: 32,
                          height: 32,
                          child: _SlideChromeButton(
                            icon: Icons.add,
                            tooltip: 'Add slide',
                            onPressed: () => widget.onSlideCountChanged(
                              InstagramLimits.clampSlideCount(_slides + 1),
                            ),
                          ),
                        ),
                      if (!widget.locked)
                        Positioned(
                          left: liveEdge - 8,
                          top: 0,
                          width: 16,
                          height: displayH,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeColumn,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragStart: (_) {
                                setState(() {
                                  _draggingCanvasEdge = true;
                                  _edgeDragStartSlides = _slides;
                                  _edgeDragDx = 0;
                                  _edgeDragPending = 0;
                                });
                                _showDivisions();
                              },
                              onHorizontalDragUpdate: (d) {
                                setState(() {
                                  _edgeDragDx += d.delta.dx;
                                  _edgeDragPending = _pendingSlideDelta();
                                });
                              },
                              onHorizontalDragEnd: (_) {
                                final next = InstagramLimits.clampSlideCount(
                                  _edgeDragStartSlides + _edgeDragPending,
                                );
                                setState(() {
                                  _draggingCanvasEdge = false;
                                  _edgeDragDx = 0;
                                  _edgeDragPending = 0;
                                });
                                if (next != widget.layout.slideCount) {
                                  widget.onSlideCountChanged(next);
                                }
                                _hideDivisions();
                              },
                              onHorizontalDragCancel: () {
                                setState(() {
                                  _draggingCanvasEdge = false;
                                  _edgeDragDx = 0;
                                  _edgeDragPending = 0;
                                });
                                _hideDivisions();
                              },
                              child: Center(
                                child: Container(
                                  width: 3,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// True when any photo meaningfully overlaps slide [index].
  bool _slideOccupied(
    int index,
    List<PhotoItem> photos,
    List<ui.Image> images,
  ) {
    final frameW = _frameLogical.width;
    final slideRect = Rect.fromLTWH(
      index * frameW,
      0,
      frameW,
      _frameLogical.height,
    );
    const minArea = 64.0; // logical px²
    for (var i = 0; i < photos.length; i++) {
      final placed = _ensurePlaced(photos[i]);
      final rect = _rectFor(placed, images[i]);
      if (!rect.overlaps(slideRect)) continue;
      final inter = rect.intersect(slideRect);
      if (inter.width * inter.height >= minArea) return true;
    }
    return false;
  }

  /// Remove slide [index], shifting content to the right left by one frame.
  void _removeSlideAt(int index) {
    if (widget.locked || _slides <= InstagramLimits.minCarouselSlides) return;
    if (index < 0 || index >= _slides) return;

    final frameW = _frameLogical.width;
    final cutRight = (index + 1) * frameW;
    final out = <PhotoItem>[];
    for (final p in _ordered) {
      final image = widget.images[p.id];
      if (image == null) {
        out.add(p);
        continue;
      }
      final placed = _ensurePlaced(p);
      if (placed.offsetX >= cutRight - 0.5) {
        out.add(
          _clampPhoto(
            placed.copyWith(offsetX: placed.offsetX - frameW),
            image,
          ),
        );
      } else {
        out.add(placed);
      }
    }
    widget.onPhotosChanged(out);
    widget.onSlideCountChanged(
      InstagramLimits.clampSlideCount(_slides - 1),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.locked) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _handleMode != _HandleMode.none) {
      setState(() => _handleMode = _HandleMode.none);
      return KeyEventResult.handled;
    }

    // Ignore photo shortcuts while typing in a TextField.
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.context != null) {
      if (primary.context!.widget is EditableText) {
        return KeyEventResult.ignored;
      }
    }

    final photoId = widget.selectedPhotoId;
    final textId = widget.selectedTextId;
    final selectedId = photoId ?? textId;
    if (selectedId == null) return KeyEventResult.ignored;

    final mods = HardwareKeyboard.instance;
    if (mods.isControlPressed || mods.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.bracketRight ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      applyZOrder(TapestryZOrder.raise);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.bracketLeft ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      applyZOrder(TapestryZOrder.lower);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      applyZOrder(TapestryZOrder.bringToFront);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      applyZOrder(TapestryZOrder.sendToBack);
      return KeyEventResult.handled;
    }

    final isPlus = event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.add ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd;
    final isMinus = event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract;
    if (isPlus || isMinus) {
      final factor = isPlus ? _scaleStep : 1 / _scaleStep;
      _scaleSelected(factor);
      return KeyEventResult.handled;
    }

    if (photoId != null) {
      final photo = _findPhoto(photoId);
      if (photo == null) return KeyEventResult.ignored;
      final image = widget.images[photoId];
      if (image == null) return KeyEventResult.ignored;

      final step = mods.isShiftPressed ? 10.0 : 1.0;
      var dx = 0.0;
      var dy = 0.0;
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) dx = -step;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) dx = step;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) dy = -step;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) dy = step;
      if (dx == 0 && dy == 0) return KeyEventResult.ignored;

      final placed = _ensurePlaced(photo);
      final next = _clampPhoto(
        placed.copyWith(
          offsetX: placed.offsetX + dx,
          offsetY: placed.offsetY + dy,
        ),
        image,
      );
      _emitPhotos(photoId, next);
      return KeyEventResult.handled;
    }

    if (textId != null) {
      final text = _findText(textId);
      if (text == null) return KeyEventResult.ignored;
      final step = mods.isShiftPressed ? 10.0 : 1.0;
      var dx = 0.0;
      var dy = 0.0;
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) dx = -step;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) dx = step;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) dy = -step;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) dy = step;
      if (dx == 0 && dy == 0) return KeyEventResult.ignored;
      _emitTexts(
        textId,
        _clampText(
          text.copyWith(
            offsetX: text.offsetX + dx,
            offsetY: text.offsetY + dy,
          ),
        ),
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _scaleSelected(double factor) {
    final photoId = widget.selectedPhotoId;
    if (photoId != null) {
      final photo = _findPhoto(photoId);
      final image = widget.images[photoId];
      if (photo == null || image == null) return;
      final placed = _ensurePlaced(photo);
      final next = _clampPhoto(
        placed.copyWith(scale: (placed.scale * factor).clamp(0.05, 12.0)),
        image,
      );
      _emitPhotos(photoId, next);
      return;
    }
    final textId = widget.selectedTextId;
    if (textId != null) {
      final text = _findText(textId);
      if (text == null) return;
      _emitTexts(
        textId,
        _clampText(
          text.copyWith(scale: (text.scale * factor).clamp(0.05, 12.0)),
        ),
      );
    }
  }

  void _pointerDown(
    PointerDownEvent e,
    List<PhotoItem> photos,
    List<ui.Image> images,
    List<TextItem> texts,
  ) {
    if (_activePointer != null) return;
    final local = e.localPosition;
    final secondary = e.buttons & kSecondaryMouseButton != 0;
    final middle = e.buttons & kMiddleMouseButton != 0;

    // Always reclaim keyboard focus when the strip is clicked.
    _focusNode.requestFocus();

    // Middle-click toggles crop ↔ resize handles on the hit (or selected) photo.
    if (middle) {
      final hit = _hitTestAny(local, photos, images, texts);
      final id = hit?.photoId ?? widget.selectedPhotoId;
      if (id == null) return;
      _selectPhoto(id);
      setState(() {
        _handleMode =
            _handleMode == _HandleMode.crop ? _HandleMode.none : _HandleMode.crop;
      });
      return;
    }

    // Right-click: context menu (never freehand rotate).
    if (secondary) {
      final hit = _hitTestAny(local, photos, images, texts);
      if (hit?.photoId != null) {
        _selectPhoto(hit!.photoId);
      } else if (hit?.textId != null) {
        _selectText(hit!.textId);
      }
      _showContextMenu(e, hit);
      return;
    }

    // Double primary-click → properties dialog (no GestureDetector arena).
    final now = DateTime.now();
    final lastAt = _lastPrimaryTapAt;
    final lastLocal = _lastPrimaryTapLocal;
    if (lastAt != null &&
        lastLocal != null &&
        now.difference(lastAt) < const Duration(milliseconds: 350) &&
        (local - lastLocal).distance < 12) {
      _lastPrimaryTapAt = null;
      _lastPrimaryTapLocal = null;
      _onDoubleTap(local, photos, images, texts);
      return;
    }
    _lastPrimaryTapAt = now;
    _lastPrimaryTapLocal = local;

    // Edge / corner resize or crop / rotate-handle on primary against selection.
    if (widget.selectedPhotoId != null) {
      final edge = _hitResizeEdge(
        local,
        widget.selectedPhotoId!,
        photos,
        images,
        isText: false,
      );
      if (edge != null) {
        final live =
            _findPhoto(widget.selectedPhotoId!) ??
            photos.firstWhere((p) => p.id == widget.selectedPhotoId);
        final placed = _ensurePlaced(live);
        final rect = _rectFor(placed, widget.images[placed.id]!);
        _clearDragState();
        _activePointer = e.pointer;
        if (_rotateHandles) {
          _dragMode = _DragMode.rotate;
          _draggingPhotoId = placed.id;
          _dragStartLocal = local;
          _dragStartPhoto = placed;
          _dragStartRect = rect;
          final center = rect.center;
          final logical = _toLogical(local);
          _rotateStartAngle = math.atan2(
            logical.dy - center.dy,
            logical.dx - center.dx,
          );
          _rotateStartDeg = placed.rotationDeg;
          setState(() => _hoverCursor = SystemMouseCursors.precise);
        } else {
          _dragMode = _DragMode.resize;
          _resizeEdge = edge;
          _draggingPhotoId = placed.id;
          _dragStartLocal = local;
          _dragStartPhoto = placed;
          _dragStartRect = rect;
          setState(() => _hoverCursor = _cursorForEdge(edge));
        }
        _focusNode.requestFocus();
        _showDivisions();
        return;
      }
    }

    if (widget.selectedTextId != null) {
      final edge = _hitTextResizeEdge(local, widget.selectedTextId!, texts);
      if (edge != null) {
        final text = _findText(widget.selectedTextId!)!;
        final rect = _textRect(text);
        _clearDragState();
        _activePointer = e.pointer;
        _draggingTextId = text.id;
        _dragStartLocal = local;
        _dragStartText = text;
        _dragStartRect = rect;
        if (_rotateHandles) {
          _dragMode = _DragMode.rotate;
          final center = rect.center;
          final logical = _toLogical(local);
          _rotateStartAngle = math.atan2(
            logical.dy - center.dy,
            logical.dx - center.dx,
          );
          _rotateStartDeg = text.rotationDeg;
          setState(() => _hoverCursor = SystemMouseCursors.precise);
        } else {
          _dragMode = _DragMode.resize;
          _resizeEdge = edge;
          setState(() => _hoverCursor = _cursorForEdge(edge));
        }
        _focusNode.requestFocus();
        _showDivisions();
        return;
      }
    }

    final hit = _hitTestAny(local, photos, images, texts);
    if (hit == null) {
      _selectPhoto(null);
      _selectText(null);
      setState(() {
        _hoverCursor = SystemMouseCursors.basic;
        _handleMode = _HandleMode.none;
      });
      return;
    }

    if (hit.photoId != null) {
      final id = hit.photoId!;
      final live = _findPhoto(id) ?? photos.firstWhere((p) => p.id == id);
      final placed = _ensurePlaced(live);
      if (id != widget.selectedPhotoId) {
        _handleMode = _HandleMode.none;
      }
      _selectPhoto(id);
      _clearDragState();
      _activePointer = e.pointer;
      _draggingPhotoId = id;
      _dragStartLocal = local;
      _dragStartPhoto = placed;
      _dragStartRect = _rectFor(placed, widget.images[id]!);
      _dragMode = _DragMode.move;
      _showDivisions();
      setState(() => _hoverCursor = SystemMouseCursors.grabbing);
      return;
    }

    final id = hit.textId!;
    final text = _findText(id)!;
    if (id != widget.selectedTextId) {
      _handleMode = _HandleMode.none;
    }
    _selectText(id);
    _clearDragState();
    _activePointer = e.pointer;
    _draggingTextId = id;
    _dragStartLocal = local;
    _dragStartText = text;
    _dragStartRect = _textRect(text);
    _dragMode = _DragMode.move;
    _showDivisions();
    setState(() => _hoverCursor = SystemMouseCursors.grabbing);
  }

  void _pointerMove(PointerMoveEvent e) {
    if (e.pointer != _activePointer) return;
    final start = _dragStartLocal;
    final startRect = _dragStartRect;
    if (start == null || startRect == null) return;

    final logical = _toLogical(e.localPosition);
    final startLogical = _toLogical(start);

    final photoId = _draggingPhotoId;
    final textId = _draggingTextId;

    if (photoId != null) {
      final photo = _dragStartPhoto;
      final image = widget.images[photoId];
      if (photo == null || image == null) return;
      switch (_dragMode) {
        case _DragMode.move:
          final dx = logical.dx - startLogical.dx;
          final dy = logical.dy - startLogical.dy;
          final next = _clampPhoto(
            photo.copyWith(
              offsetX: photo.offsetX + dx,
              offsetY: photo.offsetY + dy,
            ),
            image,
          );
          _emitPhotos(photoId, next);
        case _DragMode.resize:
          if (_cropHandles) {
            _applyCrop(logical, photo, image, startRect);
          } else {
            _applyResize(logical, photo, image, startRect);
          }
        case _DragMode.rotate:
          final center = startRect.center;
          final angle =
              math.atan2(logical.dy - center.dy, logical.dx - center.dx);
          final deltaDeg = (angle - _rotateStartAngle) * 180 / math.pi;
          final next = _clampPhoto(
            photo.copyWith(rotationDeg: _rotateStartDeg + deltaDeg),
            image,
          );
          _emitPhotos(photoId, next);
        case _DragMode.none:
          break;
      }
      return;
    }

    if (textId != null) {
      final text = _dragStartText;
      if (text == null) return;
      switch (_dragMode) {
        case _DragMode.move:
          final dx = logical.dx - startLogical.dx;
          final dy = logical.dy - startLogical.dy;
          _emitTexts(
            textId,
            _clampText(
              text.copyWith(
                offsetX: text.offsetX + dx,
                offsetY: text.offsetY + dy,
              ),
            ),
          );
        case _DragMode.resize:
          _applyTextResize(logical, text, startRect);
        case _DragMode.rotate:
          final center = startRect.center;
          final angle =
              math.atan2(logical.dy - center.dy, logical.dx - center.dx);
          final deltaDeg = (angle - _rotateStartAngle) * 180 / math.pi;
          _emitTexts(
            textId,
            _clampText(
              text.copyWith(rotationDeg: _rotateStartDeg + deltaDeg),
            ),
          );
        case _DragMode.none:
          break;
      }
    }
  }

  void _pointerUp(PointerEvent e) {
    if (e.pointer != _activePointer) return;
    final draftPhotos = _draftPhotos.value;
    final draftTexts = _draftTexts.value;
    setState(_clearDragState);
    // Commit once at gesture end (keep drafts until parent feeds them back).
    if (draftPhotos != null) {
      widget.onPhotosChanged(draftPhotos);
    }
    if (draftTexts != null) {
      widget.onTextsChanged?.call(draftTexts);
    }
    _hideDivisions();
    final paired = _paired();
    _updateHoverCursor(
      e.localPosition,
      paired.photos,
      paired.images,
      _liveTexts,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDragging) _clampAllOffCanvas();
    });
  }

  void _clearDragState() {
    _activePointer = null;
    _dragMode = _DragMode.none;
    _resizeEdge = null;
    _draggingPhotoId = null;
    _draggingTextId = null;
    _dragStartLocal = null;
    _dragStartPhoto = null;
    _dragStartText = null;
    _dragStartRect = null;
    _rotateStartAngle = 0;
    _rotateStartDeg = 0;
  }

  void _applyResize(
    Offset logical,
    PhotoItem photo,
    ui.Image image,
    Rect startRect,
  ) {
    final edge = _resizeEdge;
    if (edge == null) return;
    final border = CanvasLayout.borderPx(_config);
    final innerH = math.max(1.0, _frameLogical.height - 2 * border);
    final base = CanvasLayout.tapestryBaseSize(
      Size(image.width.toDouble(), image.height.toDouble()),
      innerH,
      photo: photo,
      tileAspect: _config.tapestryTileAspect,
    );

    double newScale = photo.scale;
    double newX = photo.offsetX;
    double newY = photo.offsetY;

    switch (edge) {
      case _ResizeEdge.right:
        final newW = math.max(8.0, logical.dx - startRect.left);
        newScale = (newW / base.width).clamp(0.05, 12.0);
        newX = startRect.left;
        newY = startRect.top;
      case _ResizeEdge.left:
        final right = startRect.right;
        final newW = math.max(8.0, right - logical.dx);
        newScale = (newW / base.width).clamp(0.05, 12.0);
        newX = right - base.width * newScale;
        newY = startRect.top;
      case _ResizeEdge.bottom:
        final newH = math.max(8.0, logical.dy - startRect.top);
        newScale = (newH / base.height).clamp(0.05, 12.0);
        newX = startRect.left;
        newY = startRect.top;
      case _ResizeEdge.top:
        final bottom = startRect.bottom;
        final newH = math.max(8.0, bottom - logical.dy);
        newScale = (newH / base.height).clamp(0.05, 12.0);
        newX = startRect.left;
        newY = bottom - base.height * newScale;
      case _ResizeEdge.bottomRight:
        final newW = math.max(8.0, logical.dx - startRect.left);
        final newH = math.max(8.0, logical.dy - startRect.top);
        newScale = math
            .max(newW / base.width, newH / base.height)
            .clamp(0.05, 12.0);
        newX = startRect.left;
        newY = startRect.top;
      case _ResizeEdge.bottomLeft:
        final right = startRect.right;
        final newW = math.max(8.0, right - logical.dx);
        final newH = math.max(8.0, logical.dy - startRect.top);
        newScale = math
            .max(newW / base.width, newH / base.height)
            .clamp(0.05, 12.0);
        newX = right - base.width * newScale;
        newY = startRect.top;
      case _ResizeEdge.topRight:
        final bottom = startRect.bottom;
        final newW = math.max(8.0, logical.dx - startRect.left);
        final newH = math.max(8.0, bottom - logical.dy);
        newScale = math
            .max(newW / base.width, newH / base.height)
            .clamp(0.05, 12.0);
        newX = startRect.left;
        newY = bottom - base.height * newScale;
      case _ResizeEdge.topLeft:
        final right = startRect.right;
        final bottom = startRect.bottom;
        final newW = math.max(8.0, right - logical.dx);
        final newH = math.max(8.0, bottom - logical.dy);
        newScale = math
            .max(newW / base.width, newH / base.height)
            .clamp(0.05, 12.0);
        newX = right - base.width * newScale;
        newY = bottom - base.height * newScale;
    }

    final next = _clampPhoto(
      photo.copyWith(offsetX: newX, offsetY: newY, scale: newScale),
      image,
    );
    _emitPhotos(photo.id, next);
  }

  void _applyCrop(
    Offset logical,
    PhotoItem startPhoto,
    ui.Image image,
    Rect startRect,
  ) {
    final edge = _resizeEdge;
    if (edge == null) return;

    // Full-image dest frame implied by the current crop window.
    final cw = math.max(0.05, startPhoto.cropWidthFrac);
    final ch = math.max(0.05, startPhoto.cropHeightFrac);
    final fullW = startRect.width / cw;
    final fullH = startRect.height / ch;
    final full = Rect.fromLTWH(
      startRect.left - startPhoto.cropLeft * fullW,
      startRect.top - startPhoto.cropTop * fullH,
      fullW,
      fullH,
    );

    var left = startRect.left;
    var top = startRect.top;
    var right = startRect.right;
    var bottom = startRect.bottom;
    final min = _minCropDestPx;

    void clampL() => left = left.clamp(full.left, right - min);
    void clampR() => right = right.clamp(left + min, full.right);
    void clampT() => top = top.clamp(full.top, bottom - min);
    void clampB() => bottom = bottom.clamp(top + min, full.bottom);

    switch (edge) {
      case _ResizeEdge.left:
        left = logical.dx;
        clampL();
      case _ResizeEdge.right:
        right = logical.dx;
        clampR();
      case _ResizeEdge.top:
        top = logical.dy;
        clampT();
      case _ResizeEdge.bottom:
        bottom = logical.dy;
        clampB();
      case _ResizeEdge.topLeft:
        left = logical.dx;
        top = logical.dy;
        clampL();
        clampT();
      case _ResizeEdge.topRight:
        right = logical.dx;
        top = logical.dy;
        clampR();
        clampT();
      case _ResizeEdge.bottomLeft:
        left = logical.dx;
        bottom = logical.dy;
        clampL();
        clampB();
      case _ResizeEdge.bottomRight:
        right = logical.dx;
        bottom = logical.dy;
        clampR();
        clampB();
    }

    final crop = startPhoto.withClampedCrop(
      cropLeft: ((left - full.left) / full.width).clamp(0.0, 0.95),
      cropTop: ((top - full.top) / full.height).clamp(0.0, 0.95),
      cropRight: ((full.right - right) / full.width).clamp(0.0, 0.95),
      cropBottom: ((full.bottom - bottom) / full.height).clamp(0.0, 0.95),
    );

    final border = CanvasLayout.borderPx(_config);
    final innerH = math.max(1.0, _frameLogical.height - 2 * border);
    final base = CanvasLayout.tapestryBaseSize(
      Size(image.width.toDouble(), image.height.toDouble()),
      innerH,
      photo: crop,
      tileAspect: _config.tapestryTileAspect,
    );
    final destH = bottom - top;
    final scale = (destH / base.height).clamp(0.05, 12.0);
    final next = _clampPhoto(
      crop.copyWith(
        offsetX: left,
        offsetY: top,
        scale: scale,
      ),
      image,
    );
    _emitPhotos(startPhoto.id, next);
  }

  Future<void> _onDoubleTap(
    Offset local,
    List<PhotoItem> photos,
    List<ui.Image> images,
    List<TextItem> texts,
  ) async {
    final hit = _hitTestAny(local, photos, images, texts);
    if (hit?.textId != null) {
      final text = _findText(hit!.textId!);
      if (text == null) return;
      _selectText(text.id);
      _focusNode.requestFocus();
      final result = await showDialog<TextItem>(
        context: context,
        builder: (ctx) => _TextPropertiesDialog(text: text),
      );
      if (result != null && mounted) {
        _emitTexts(text.id, _clampText(result));
      }
      return;
    }

    final id = hit?.photoId ?? widget.selectedPhotoId;
    if (id == null) return;
    final photo = photos.cast<PhotoItem?>().firstWhere(
          (p) => p?.id == id,
          orElse: () => null,
        );
    if (photo == null) return;
    final image = widget.images[id];
    if (image == null) return;

    _selectPhoto(id);
    _focusNode.requestFocus();

    final placed = _ensurePlaced(photo);
    final border = CanvasLayout.borderPx(_config);
    final innerH = math.max(1.0, _frameLogical.height - 2 * border);
    final base = CanvasLayout.tapestryBaseSize(
      Size(image.width.toDouble(), image.height.toDouble()),
      innerH,
      photo: photo,
      tileAspect: _config.tapestryTileAspect,
    );

    final result = await showDialog<PhotoItem>(
      context: context,
      builder: (ctx) => _PhotoPropertiesDialog(
        photo: placed,
        baseSize: base,
      ),
    );
    if (result != null && mounted) {
      _emitPhotos(id, _clampPhoto(result, image));
    }
  }

  Offset _toLogical(Offset local) =>
      Offset(local.dx / _viewScale, local.dy / _viewScale);

  void _selectPhoto(String? id) {
    widget.onSelectPhoto(id);
    if (id != null) widget.onSelectText?.call(null);
  }

  void _selectText(String? id) {
    widget.onSelectText?.call(id);
    if (id != null) widget.onSelectPhoto(null);
  }

  Future<void> _showContextMenu(
    PointerDownEvent e,
    ({String? photoId, String? textId})? hit,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(e.position.dx, e.position.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    if (hit?.photoId != null ||
        (hit == null && widget.selectedPhotoId != null)) {
      final id = hit?.photoId ?? widget.selectedPhotoId!;
      final chosen = await showMenu<String>(
        context: context,
        position: position,
        items: [
          const PopupMenuItem(value: 'rotate', child: Text('Rotate')),
          const PopupMenuItem(value: 'crop', child: Text('Crop')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'layerUp', child: Text('Layer up')),
          const PopupMenuItem(value: 'layerDown', child: Text('Layer down')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'size', child: Text('Size…')),
          const PopupMenuItem(value: 'properties', child: Text('Properties…')),
        ],
      );
      if (!mounted || chosen == null) return;
      await _handlePhotoMenu(chosen, id);
      return;
    }

    if (hit?.textId != null ||
        (hit == null && widget.selectedTextId != null && hit?.photoId == null)) {
      final id = hit?.textId ?? widget.selectedTextId!;
      final chosen = await showMenu<String>(
        context: context,
        position: position,
        items: [
          const PopupMenuItem(value: 'rotate', child: Text('Rotate')),
          const PopupMenuItem(value: 'font', child: Text('Font…')),
          const PopupMenuItem(value: 'size', child: Text('Size…')),
          const PopupMenuItem(value: 'color', child: Text('Color…')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'layerUp', child: Text('Layer up')),
          const PopupMenuItem(value: 'layerDown', child: Text('Layer down')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'properties', child: Text('Properties…')),
        ],
      );
      if (!mounted || chosen == null) return;
      await _handleTextMenu(chosen, id);
      return;
    }

    // Empty canvas: optional Add text.
    final chosen = await showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(value: 'addText', child: Text('Add text')),
      ],
    );
    if (!mounted || chosen != 'addText') return;
    _defaultAddText();
  }

  Future<void> _handlePhotoMenu(String action, String id) async {
    _selectPhoto(id);
    switch (action) {
      case 'rotate':
        setState(() => _handleMode = _HandleMode.rotate);
      case 'crop':
        setState(() => _handleMode = _HandleMode.crop);
      case 'layerUp':
        applyZOrder(TapestryZOrder.raise);
      case 'layerDown':
        applyZOrder(TapestryZOrder.lower);
      case 'size':
      case 'properties':
        final photo = _findPhoto(id);
        final image = widget.images[id];
        if (photo == null || image == null) return;
        final placed = _ensurePlaced(photo);
        final border = CanvasLayout.borderPx(_config);
        final innerH = math.max(1.0, _frameLogical.height - 2 * border);
        final base = CanvasLayout.tapestryBaseSize(
          Size(image.width.toDouble(), image.height.toDouble()),
          innerH,
          photo: photo,
          tileAspect: _config.tapestryTileAspect,
        );
        final result = await showDialog<PhotoItem>(
          context: context,
          builder: (ctx) => _PhotoPropertiesDialog(
            photo: placed,
            baseSize: base,
          ),
        );
        if (result != null && mounted) {
          _emitPhotos(id, _clampPhoto(result, image));
        }
    }
  }

  Future<void> _handleTextMenu(String action, String id) async {
    _selectText(id);
    final text = _findText(id);
    if (text == null) return;
    switch (action) {
      case 'rotate':
        setState(() => _handleMode = _HandleMode.rotate);
      case 'layerUp':
        applyZOrder(TapestryZOrder.raise);
      case 'layerDown':
        applyZOrder(TapestryZOrder.lower);
      case 'font':
      case 'size':
      case 'color':
      case 'properties':
        final result = await showDialog<TextItem>(
          context: context,
          builder: (ctx) => _TextPropertiesDialog(
            text: text,
            focusField: switch (action) {
              'font' => _TextPropFocus.font,
              'size' => _TextPropFocus.size,
              'color' => _TextPropFocus.color,
              _ => _TextPropFocus.content,
            },
          ),
        );
        if (result != null && mounted) {
          _emitTexts(id, _clampText(result));
        }
    }
  }

  void _defaultAddText() {
    if (widget.locked) return;
    if (widget.onAddText != null) {
      widget.onAddText!();
      return;
    }
    final strip = _stripLogical;
    final z = TapestryLayerOrder.nextZIndex(
      widget.layout.photos,
      widget.layout.texts,
    );
    final id = 'text-${DateTime.now().microsecondsSinceEpoch}';
    final item = TextItem(
      id: id,
      text: 'Text',
      offsetX: strip.width * 0.35,
      offsetY: strip.height * 0.35,
      zIndex: z,
    );
    final next = [...widget.layout.texts, item];
    widget.onTextsChanged?.call(next);
    _selectText(id);
    _focusNode.requestFocus();
  }

  void _updateHoverCursor(
    Offset local,
    List<PhotoItem> photos,
    List<ui.Image> images,
    List<TextItem> texts,
  ) {
    if (_dragMode == _DragMode.resize && _resizeEdge != null) {
      final locked = _cursorForEdge(_resizeEdge!);
      if (_hoverCursor != locked) setState(() => _hoverCursor = locked);
      return;
    }
    if (_dragMode == _DragMode.move) {
      if (_hoverCursor != SystemMouseCursors.grabbing) {
        setState(() => _hoverCursor = SystemMouseCursors.grabbing);
      }
      return;
    }
    if (_dragMode == _DragMode.rotate) {
      if (_hoverCursor != SystemMouseCursors.precise) {
        setState(() => _hoverCursor = SystemMouseCursors.precise);
      }
      return;
    }

    MouseCursor next = SystemMouseCursors.basic;
    if (widget.selectedPhotoId != null) {
      final edge = _hitResizeEdge(
        local,
        widget.selectedPhotoId!,
        photos,
        images,
        isText: false,
      );
      if (edge != null) {
        next = _rotateHandles
            ? SystemMouseCursors.precise
            : _cursorForEdge(edge);
      } else if (_hitTestAny(local, photos, images, texts) != null) {
        next = SystemMouseCursors.grab;
      }
    } else if (widget.selectedTextId != null) {
      final edge = _hitTextResizeEdge(local, widget.selectedTextId!, texts);
      if (edge != null) {
        next = _rotateHandles
            ? SystemMouseCursors.precise
            : _cursorForEdge(edge);
      } else if (_hitTestAny(local, photos, images, texts) != null) {
        next = SystemMouseCursors.grab;
      }
    } else if (_hitTestAny(local, photos, images, texts) != null) {
      next = SystemMouseCursors.click;
    }

    if (next != _hoverCursor) {
      setState(() => _hoverCursor = next);
    }
  }

  MouseCursor _cursorForEdge(_ResizeEdge edge) {
    return switch (edge) {
      _ResizeEdge.left || _ResizeEdge.right =>
        SystemMouseCursors.resizeLeftRight,
      _ResizeEdge.top || _ResizeEdge.bottom => SystemMouseCursors.resizeUpDown,
      _ResizeEdge.topLeft || _ResizeEdge.bottomRight =>
        SystemMouseCursors.resizeUpLeftDownRight,
      _ResizeEdge.topRight || _ResizeEdge.bottomLeft =>
        SystemMouseCursors.resizeUpRightDownLeft,
    };
  }

  _ResizeEdge? _hitResizeEdge(
    Offset local,
    String selectedId,
    List<PhotoItem> photos,
    List<ui.Image> images, {
    required bool isText,
  }) {
    if (isText) return null;
    final idx = photos.indexWhere((p) => p.id == selectedId);
    if (idx < 0) return null;
    final placed = _ensurePlaced(photos[idx]);
    final rect = _rectFor(placed, images[idx]);
    return _edgeAt(local, rect);
  }

  _ResizeEdge? _hitTextResizeEdge(
    Offset local,
    String selectedId,
    List<TextItem> texts,
  ) {
    final text = texts.cast<TextItem?>().firstWhere(
          (t) => t?.id == selectedId,
          orElse: () => null,
        );
    if (text == null) return null;
    return _edgeAt(local, _textRect(text));
  }

  _ResizeEdge? _edgeAt(Offset local, Rect rect) {
    final logical = _toLogical(local);
    final tol = _edgeHitPx / _viewScale;

    final nearLeft = (logical.dx - rect.left).abs() <= tol &&
        logical.dy >= rect.top - tol &&
        logical.dy <= rect.bottom + tol;
    final nearRight = (logical.dx - rect.right).abs() <= tol &&
        logical.dy >= rect.top - tol &&
        logical.dy <= rect.bottom + tol;
    final nearTop = (logical.dy - rect.top).abs() <= tol &&
        logical.dx >= rect.left - tol &&
        logical.dx <= rect.right + tol;
    final nearBottom = (logical.dy - rect.bottom).abs() <= tol &&
        logical.dx >= rect.left - tol &&
        logical.dx <= rect.right + tol;

    if (nearLeft && nearTop) return _ResizeEdge.topLeft;
    if (nearRight && nearTop) return _ResizeEdge.topRight;
    if (nearLeft && nearBottom) return _ResizeEdge.bottomLeft;
    if (nearRight && nearBottom) return _ResizeEdge.bottomRight;
    if (nearLeft) return _ResizeEdge.left;
    if (nearRight) return _ResizeEdge.right;
    if (nearTop) return _ResizeEdge.top;
    if (nearBottom) return _ResizeEdge.bottom;
    return null;
  }

  ({String? photoId, String? textId})? _hitTestAny(
    Offset local,
    List<PhotoItem> photos,
    List<ui.Image> images,
    List<TextItem> texts,
  ) {
    final logical = _toLogical(local);
    final layers = TapestryLayerOrder.sorted(photos, texts).reversed;
    for (final layer in layers) {
      if (layer.isPhoto) {
        final i = photos.indexWhere((p) => p.id == layer.id);
        if (i < 0) continue;
        final placed = _ensurePlaced(photos[i]);
        final rect = _rectFor(placed, images[i]);
        if (rect.contains(logical)) {
          return (photoId: photos[i].id, textId: null);
        }
      } else {
        final text = _findText(layer.id);
        if (text == null) continue;
        if (_textRect(text).contains(logical)) {
          return (photoId: null, textId: text.id);
        }
      }
    }
    return null;
  }

  Rect _textRect(TextItem text) {
    final size = TextRasterizer.measure(text);
    return Rect.fromLTWH(text.offsetX, text.offsetY, size.width, size.height);
  }

  Rect _rectFor(PhotoItem photo, ui.Image image) {
    final border = CanvasLayout.borderPx(_config);
    final innerH = math.max(1.0, _frameLogical.height - 2 * border);
    final base = CanvasLayout.tapestryBaseSize(
      Size(image.width.toDouble(), image.height.toDouble()),
      innerH,
      photo: photo,
      tileAspect: _config.tapestryTileAspect,
    );
    if (photo.hasCustomTransform) {
      return Rect.fromLTWH(
        photo.offsetX,
        photo.offsetY,
        base.width * photo.scale,
        base.height * photo.scale,
      );
    }
    return _autoRectFor(photo.id) ??
        Rect.fromLTWH(border, border, base.width, base.height);
  }

  /// Sequential height-fit origin for [photoId], ignoring sibling custom transforms.
  Rect? _autoRectFor(String photoId) {
    final paired = _paired();
    final border = CanvasLayout.borderPx(_config);
    final innerH = math.max(1.0, _frameLogical.height - 2 * border);
    final gap = _config.tapestryGapPx.toDouble();
    final defaults = [
      for (final p in paired.photos)
        PhotoItem(id: p.id, sourcePath: p.sourcePath, order: p.order),
    ];
    final idx = defaults.indexWhere((p) => p.id == photoId);
    if (idx < 0) return null;
    return CanvasLayout.tapestryPhotoRect(
      photos: defaults,
      images: paired.images,
      index: idx,
      border: border,
      innerH: innerH,
      gap: gap,
      tileAspect: _config.tapestryTileAspect,
    );
  }

  PhotoItem? _findPhoto(String id) {
    for (final p in _ordered) {
      if (p.id == id) return p;
    }
    return null;
  }

  TextItem? _findText(String id) {
    for (final t in widget.layout.texts) {
      if (t.id == id) return t;
    }
    return null;
  }

  PhotoItem _ensurePlaced(PhotoItem photo) {
    if (photo.hasCustomTransform) {
      return photo;
    }
    final auto = _autoRectFor(photo.id);
    if (auto == null) return photo;
    return photo.copyWith(offsetX: auto.left, offsetY: auto.top);
  }

  PhotoItem _clampPhoto(PhotoItem photo, ui.Image image) {
    final border = CanvasLayout.borderPx(_config);
    final innerH = math.max(1.0, _frameLogical.height - 2 * border);
    final base = CanvasLayout.tapestryBaseSize(
      Size(image.width.toDouble(), image.height.toDouble()),
      innerH,
      photo: photo,
      tileAspect: _config.tapestryTileAspect,
    );
    final size = Size(base.width * photo.scale, base.height * photo.scale);
    final origin = CanvasLayout.clampPhotoOrigin(
      origin: Offset(photo.offsetX, photo.offsetY),
      photoSize: size,
      stripSize: _stripLogical,
      minOverlap: _minOverlap,
    );
    return photo.copyWith(offsetX: origin.dx, offsetY: origin.dy);
  }

  TextItem _clampText(TextItem text) {
    final size = TextRasterizer.measure(text);
    final origin = CanvasLayout.clampPhotoOrigin(
      origin: Offset(text.offsetX, text.offsetY),
      photoSize: size,
      stripSize: _stripLogical,
      minOverlap: math.min(_minOverlap, size.shortestSide * 0.5),
    );
    return text.copyWith(offsetX: origin.dx, offsetY: origin.dy);
  }

  void _applyTextResize(Offset logical, TextItem start, Rect startRect) {
    final edge = _resizeEdge;
    if (edge == null) return;
    final base = TextRasterizer.measure(
      start.copyWith(scale: 1),
    );
    if (base.width < 1 || base.height < 1) return;

    double newScale = start.scale;
    double newX = start.offsetX;
    double newY = start.offsetY;

    switch (edge) {
      case _ResizeEdge.right:
      case _ResizeEdge.bottomRight:
      case _ResizeEdge.topRight:
        final newW = math.max(8.0, logical.dx - startRect.left);
        newScale = (newW / base.width).clamp(0.05, 12.0);
        newX = startRect.left;
        newY = startRect.top;
      case _ResizeEdge.left:
      case _ResizeEdge.bottomLeft:
      case _ResizeEdge.topLeft:
        final right = startRect.right;
        final newW = math.max(8.0, right - logical.dx);
        newScale = (newW / base.width).clamp(0.05, 12.0);
        newX = right - base.width * newScale;
        newY = startRect.top;
      case _ResizeEdge.bottom:
        final newH = math.max(8.0, logical.dy - startRect.top);
        newScale = (newH / base.height).clamp(0.05, 12.0);
        newX = startRect.left;
        newY = startRect.top;
      case _ResizeEdge.top:
        final bottom = startRect.bottom;
        final newH = math.max(8.0, bottom - logical.dy);
        newScale = (newH / base.height).clamp(0.05, 12.0);
        newX = startRect.left;
        newY = bottom - base.height * newScale;
    }
    _emitTexts(
      start.id,
      _clampText(start.copyWith(offsetX: newX, offsetY: newY, scale: newScale)),
    );
  }

  void _clampAllOffCanvas() {
    if (!mounted || widget.locked || _isDragging) return;
    final ordered = _ordered;
    var changed = false;
    final out = <PhotoItem>[];
    for (final p in ordered) {
      final image = widget.images[p.id];
      if (image == null) {
        out.add(p);
        continue;
      }
      final placed = _ensurePlaced(p);
      final clamped = _clampPhoto(placed, image);
      if (clamped.offsetX != p.offsetX ||
          clamped.offsetY != p.offsetY ||
          clamped.scale != p.scale) {
        changed = true;
      }
      out.add(clamped);
    }
    if (changed) widget.onPhotosChanged(out);

    var textsChanged = false;
    final nextTexts = <TextItem>[];
    for (final t in widget.layout.texts) {
      final clamped = _clampText(t);
      if (clamped.offsetX != t.offsetX || clamped.offsetY != t.offsetY) {
        textsChanged = true;
      }
      nextTexts.add(clamped);
    }
    if (textsChanged) widget.onTextsChanged?.call(nextTexts);
  }

  void _emitPhotos(String id, PhotoItem next) {
    final ordered = _ordered;
    if (_isDragging) {
      // Local draft only — parent commit happens on pointer-up.
      _beginPhotoDraft();
      _draftPhotos.value = [
        for (final p in ordered) p.id == id ? next : p,
      ];
      return;
    }
    final images = widget.images;
    final out = <PhotoItem>[];
    for (final p in ordered) {
      if (p.id == id) {
        out.add(next);
        continue;
      }
      final img = images[p.id];
      if (img == null) {
        out.add(p);
        continue;
      }
      final needsPlace = !p.hasCustomTransform;
      if (!needsPlace) {
        out.add(p);
        continue;
      }
      final placed = _ensurePlaced(p);
      out.add(placed);
    }
    widget.onPhotosChanged(out);
  }

  void _emitTexts(String id, TextItem next) {
    final texts = _liveTexts;
    final out = [for (final t in texts) t.id == id ? next : t];
    if (_isDragging) {
      _beginTextDraft();
      _draftTexts.value = out;
      return;
    }
    widget.onTextsChanged?.call(out);
  }

  void applyAlign(TapestryAlign align) {
    final photoId = widget.selectedPhotoId;
    if (photoId != null) {
      if (widget.locked) return;
      final photo = _findPhoto(photoId);
      final image = widget.images[photoId];
      if (photo == null || image == null) return;

      final placed = _ensurePlaced(photo);
      final rect = _rectFor(placed, image);
      final strip = _stripLogical;
      final border = CanvasLayout.borderPx(_config);
      final frameW = _frameLogical.width;
      final slideIndex =
          (rect.center.dx / frameW).floor().clamp(0, _slides - 1);
      final slideLeft = slideIndex * frameW;
      final slideRight = slideLeft + frameW;

      late PhotoItem next;
      switch (align) {
        case TapestryAlign.left:
          next = placed.copyWith(offsetX: border);
        case TapestryAlign.centerH:
          next = placed.copyWith(offsetX: (strip.width - rect.width) / 2);
        case TapestryAlign.right:
          next = placed.copyWith(offsetX: strip.width - border - rect.width);
        case TapestryAlign.top:
          next = placed.copyWith(offsetY: border);
        case TapestryAlign.centerV:
          next = placed.copyWith(offsetY: (strip.height - rect.height) / 2);
        case TapestryAlign.bottom:
          next = placed.copyWith(offsetY: strip.height - border - rect.height);
        case TapestryAlign.snapSlide:
          final cx = rect.center.dx;
          final target = (cx - slideLeft < slideRight - cx)
              ? slideLeft + border
              : slideRight - border - rect.width;
          next = placed.copyWith(offsetX: target);
      }
      _emitPhotos(photoId, _clampPhoto(next, image));
      _focusNode.requestFocus();
      return;
    }

    final textId = widget.selectedTextId;
    if (textId == null || widget.locked) return;
    final text = _findText(textId);
    if (text == null) return;
    final rect = _textRect(text);
    final strip = _stripLogical;
    final border = CanvasLayout.borderPx(_config);
    late TextItem next;
    switch (align) {
      case TapestryAlign.left:
        next = text.copyWith(offsetX: border.toDouble());
      case TapestryAlign.centerH:
        next = text.copyWith(offsetX: (strip.width - rect.width) / 2);
      case TapestryAlign.right:
        next = text.copyWith(offsetX: strip.width - border - rect.width);
      case TapestryAlign.top:
        next = text.copyWith(offsetY: border.toDouble());
      case TapestryAlign.centerV:
        next = text.copyWith(offsetY: (strip.height - rect.height) / 2);
      case TapestryAlign.bottom:
        next = text.copyWith(offsetY: strip.height - border - rect.height);
      case TapestryAlign.snapSlide:
        final frameW = _frameLogical.width;
        final slideIndex =
            (rect.center.dx / frameW).floor().clamp(0, _slides - 1);
        final slideLeft = slideIndex * frameW;
        final slideRight = slideLeft + frameW;
        final cx = rect.center.dx;
        final target = (cx - slideLeft < slideRight - cx)
            ? slideLeft + border
            : slideRight - border - rect.width;
        next = text.copyWith(offsetX: target);
    }
    _emitTexts(textId, _clampText(next));
    _focusNode.requestFocus();
  }

  void applyRotate(double deltaDeg) {
    final photoId = widget.selectedPhotoId;
    if (photoId != null) {
      if (widget.locked) return;
      final photo = _findPhoto(photoId);
      final image = widget.images[photoId];
      if (photo == null || image == null) return;
      final placed = _ensurePlaced(photo);
      _emitPhotos(
        photoId,
        _clampPhoto(
          placed.copyWith(rotationDeg: placed.rotationDeg + deltaDeg),
          image,
        ),
      );
      _focusNode.requestFocus();
      return;
    }
    final textId = widget.selectedTextId;
    if (textId == null || widget.locked) return;
    final text = _findText(textId);
    if (text == null) return;
    _emitTexts(
      textId,
      _clampText(
        text.copyWith(rotationDeg: text.rotationDeg + deltaDeg),
      ),
    );
    _focusNode.requestFocus();
  }

  void applyZOrder(TapestryZOrder action) {
    final id = _selectedId;
    if (id == null || widget.locked) return;
    final photos = widget.layout.photos;
    final texts = widget.layout.texts;
    final next = switch (action) {
      TapestryZOrder.raise => TapestryLayerOrder.raise(photos, texts, id),
      TapestryZOrder.lower => TapestryLayerOrder.lower(photos, texts, id),
      TapestryZOrder.bringToFront =>
        TapestryLayerOrder.bringToFront(photos, texts, id),
      TapestryZOrder.sendToBack =>
        TapestryLayerOrder.sendToBack(photos, texts, id),
    };
    if (!identical(next.photos, photos)) {
      widget.onPhotosChanged(next.photos);
    }
    if (!identical(next.texts, texts)) {
      widget.onTextsChanged?.call(next.texts);
    }
    _focusNode.requestFocus();
  }
}

class _InteractiveStripPainter extends CustomPainter {
  _InteractiveStripPainter({
    required this.config,
    required this.images,
    required this.photos,
    required this.texts,
    required this.slideCount,
    required this.selectedPhotoId,
    required this.selectedTextId,
    required this.divisionsOpacity,
    this.pendingSlideDelta = 0,
    this.handleMode = _HandleMode.none,
    this.fast = false,
  });

  final CanvasConfig config;
  final List<ui.Image> images;
  final List<PhotoItem> photos;
  final List<TextItem> texts;
  final int slideCount;
  final String? selectedPhotoId;
  final String? selectedTextId;
  final double divisionsOpacity;
  /// Negative = gray-out rightmost slides that would be removed.
  final int pendingSlideDelta;
  final _HandleMode handleMode;
  /// Prefer cheaper filtering while a drag draft is active.
  final bool fast;

  static const _resizeAccent = Color(0xFF2F6FED);
  static const _cropAccent = Color(0xFFE67E22);
  static const _rotateAccent = Color(0xFF8E44AD);

  Color get _accent => switch (handleMode) {
        _HandleMode.crop => _cropAccent,
        _HandleMode.rotate => _rotateAccent,
        _HandleMode.none => _resizeAccent,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final logical = Size(
      CanvasLayout.canvasSize(config).width * slideCount,
      CanvasLayout.canvasSize(config).height,
    );
    final sx = size.width / logical.width;
    final sy = size.height / logical.height;
    canvas.save();
    canvas.scale(sx, sy);

    final matte = Paint()..color = config.swatch.color;
    canvas.drawRect(Offset.zero & logical, matte);

    canvas.save();
    canvas.clipRect(Offset.zero & logical);

    final border = CanvasLayout.borderPx(config);
    final innerH = math.max(1.0, logical.height - 2 * border);
    final gap = config.tapestryGapPx.toDouble();
    final imagePaint = Paint()
      ..filterQuality = fast ? FilterQuality.low : FilterQuality.medium;

    final layers = TapestryLayerOrder.sorted(photos, texts);
    for (final layer in layers) {
      if (layer.isPhoto) {
        final i = photos.indexWhere((p) => p.id == layer.id);
        if (i < 0 || i >= images.length) continue;
        final rect = CanvasLayout.tapestryPhotoRect(
          photos: photos,
          images: images,
          index: i,
          border: border,
          innerH: innerH,
          gap: gap,
          tileAspect: config.tapestryTileAspect,
        );
        final photo = photos[i];
        final image = images[i];
        final selected = photo.id == selectedPhotoId;
        final showCropGuide = handleMode == _HandleMode.crop && selected;
        final tileAspect = config.tapestryTileAspect;

        canvas.save();
        final cx = rect.center.dx;
        final cy = rect.center.dy;
        canvas.translate(cx, cy);
        canvas.rotate(photo.rotationDeg * math.pi / 180);
        canvas.translate(-cx, -cy);

        if (showCropGuide && photo.hasCrop) {
          final cw = math.max(0.05, photo.cropWidthFrac);
          final ch = math.max(0.05, photo.cropHeightFrac);
          final full = Rect.fromLTWH(
            rect.left - photo.cropLeft * (rect.width / cw),
            rect.top - photo.cropTop * (rect.height / ch),
            rect.width / cw,
            rect.height / ch,
          );
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            full,
            imagePaint,
          );
          final dim = Paint()..color = const Color(0x99000000);
          canvas.drawRect(full, dim);
          final crop = photo.sourceCropPixels(
            sourceWidth: image.width,
            sourceHeight: image.height,
          );
          var src = Rect.fromLTWH(
            crop.left.toDouble(),
            crop.top.toDouble(),
            crop.width.toDouble(),
            crop.height.toDouble(),
          );
          var dst = rect;
          if (tileAspect != null) {
            final fitted = CanvasLayout.tileFitRects(
              src: src,
              tile: rect,
              fit: config.fitMode,
              tileAspect: tileAspect.ratio,
            );
            src = fitted.src;
            dst = fitted.dst;
          }
          canvas.drawImageRect(image, src, dst, imagePaint);
        } else {
          final crop = photo.sourceCropPixels(
            sourceWidth: image.width,
            sourceHeight: image.height,
          );
          var src = Rect.fromLTWH(
            crop.left.toDouble(),
            crop.top.toDouble(),
            crop.width.toDouble(),
            crop.height.toDouble(),
          );
          var dst = rect;
          if (tileAspect != null) {
            final fitted = CanvasLayout.tileFitRects(
              src: src,
              tile: rect,
              fit: config.fitMode,
              tileAspect: tileAspect.ratio,
            );
            src = fitted.src;
            dst = fitted.dst;
          }
          canvas.drawImageRect(image, src, dst, imagePaint
          );
        }
        canvas.restore();
      } else {
        TextItem? text;
        for (final t in texts) {
          if (t.id == layer.id) {
            text = t;
            break;
          }
        }
        if (text != null) TextRasterizer.paint(canvas, text);
      }
    }
    canvas.restore(); // clip

    if (pendingSlideDelta < 0) {
      final remove = -pendingSlideDelta;
      final frameW = CanvasLayout.canvasSize(config).width;
      final left = math.max(0.0, (slideCount - remove) * frameW);
      final ghost = Paint()..color = const Color(0x99888888);
      canvas.drawRect(
        Rect.fromLTWH(left, 0, logical.width - left, logical.height),
        ghost,
      );
      final mark = Paint()
        ..color = const Color(0xE0FFFFFF)
        ..strokeWidth = 3 / sx
        ..strokeCap = StrokeCap.round;
      final midX = left + (logical.width - left) / 2;
      final midY = logical.height / 2;
      final arm = math.min(frameW, logical.width - left) * 0.18;
      canvas.drawLine(Offset(midX - arm, midY), Offset(midX + arm, midY), mark);
    }

    void drawHandles(Rect rect) {
      final accent = _accent;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / sx
        ..color = accent;
      canvas.drawRect(rect.inflate(1), stroke);

      final handle = Paint()..color = accent;
      final hs = handleMode == _HandleMode.rotate ? 7 / sx : 6 / sx;
      for (final c in [
        Offset(rect.left, rect.top),
        Offset(rect.right, rect.top),
        Offset(rect.left, rect.bottom),
        Offset(rect.right, rect.bottom),
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.bottom),
      ]) {
        if (handleMode == _HandleMode.rotate) {
          canvas.drawCircle(c, hs * 0.55, handle);
        } else {
          canvas.drawRect(
            Rect.fromCenter(center: c, width: hs, height: hs),
            handle,
          );
        }
      }
    }

    if (selectedPhotoId != null) {
      final idx = photos.indexWhere((p) => p.id == selectedPhotoId);
      if (idx >= 0) {
        final rect = CanvasLayout.tapestryPhotoRect(
          photos: photos,
          images: images,
          index: idx,
          border: border,
          innerH: innerH,
          gap: gap,
          tileAspect: config.tapestryTileAspect,
        );
        drawHandles(rect);
      }
    } else if (selectedTextId != null) {
      TextItem? text;
      for (final t in texts) {
        if (t.id == selectedTextId) {
          text = t;
          break;
        }
      }
      if (text != null) {
        final m = TextRasterizer.measure(text);
        drawHandles(
          Rect.fromLTWH(text.offsetX, text.offsetY, m.width, m.height),
        );
      }
    }

    if (divisionsOpacity > 0.01 && slideCount > 1) {
      final frameW = CanvasLayout.canvasSize(config).width;
      final line = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: divisionsOpacity)
        ..blendMode = BlendMode.difference
        ..strokeWidth = 1 / sx;
      for (var i = 1; i < slideCount; i++) {
        final x = i * frameW;
        canvas.drawLine(Offset(x, 0), Offset(x, logical.height), line);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InteractiveStripPainter old) {
    return old.config != config ||
        old.slideCount != slideCount ||
        old.selectedPhotoId != selectedPhotoId ||
        old.selectedTextId != selectedTextId ||
        old.divisionsOpacity != divisionsOpacity ||
        old.pendingSlideDelta != pendingSlideDelta ||
        old.handleMode != handleMode ||
        old.fast != fast ||
        old.images.length != images.length ||
        !identical(old.images, images) ||
        !identical(old.photos, photos) ||
        !identical(old.texts, texts);
  }
}

/// Compact add/remove control overlaid on empty slides / after the strip.
class _SlideChromeButton extends StatelessWidget {
  const _SlideChromeButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _AddSlideGhostPainter extends CustomPainter {
  const _AddSlideGhostPainter({
    required this.committed,
    required this.frameViewWidth,
  });

  /// True once the drag has crossed the 50% threshold (will add on release).
  final bool committed;
  final double frameViewWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = committed ? const Color(0x99888888) : const Color(0x55888888);
    canvas.drawRect(Offset.zero & size, fill);

    if (frameViewWidth > 1) {
      final div = Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 1;
      for (var x = frameViewWidth; x < size.width - 0.5; x += frameViewWidth) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), div);
      }
    }

    if (committed) {
      final mark = Paint()
        ..color = const Color(0xE0FFFFFF)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final cx = size.width / 2;
      final cy = size.height / 2;
      final arm = math.min(size.width, size.height) * 0.12;
      canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), mark);
      canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), mark);
    }
  }

  @override
  bool shouldRepaint(covariant _AddSlideGhostPainter old) {
    return old.committed != committed || old.frameViewWidth != frameViewWidth;
  }
}

class _PhotoPropertiesDialog extends StatefulWidget {
  const _PhotoPropertiesDialog({
    required this.photo,
    required this.baseSize,
  });

  final PhotoItem photo;
  final Size baseSize;

  @override
  State<_PhotoPropertiesDialog> createState() => _PhotoPropertiesDialogState();
}

class _PhotoPropertiesDialogState extends State<_PhotoPropertiesDialog> {
  late final TextEditingController _w;
  late final TextEditingController _h;
  late final TextEditingController _x;
  late final TextEditingController _y;
  late final TextEditingController _rot;
  late final TextEditingController _scale;

  @override
  void initState() {
    super.initState();
    final p = widget.photo;
    final w = widget.baseSize.width * p.scale;
    final h = widget.baseSize.height * p.scale;
    _w = TextEditingController(text: w.toStringAsFixed(1));
    _h = TextEditingController(text: h.toStringAsFixed(1));
    _x = TextEditingController(text: p.offsetX.toStringAsFixed(1));
    _y = TextEditingController(text: p.offsetY.toStringAsFixed(1));
    _rot = TextEditingController(text: p.rotationDeg.toStringAsFixed(1));
    _scale = TextEditingController(text: p.scale.toStringAsFixed(3));
  }

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    _x.dispose();
    _y.dispose();
    _rot.dispose();
    _scale.dispose();
    super.dispose();
  }

  void _fromWidth(String raw) {
    final w = double.tryParse(raw);
    if (w == null || w <= 0) return;
    final scale = w / widget.baseSize.width;
    final h = widget.baseSize.height * scale;
    setState(() {
      _scale.text = scale.toStringAsFixed(3);
      _h.text = h.toStringAsFixed(1);
    });
  }

  void _fromHeight(String raw) {
    final h = double.tryParse(raw);
    if (h == null || h <= 0) return;
    final scale = h / widget.baseSize.height;
    final w = widget.baseSize.width * scale;
    setState(() {
      _scale.text = scale.toStringAsFixed(3);
      _w.text = w.toStringAsFixed(1);
    });
  }

  void _fromScale(String raw) {
    final scale = double.tryParse(raw);
    if (scale == null || scale <= 0) return;
    setState(() {
      _w.text = (widget.baseSize.width * scale).toStringAsFixed(1);
      _h.text = (widget.baseSize.height * scale).toStringAsFixed(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Photo properties'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _w,
                    decoration: const InputDecoration(
                      labelText: 'Width (px)',
                      helperText: 'Aspect locked',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: _fromWidth,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _h,
                    decoration: const InputDecoration(
                      labelText: 'Height (px)',
                      helperText: 'Aspect locked',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: _fromHeight,
                  ),
                ),
              ],
            ),
            TextField(
              controller: _scale,
              decoration: const InputDecoration(labelText: 'Scale'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: _fromScale,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _x,
                    decoration: const InputDecoration(labelText: 'X'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _y,
                    decoration: const InputDecoration(labelText: 'Y'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _rot,
              decoration: const InputDecoration(labelText: 'Rotation (°)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (widget.photo.hasCrop) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      widget.photo.copyWith(
                        cropLeft: 0,
                        cropTop: 0,
                        cropRight: 0,
                        cropBottom: 0,
                      ),
                    );
                  },
                  icon: const Icon(Icons.crop_free, size: 18),
                  label: const Text('Reset crop'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final scale = double.tryParse(_scale.text) ?? widget.photo.scale;
            final x = double.tryParse(_x.text) ?? widget.photo.offsetX;
            final y = double.tryParse(_y.text) ?? widget.photo.offsetY;
            final rot = double.tryParse(_rot.text) ?? widget.photo.rotationDeg;
            Navigator.pop(
              context,
              widget.photo.copyWith(
                scale: scale.clamp(0.05, 12.0),
                offsetX: x,
                offsetY: y,
                rotationDeg: rot,
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

enum _TextPropFocus { content, font, size, color }

class _TextPropertiesDialog extends StatefulWidget {
  const _TextPropertiesDialog({
    required this.text,
    this.focusField = _TextPropFocus.content,
  });

  final TextItem text;
  final _TextPropFocus focusField;

  @override
  State<_TextPropertiesDialog> createState() => _TextPropertiesDialogState();
}

class _TextPropertiesDialogState extends State<_TextPropertiesDialog> {
  late final TextEditingController _content;
  late final TextEditingController _font;
  late final TextEditingController _size;
  late final TextEditingController _scale;
  late final TextEditingController _rot;
  late final TextEditingController _x;
  late final TextEditingController _y;
  late int _colorArgb;
  late int _weight;
  final _contentFocus = FocusNode();
  final _fontFocus = FocusNode();
  final _sizeFocus = FocusNode();

  static const _fonts = [
    'Georgia',
    'Roboto',
    'Arial',
    'Times New Roman',
    'Courier New',
    'Segoe UI',
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.text;
    _content = TextEditingController(text: t.text);
    _font = TextEditingController(text: t.fontFamily);
    _size = TextEditingController(text: t.fontSize.toStringAsFixed(0));
    _scale = TextEditingController(text: t.scale.toStringAsFixed(3));
    _rot = TextEditingController(text: t.rotationDeg.toStringAsFixed(1));
    _x = TextEditingController(text: t.offsetX.toStringAsFixed(1));
    _y = TextEditingController(text: t.offsetY.toStringAsFixed(1));
    _colorArgb = t.colorArgb;
    _weight = t.fontWeight;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (widget.focusField) {
        case _TextPropFocus.font:
          _fontFocus.requestFocus();
        case _TextPropFocus.size:
          _sizeFocus.requestFocus();
        case _TextPropFocus.color:
          break;
        case _TextPropFocus.content:
          _contentFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _content.dispose();
    _font.dispose();
    _size.dispose();
    _scale.dispose();
    _rot.dispose();
    _x.dispose();
    _y.dispose();
    _contentFocus.dispose();
    _fontFocus.dispose();
    _sizeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Text properties'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _content,
                focusNode: _contentFocus,
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 3,
              ),
              DropdownMenu<String>(
                initialSelection: _fonts.contains(_font.text)
                    ? _font.text
                    : _fonts.first,
                label: const Text('Font'),
                dropdownMenuEntries: [
                  for (final f in _fonts)
                    DropdownMenuEntry(value: f, label: f),
                ],
                onSelected: (v) {
                  if (v == null) return;
                  setState(() => _font.text = v);
                },
              ),
              TextField(
                controller: _font,
                focusNode: _fontFocus,
                decoration: const InputDecoration(
                  labelText: 'Font family',
                  helperText: 'Or type a custom family name',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _size,
                      focusNode: _sizeFocus,
                      decoration: const InputDecoration(labelText: 'Size'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _scale,
                      decoration: const InputDecoration(labelText: 'Scale'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _x,
                      decoration: const InputDecoration(labelText: 'X'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _y,
                      decoration: const InputDecoration(labelText: 'Y'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _rot,
                decoration: const InputDecoration(labelText: 'Rotation (°)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Weight: $_weight',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Slider(
                value: _weight.toDouble().clamp(100, 900),
                min: 100,
                max: 900,
                divisions: 8,
                label: '$_weight',
                onChanged: (v) => setState(() => _weight = (v / 100).round() * 100),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Color'),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () async {
                      // Simple preset cycle + custom via hex field would be heavy;
                      // offer a few common colors.
                      final chosen = await showDialog<int>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: const Text('Text color'),
                          children: [
                            for (final entry in const [
                              ('Black', 0xFF000000),
                              ('White', 0xFFFFFFFF),
                              ('Charcoal', 0xFF333333),
                              ('Accent blue', 0xFF2F6FED),
                              ('Coral', 0xFFE74C3C),
                              ('Forest', 0xFF27AE60),
                            ])
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(ctx, entry.$2),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      color: Color(entry.$2),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(entry.$1),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                      if (chosen != null) setState(() => _colorArgb = chosen);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(_colorArgb),
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final fontSize =
                double.tryParse(_size.text) ?? widget.text.fontSize;
            final scale = double.tryParse(_scale.text) ?? widget.text.scale;
            final x = double.tryParse(_x.text) ?? widget.text.offsetX;
            final y = double.tryParse(_y.text) ?? widget.text.offsetY;
            final rot = double.tryParse(_rot.text) ?? widget.text.rotationDeg;
            Navigator.pop(
              context,
              widget.text.copyWith(
                text: _content.text,
                fontFamily: _font.text.trim().isEmpty
                    ? widget.text.fontFamily
                    : _font.text.trim(),
                fontSize: fontSize.clamp(4.0, 2000.0),
                scale: scale.clamp(0.05, 12.0),
                offsetX: x,
                offsetY: y,
                rotationDeg: rot,
                colorArgb: _colorArgb,
                fontWeight: _weight,
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
