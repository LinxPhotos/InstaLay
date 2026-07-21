import 'package:shared_preferences/shared_preferences.dart';

/// Linx Photos library auth (desktop pairing JWT) — separate from IL-/Adapty license.
class LinxAuthStore {
  static const _tokenKey = 'linx_desktop_access_token_v1';
  static const _baseKey = 'linx_api_base_url_v1';

  /// Default API origin; override via prefs or `--dart-define=LINX_API_BASE_URL=…`
  static const defaultApiBase = String.fromEnvironment(
    'LINX_API_BASE_URL',
    defaultValue: 'http://localhost:4321',
  );

  String? _accessToken;
  String _apiBase = defaultApiBase;

  String? get accessToken => _accessToken;
  String get apiBase => _apiBase.replaceAll(RegExp(r'/+$'), '');
  bool get isConnected => _accessToken != null && _accessToken!.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    _apiBase = prefs.getString(_baseKey) ?? defaultApiBase;
  }

  Future<void> saveSession({
    required String accessToken,
    String? apiBase,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = accessToken.trim();
    await prefs.setString(_tokenKey, _accessToken!);
    if (apiBase != null && apiBase.trim().isNotEmpty) {
      _apiBase = apiBase.trim().replaceAll(RegExp(r'/+$'), '');
      await prefs.setString(_baseKey, _apiBase);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _accessToken = null;
  }
}
