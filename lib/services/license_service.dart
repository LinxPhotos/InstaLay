import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Universal lifetime license unlock (IL-···· keys from Stripe fulfillment).
class LicenseService {
  static const _prefsKey = 'instalay_license_v1';
  static const productSku = 'instalay-universal-lifetime';

  String? _licenseKey;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get isLicensed => _licenseKey != null && _licenseKey!.startsWith('IL-');
  String? get licenseKey => _licenseKey;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _licenseKey = prefs.getString(_prefsKey);
    } catch (_) {
      _licenseKey = null;
    }
    _loaded = true;
  }

  /// Accepts keys matching `IL-XXXX-XXXX-XXXX-XXXX` from website fulfillment.
  Future<bool> activate(String raw) async {
    final key = raw.trim().toUpperCase();
    final ok = RegExp(r'^IL-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$')
        .hasMatch(key);
    if (!ok) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, key);
    await prefs.setString(
      '${_prefsKey}_meta',
      jsonEncode({
        'sku': productSku,
        'activatedAt': DateTime.now().toIso8601String(),
        'platforms': 'windows,macos,linux,android,ios,web',
      }),
    );
    _licenseKey = key;
    return true;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _licenseKey = null;
  }
}
