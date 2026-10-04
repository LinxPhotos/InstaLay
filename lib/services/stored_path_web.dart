import 'app_storage.dart';

Future<bool> storedPathExists(String path) => AppStorage.exists(path);
