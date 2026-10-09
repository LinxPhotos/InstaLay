import 'app_storage.dart';

Future<bool> storedPathExists(String path) => AppStorage.exists(path);

Future<int?> storedPathModifiedMs(String path) async {
  final stat = await AppStorage.stat(path);
  if (stat == null) return null;
  final ms = stat.modifiedMs;
  return ms > 0 ? ms : null;
}
