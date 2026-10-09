import 'project.dart';

/// Instagram organic carousel limits (native app upload).
abstract final class InstagramLimits {
  /// Max photos/videos in one carousel post (raised from 10 in Oct 2024).
  static const int maxCarouselSlides = 20;

  /// Minimum slides for a carousel (below this it is a single image post).
  static const int minCarouselSlides = 1;

  /// Clamp a requested slide/photo count into the allowed range.
  static int clampSlideCount(int n) =>
      n.clamp(minCarouselSlides, maxCarouselSlides);

  static List<PhotoItem> _orderedPhotos(List<PhotoItem> photos) {
    final list = [...photos]..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// True when this layout has more carousel frames / batch photos than IG allows.
  static bool layoutExceedsCarouselLimit(LayoutCanvas layout) {
    if (layout.isTapestry) {
      return layout.tapestrySlideCount > maxCarouselSlides ||
          _orderedPhotos(layout.photos).length > maxCarouselSlides;
    }
    return _orderedPhotos(layout.photos).length > maxCarouselSlides;
  }

  /// Batch strip index (0-based carousel order) is beyond the IG cap.
  static bool batchCarouselIndexExceedsLimit(int carouselIndex) =>
      carouselIndex >= maxCarouselSlides;

  static const excessCarouselFrameTooltip =
      'Beyond Instagram\'s carousel limit ($maxCarouselSlides photos per post). '
      'This frame will not appear in a native carousel unless you remove or '
      'reorder earlier photos.';

  static const showInstagramWarningsTooltip =
      'Show which parts of this layout exceed Instagram\'s carousel limit '
      '($maxCarouselSlides photos per post).';

  static const hideInstagramWarningsTooltip =
      'Hide Instagram carousel limit warnings for this layout.';
}
