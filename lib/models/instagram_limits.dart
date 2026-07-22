/// Instagram organic carousel limits (native app upload).
abstract final class InstagramLimits {
  /// Max photos/videos in one carousel post (raised from 10 in Oct 2024).
  static const int maxCarouselSlides = 20;

  /// Minimum slides for a carousel (below this it is a single image post).
  static const int minCarouselSlides = 1;

  /// Clamp a requested slide/photo count into the allowed range.
  static int clampSlideCount(int n) =>
      n.clamp(minCarouselSlides, maxCarouselSlides);
}
