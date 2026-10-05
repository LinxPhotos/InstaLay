import 'package:shared_preferences/shared_preferences.dart';

import 'linx_oauth.dart';

/// Linx Photos library auth (desktop / OAuth JWT) — separate from IL-/Adapty license.
class LinxAuthStore {
  static const _tokenKey = 'linx_desktop_access_token_v1';
  static const _refreshKey = 'linx_desktop_refresh_token_v1';
  static const _baseKey = 'linx_api_base_url_v1';
  static const _emailKey = 'linx_account_email_v1';
  static const _nameKey = 'linx_account_name_v1';

  /// Default API origin; override via prefs or `--dart-define=LINX_API_BASE_URL=…`
  static const defaultApiBase = String.fromEnvironment(
    'LINX_API_BASE_URL',
    defaultValue: 'http://localhost:4321',
  );

  String? _accessToken;
  String? _refreshToken;
  String _apiBase = defaultApiBase;
  String? _accountEmail;
  String? _accountName;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String get apiBase => _apiBase.replaceAll(RegExp(r'/+$'), '');
  bool get isConnected => _accessToken != null && _accessToken!.isNotEmpty;
  String? get accountEmail => _accountEmail;
  String? get accountName => _accountName;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshKey);
    _apiBase = prefs.getString(_baseKey) ?? defaultApiBase;
    _accountEmail = prefs.getString(_emailKey);
    _accountName = prefs.getString(_nameKey);
  }

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    String? apiBase,
    String? accountEmail,
    String? accountName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = accessToken.trim();
    await prefs.setString(_tokenKey, _accessToken!);
    if (refreshToken != null) {
      _refreshToken = refreshToken.trim();
      if (_refreshToken!.isEmpty) {
        await prefs.remove(_refreshKey);
        _refreshToken = null;
      } else {
        await prefs.setString(_refreshKey, _refreshToken!);
      }
    }
    if (apiBase != null && apiBase.trim().isNotEmpty) {
      _apiBase = apiBase.trim().replaceAll(RegExp(r'/+$'), '');
      await prefs.setString(_baseKey, _apiBase);
    }
    if (accountEmail != null) {
      _accountEmail = accountEmail.trim().isEmpty ? null : accountEmail.trim();
      if (_accountEmail == null) {
        await prefs.remove(_emailKey);
      } else {
        await prefs.setString(_emailKey, _accountEmail!);
      }
    }
    if (accountName != null) {
      _accountName = accountName.trim().isEmpty ? null : accountName.trim();
      if (_accountName == null) {
        await prefs.remove(_nameKey);
      } else {
        await prefs.setString(_nameKey, _accountName!);
      }
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
    _accessToken = null;
    _refreshToken = null;
    _accountEmail = null;
    _accountName = null;
  }

  /// OAuth sign-in; saves under the same access-token key used by the picker.
  Future<void> connectWithOauth() async {
    final tokens = await LinxOauth.signIn(apiBase: apiBase);
    await saveSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      apiBase: LinxOauth.resolveApiBase(apiBase),
    );
  }

  /// Revoke on the server when possible, then clear local tokens.
  Future<void> disconnect({bool revokeRemote = true}) async {
    final token = _refreshToken ?? _accessToken;
    final base = apiBase;
    if (revokeRemote && token != null && token.isNotEmpty) {
      await LinxOauth.revoke(
        apiBase: base,
        token: token,
        tokenTypeHint: _refreshToken != null ? 'refresh_token' : 'access_token',
      );
    }
    await clear();
  }
}
