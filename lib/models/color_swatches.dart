import 'package:flutter/material.dart';

/// Adams zone-system inspired groupings for photographic mattes / canvases.
enum PhotoZone {
  zone0('Zone 0', 'Pure black — absolute Dmax'),
  zoneI('Zone I', 'Near black — slight tone'),
  zoneII('Zone II', 'Darkest textured shadow'),
  zoneIII('Zone III', 'Dark with detail'),
  zoneIV('Zone IV', 'Open shadow / dark midtone'),
  zoneV('Zone V', 'Middle grey (18%)'),
  zoneVI('Zone VI', 'Light midtone'),
  zoneVII('Zone VII', 'Light grey / high key'),
  zoneVIII('Zone VIII', 'Sheer light — textured highlight'),
  zoneIX('Zone IX', 'Near white'),
  zoneX('Zone X', 'Pure white — paper base'),
  taupe('Taupes', 'Warm neutrals for skin & interiors');

  const PhotoZone(this.label, this.description);

  final String label;
  final String description;
}

class CanvasSwatch {
  const CanvasSwatch({
    required this.id,
    required this.name,
    required this.color,
    required this.zone,
  });

  final String id;
  final String name;
  final Color color;
  final PhotoZone zone;

  int get argb => color.toARGB32();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'argb': argb,
        'zone': zone.name,
      };

  factory CanvasSwatch.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id != null) {
      for (final s in CanvasSwatchCatalog.all) {
        if (s.id == id) return s;
      }
    }
    return CanvasSwatch(
      id: id ?? 'custom',
      name: json['name'] as String? ?? 'Custom',
      color: Color(json['argb'] as int? ?? 0xFFF2F2F0),
      zone: PhotoZone.values.firstWhere(
        (z) => z.name == json['zone'],
        orElse: () => PhotoZone.zoneVIII,
      ),
    );
  }
}

/// Predefined mattes: sheer whites/greys/taupes plus cinematic darks.
abstract final class CanvasSwatchCatalog {
  /// Default: very sheer light grey (Zone VIII).
  static const defaultSwatch = sheerCloud;

  static const allWhite = CanvasSwatch(
    id: 'all_white',
    name: 'All White',
    color: Color(0xFFFFFFFF),
    zone: PhotoZone.zoneX,
  );

  static const paperIvory = CanvasSwatch(
    id: 'paper_ivory',
    name: 'Paper Ivory',
    color: Color(0xFFFFFEF9),
    zone: PhotoZone.zoneIX,
  );

  static const mistWhite = CanvasSwatch(
    id: 'mist_white',
    name: 'Mist White',
    color: Color(0xFFF9F9F7),
    zone: PhotoZone.zoneIX,
  );

  static const sheerCloud = CanvasSwatch(
    id: 'sheer_cloud',
    name: 'Sheer Cloud',
    color: Color(0xFFF2F2F0),
    zone: PhotoZone.zoneVIII,
  );

  static const softAsh = CanvasSwatch(
    id: 'soft_ash',
    name: 'Soft Ash',
    color: Color(0xFFE8E8E4),
    zone: PhotoZone.zoneVIII,
  );

  static const warmLinen = CanvasSwatch(
    id: 'warm_linen',
    name: 'Warm Linen',
    color: Color(0xFFEDE9E3),
    zone: PhotoZone.zoneVIII,
  );

  static const lightGrey = CanvasSwatch(
    id: 'light_grey',
    name: 'Light Grey',
    color: Color(0xFFD6D6D2),
    zone: PhotoZone.zoneVII,
  );

  static const midSilver = CanvasSwatch(
    id: 'mid_silver',
    name: 'Mid Silver',
    color: Color(0xFFB8B8B4),
    zone: PhotoZone.zoneVI,
  );

  static const middleGrey = CanvasSwatch(
    id: 'middle_grey',
    name: 'Middle Grey (Zone V)',
    color: Color(0xFF7A7A76),
    zone: PhotoZone.zoneV,
  );

  static const openShadow = CanvasSwatch(
    id: 'open_shadow',
    name: 'Open Shadow',
    color: Color(0xFF555552),
    zone: PhotoZone.zoneIV,
  );

  static const darkDetail = CanvasSwatch(
    id: 'dark_detail',
    name: 'Dark Detail',
    color: Color(0xFF3A3A38),
    zone: PhotoZone.zoneIII,
  );

  static const texturedBlack = CanvasSwatch(
    id: 'textured_black',
    name: 'Textured Black',
    color: Color(0xFF242422),
    zone: PhotoZone.zoneII,
  );

  static const nearBlack = CanvasSwatch(
    id: 'near_black',
    name: 'Near Black',
    color: Color(0xFF121211),
    zone: PhotoZone.zoneI,
  );

  static const allBlack = CanvasSwatch(
    id: 'all_black',
    name: 'All Black',
    color: Color(0xFF000000),
    zone: PhotoZone.zone0,
  );

  static const cinemaCharcoal = CanvasSwatch(
    id: 'cinema_charcoal',
    name: 'Cinema Charcoal',
    color: Color(0xFF1C1C1A),
    zone: PhotoZone.zoneI,
  );

  static const taupeMist = CanvasSwatch(
    id: 'taupe_mist',
    name: 'Taupe Mist',
    color: Color(0xFFE8E2DA),
    zone: PhotoZone.taupe,
  );

  static const taupeStone = CanvasSwatch(
    id: 'taupe_stone',
    name: 'Taupe Stone',
    color: Color(0xFFC9C0B4),
    zone: PhotoZone.taupe,
  );

  static const taupeClay = CanvasSwatch(
    id: 'taupe_clay',
    name: 'Taupe Clay',
    color: Color(0xFFA89888),
    zone: PhotoZone.taupe,
  );

  static const taupeUmber = CanvasSwatch(
    id: 'taupe_umber',
    name: 'Taupe Umber',
    color: Color(0xFF6E6258),
    zone: PhotoZone.taupe,
  );

  static const all = <CanvasSwatch>[
    allWhite,
    paperIvory,
    mistWhite,
    sheerCloud,
    softAsh,
    warmLinen,
    lightGrey,
    midSilver,
    middleGrey,
    openShadow,
    darkDetail,
    texturedBlack,
    nearBlack,
    cinemaCharcoal,
    allBlack,
    taupeMist,
    taupeStone,
    taupeClay,
    taupeUmber,
  ];

  static Map<PhotoZone, List<CanvasSwatch>> get byZone {
    final map = <PhotoZone, List<CanvasSwatch>>{};
    for (final s in all) {
      map.putIfAbsent(s.zone, () => []).add(s);
    }
    return map;
  }

  static CanvasSwatch byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => defaultSwatch);
}
