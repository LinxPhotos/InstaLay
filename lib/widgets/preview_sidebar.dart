import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fitted overview of the framed export (contain-in-box), not pixel zoom.
class PreviewSidebar extends StatefulWidget {
  const PreviewSidebar({
    super.key,
    required this.title,
    required this.image,
    this.slices = const [],
    this.loading = false,
    this.width = 320,
    this.aspectRatio = 1,
    this.subtitle,
  });

  final String title;
  final ui.Image? image;
  /// When non-empty (tapestry), show a swipeable carousel of framed slices.
  final List<ui.Image> slices;
  final bool loading;
  final double width;
  /// Box shape for the fitted preview (defaults to square).
  final double aspectRatio;
  final String? subtitle;

  @override
  State<PreviewSidebar> createState() => _PreviewSidebarState();
}

class _PreviewSidebarState extends State<PreviewSidebar> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant PreviewSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slices.length != widget.slices.length ||
        !identical(oldWidget.slices, widget.slices)) {
      _page = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppTheme.chrome(context);
    final panel = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.elevatedDark
        : const Color(0xFFF0EFEC);
    final hasSlices = widget.slices.length > 1;
    final single = widget.slices.length == 1
        ? widget.slices.first
        : widget.image;
    final subtitle = widget.subtitle ??
        (hasSlices
            ? 'Tapestry carousel · swipe frames'
            : 'Framed canvas, fitted to the box');

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: chrome)),
        color: panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              widget.title,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.muted(context, 0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.topCenter,
                child: AspectRatio(
                  aspectRatio:
                      widget.aspectRatio <= 0 ? 1 : widget.aspectRatio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: chrome),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasSlices)
                          _SlicePager(
                            controller: _pageController,
                            slices: widget.slices,
                            page: _page,
                            onPage: (i) => setState(() => _page = i),
                          )
                        else if (single != null)
                          InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 8,
                            child: RawImage(
                              image: single,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          )
                        else if (!widget.loading)
                          Center(
                            child: Text(
                              'Select a photo',
                              style: TextStyle(
                                color: AppTheme.muted(context, 0.4),
                              ),
                            ),
                          ),
                        if (widget.loading)
                          ColoredBox(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: single == null && !hasSlices ? 1 : 0.35),
                            child: const Center(
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (hasSlices)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                'Frame ${_page + 1} of ${widget.slices.length}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted(context, 0.55),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SlicePager extends StatelessWidget {
  const _SlicePager({
    required this.controller,
    required this.slices,
    required this.page,
    required this.onPage,
  });

  final PageController controller;
  final List<ui.Image> slices;
  final int page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: controller,
          itemCount: slices.length,
          onPageChanged: onPage,
          itemBuilder: (context, index) {
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 8,
              child: RawImage(
                image: slices[index],
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            );
          },
        ),
        if (slices.length > 1)
          Positioned(
            left: 4,
            right: 4,
            bottom: 8,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < slices.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == page
                            ? Theme.of(context).colorScheme.primary
                            : AppTheme.muted(context, 0.25),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
