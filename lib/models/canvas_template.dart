import 'canvas_config.dart';

class CanvasTemplate {
  const CanvasTemplate({
    required this.id,
    required this.name,
    required this.config,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final CanvasConfig config;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CanvasTemplate copyWith({
    String? name,
    CanvasConfig? config,
    DateTime? updatedAt,
  }) {
    return CanvasTemplate(
      id: id,
      name: name ?? this.name,
      config: config ?? this.config,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'config': config.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory CanvasTemplate.fromJson(Map<String, dynamic> json) {
    return CanvasTemplate(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      config: CanvasConfig.fromJson(
        Map<String, dynamic>.from(json['config'] as Map? ?? const {}),
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}
