import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/services/safe_json_file.dart';

void main() {
  test('queues concurrent atomic writes to the same file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'instalay-safe-json-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}projects.json');
    await file.writeAsString('[]');

    await Future.wait([
      for (var i = 0; i < 25; i++)
        writeJsonFileAtomic(file, {
          'write': i,
          'payload': List<String>.filled(100, '$i'),
        }),
    ]);

    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(decoded['write'], 24);
    expect(
      directory.listSync().whereType<File>().map((entry) => entry.path),
      [file.path],
    );
  });
}
