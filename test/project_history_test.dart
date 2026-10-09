import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/models/canvas_config.dart';
import 'package:instalay/models/project.dart';
import 'package:instalay/services/project_history.dart';

Project _minimalProject({String name = 'Test'}) {
  final now = DateTime(2026, 10, 9, 12);
  return Project(
    id: '11111111-1111-1111-1111-111111111111',
    name: name,
    createdAt: now,
    updatedAt: now,
    activeVersionId: 'v1',
    versions: [
      ProjectVersion(
        id: 'v1',
        versionNumber: 1,
        activeLayoutId: 'l1',
        layouts: [
          LayoutCanvas(
            id: 'l1',
            name: 'Batch',
            config: const CanvasConfig(),
            photos: const [],
          ),
        ],
        createdAt: now,
      ),
    ],
  );
}

void main() {
  test('projectDataEquals ignores updatedAt', () {
    final a = _minimalProject();
    final b = a.copyWith(updatedAt: DateTime(2026, 10, 9, 13));
    expect(ProjectHistory.projectDataEquals(a, b), isTrue);
  });

  test('projectDataEquals detects name change', () {
    final a = _minimalProject();
    final b = a.copyWith(name: 'Other');
    expect(ProjectHistory.projectDataEquals(a, b), isFalse);
  });
}
