import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'adapty_service.dart';

/// License unlock via IL-···· keys (Stripe web) and/or Adapty access levels (mobile).
class LicenseService {
  LicenseService({AdaptyService? adapty}) : _adapty = adapty ?? AdaptyService();

  static const _prefsKey = 'instalay_license_v1';
  static const productSku = 'instalay-universal-lifetime';

  final AdaptyService _adapty;

  String? _licenseKey;
  bool _loaded = false;

  AdaptyService get adapty => _adapty;

  bool get isLoaded => _loaded;

  /// True when an IL- key is stored **or** Adapty reports the `instalay` access level.
  bool get isLicensed => hasIlKey || _adapty.hasAccess;

  bool get hasIlKey =>
      _licenseKey != null && _licenseKey!.startsWith('IL-');

  String? get licenseKey => _licenseKey;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _licenseKey = prefs.getString(_prefsKey);
    } catch (_) {
      _licenseKey = null;
    }
    await _adapty.activate();
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

  /// Link this install to a Stripe/Adapty customer (usually buyer email).
  Future<void> identifyCustomer(String customerUserId) async {
    await _adapty.activate(customerUserId: customerUserId);
    if (_adapty.isActivated) {
      await _adapty.identify(customerUserId);
    }
  }

  Future<void> restorePurchases() => _adapty.restorePurchases();

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _licenseKey = null;
    await _adapty.logout();
  }
}
