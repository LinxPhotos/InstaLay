import 'color_swatches.dart';

/// A set of related matte chips (e.g. Zone VIII, Taupes).
class SwatchGroup {
  const SwatchGroup({
    required this.id,
    required this.name,
    required this.swatches,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
  final List<CanvasSwatch> swatches;

  SwatchGroup copyWith({
    String? name,
    String? description,
    List<CanvasSwatch>? swatches,
  }) =>
      SwatchGroup(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        swatches: swatches ?? this.swatches,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'swatches': swatches.map((s) => s.toJson()).toList(),
      };

  factory SwatchGroup.fromJson(Map<String, dynamic> json) => SwatchGroup(
        id: json['id'] as String? ?? 'group',
        name: json['name'] as String? ?? 'Group',
        description: json['description'] as String?,
        swatches: [
          for (final e in (json['swatches'] as List? ?? const []))
            CanvasSwatch.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
}

/// Outer container for related groups (e.g. Zone system). Shown with a border.
class SwatchCollection {
  const SwatchCollection({
    required this.id,
    required this.name,
    required this.groups,
    this.description,
    this.builtin = false,
  });

  final String id;
  final String name;
  final String? description;
  final List<SwatchGroup> groups;
  final bool builtin;

  SwatchCollection copyWith({
    String? name,
    String? description,
    List<SwatchGroup>? groups,
  }) =>
      SwatchCollection(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        groups: groups ?? this.groups,
        builtin: builtin,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'groups': groups.map((g) => g.toJson()).toList(),
      };

  factory SwatchCollection.fromJson(Map<String, dynamic> json) =>
      SwatchCollection(
        id: json['id'] as String? ?? 'collection',
        name: json['name'] as String? ?? 'Collection',
        description: json['description'] as String?,
        groups: [
          for (final e in (json['groups'] as List? ?? const []))
            SwatchGroup.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
}

/// Full matte browser layout: collections + standalone groups (Taupes, customs).
class MattePalette {
  const MattePalette({
    required this.collections,
    required this.standaloneGroups,
  });

  final List<SwatchCollection> collections;
  final List<SwatchGroup> standaloneGroups;

  Iterable<CanvasSwatch> get allSwatches sync* {
    for (final c in collections) {
      for (final g in c.groups) {
        yield* g.swatches;
      }
    }
    for (final g in standaloneGroups) {
      yield* g.swatches;
    }
  }

  CanvasSwatch? findById(String id) {
    for (final s in allSwatches) {
      if (s.id == id) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'collections': collections.map((c) => c.toJson()).toList(),
        'standaloneGroups': standaloneGroups.map((g) => g.toJson()).toList(),
      };

  factory MattePalette.fromJson(Map<String, dynamic> json) => MattePalette(
        collections: [
          for (final e in (json['collections'] as List? ?? const []))
            SwatchCollection.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        standaloneGroups: [
          for (final e in (json['standaloneGroups'] as List? ?? const []))
            SwatchGroup.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );

  /// Built-in Zone system collection + Taupes as a free-standing group.
  static MattePalette builtins() {
    final byZone = CanvasSwatchCatalog.byZone;
    final zoneGroups = <SwatchGroup>[
      for (final zone in PhotoZone.values)
        if (zone != PhotoZone.taupe && byZone.containsKey(zone))
          SwatchGroup(
            id: 'zone_${zone.name}',
            name: zone.label,
            description: zone.description,
            swatches: byZone[zone]!,
          ),
    ];
    final taupeSwatches = byZone[PhotoZone.taupe] ?? const <CanvasSwatch>[];
    return MattePalette(
      collections: [
        SwatchCollection(
          id: 'zone_system',
          name: 'Zone system',
          description: 'Adams greyscale zones for photographic mattes',
          groups: zoneGroups,
          builtin: true,
        ),
      ],
      standaloneGroups: [
        if (taupeSwatches.isNotEmpty)
          SwatchGroup(
            id: 'taupes',
            name: PhotoZone.taupe.label,
            description: PhotoZone.taupe.description,
            swatches: taupeSwatches,
          ),
      ],
    );
  }

  /// Merge builtins with user-defined extras (user collections never replace Zone system).
  static MattePalette merge(MattePalette builtins, MattePalette? custom) {
    if (custom == null) return builtins;

    final zoneExtras = custom.collections
        .where((c) => c.id == 'zone_system_extra')
        .expand((c) => c.groups)
        .toList();

    final collections = <SwatchCollection>[
      for (final c in builtins.collections)
        if (c.id == 'zone_system' && zoneExtras.isNotEmpty)
          c.copyWith(groups: [...c.groups, ...zoneExtras])
        else
          c,
      for (final c in custom.collections)
        if (c.id != 'zone_system' && c.id != 'zone_system_extra') c,
    ];

    // Fold `groupId__user` extras into matching builtin/standalone groups.
    final extrasByParent = <String, List<CanvasSwatch>>{};
    final plainStandalone = <SwatchGroup>[];
    for (final g in custom.standaloneGroups) {
      if (g.id == 'taupes') continue;
      if (g.id.endsWith('__user')) {
        final parent = g.id.substring(0, g.id.length - '__user'.length);
        extrasByParent.putIfAbsent(parent, () => []).addAll(g.swatches);
      } else {
        plainStandalone.add(g);
      }
    }

    List<SwatchGroup> withExtras(List<SwatchGroup> groups) => [
          for (final g in groups)
            extrasByParent.containsKey(g.id)
                ? g.copyWith(
                    swatches: [...g.swatches, ...extrasByParent[g.id]!],
                  )
                : g,
        ];

    return MattePalette(
      collections: [
        for (final c in collections) c.copyWith(groups: withExtras(c.groups)),
      ],
      standaloneGroups: [
        ...withExtras(builtins.standaloneGroups),
        ...plainStandalone,
      ],
    );
  }
}
