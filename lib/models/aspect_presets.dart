/// Named aspect ratios commonly needed for IG feed, stories, and custom frames.
class AspectPreset {
  const AspectPreset({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    this.subtitle,
  });

  final String id;
  final String label;
  final int width;
  final int height;
  final String? subtitle;

  double get ratio => width / height;

  String get ratioLabel => '$width:$height';

  static const portrait45 = AspectPreset(
    id: 'ig_4_5',
    label: '4:5',
    width: 4,
    height: 5,
    subtitle: 'Instagram feed (max portrait)',
  );

  static const square = AspectPreset(
    id: 'ig_1_1',
    label: '1:1',
    width: 1,
    height: 1,
    subtitle: 'Square feed',
  );

  static const landscape169 = AspectPreset(
    id: 'ig_16_9',
    label: '16:9',
    width: 16,
    height: 9,
    subtitle: 'Landscape / Reel still',
  );

  static const story916 = AspectPreset(
    id: 'ig_9_16',
    label: '9:16',
    width: 9,
    height: 16,
    subtitle: 'Stories / Reels',
  );

  static const classic32 = AspectPreset(
    id: 'classic_3_2',
    label: '3:2',
    width: 3,
    height: 2,
    subtitle: 'Classic photo',
  );

  static const portrait23 = AspectPreset(
    id: 'classic_2_3',
    label: '2:3',
    width: 2,
    height: 3,
    subtitle: 'Portrait photo',
  );

  static const cinematic219 = AspectPreset(
    id: 'cine_21_9',
    label: '21:9',
    width: 21,
    height: 9,
    subtitle: 'Ultrawide cinematic',
  );

  static const all = <AspectPreset>[
    portrait45,
    square,
    landscape169,
    story916,
    classic32,
    portrait23,
    cinematic219,
  ];

  static AspectPreset byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => portrait45);

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'width': width,
        'height': height,
        'subtitle': subtitle,
      };

  factory AspectPreset.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id != null) {
      for (final p in all) {
        if (p.id == id) return p;
      }
    }
    return AspectPreset(
      id: id ?? 'custom',
      label: json['label'] as String? ?? 'Custom',
      width: json['width'] as int? ?? 4,
      height: json['height'] as int? ?? 5,
      subtitle: json['subtitle'] as String?,
    );
  }
}
