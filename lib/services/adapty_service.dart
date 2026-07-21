import 'dart:io' show Platform;

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Adapty for mobile store + web (Stripe) access levels.
///
/// Desktop (Windows/macOS/Linux) and web builds skip native Adapty activation;
/// those platforms keep using IL- license keys from Stripe fulfillment.
class AdaptyService {
  /// Access level id configured in the Adapty dashboard (Products → Access levels).
  static const accessLevelId = 'instalay';

  /// Public SDK key from Adapty → App settings → General.
  /// Pass at build/run time: `--dart-define=ADAPTY_PUBLIC_SDK_KEY=public_live_...`
  static const publicSdkKey = String.fromEnvironment('ADAPTY_PUBLIC_SDK_KEY');

  bool _activated = false;
  bool _accessActive = false;
  String? _customerUserId;

  bool get isActivated => _activated;
  bool get hasAccess => _accessActive;
  String? get customerUserId => _customerUserId;

  /// Adapty's Flutter SDK targets iOS / Android store billing.
  bool get isStorePlatform {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS || Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  bool get canActivate =>
      isStorePlatform && publicSdkKey.isNotEmpty && !_activated;

  Future<void> activate({String? customerUserId}) async {
    if (!isStorePlatform || publicSdkKey.isEmpty) return;
    if (_activated) {
      if (customerUserId != null && customerUserId.isNotEmpty) {
        await identify(customerUserId);
      }
      return;
    }

    try {
      final config = AdaptyConfiguration(apiKey: publicSdkKey);
      if (customerUserId != null && customerUserId.isNotEmpty) {
        config.withCustomerUserId(customerUserId);
        _customerUserId = customerUserId;
      }
      await Adapty().activate(configuration: config);
      _activated = true;
      await refreshAccess();
    } catch (e, st) {
      debugPrint('Adapty activate failed: $e\n$st');
    }
  }

  Future<void> identify(String customerUserId) async {
    final id = customerUserId.trim();
    if (id.isEmpty || !_activated) return;
    try {
      await Adapty().identify(id);
      _customerUserId = id;
      await refreshAccess();
    } catch (e, st) {
      debugPrint('Adapty identify failed: $e\n$st');
    }
  }

  Future<void> logout() async {
    if (!_activated) return;
    try {
      await Adapty().logout();
      _customerUserId = null;
      _accessActive = false;
    } catch (e, st) {
      debugPrint('Adapty logout failed: $e\n$st');
    }
  }

  Future<void> refreshAccess() async {
    if (!_activated) {
      _accessActive = false;
      return;
    }
    try {
      final profile = await Adapty().getProfile();
      _accessActive =
          profile.accessLevels[accessLevelId]?.isActive ?? false;
    } catch (e, st) {
      debugPrint('Adapty getProfile failed: $e\n$st');
      _accessActive = false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_activated) return;
    try {
      await Adapty().restorePurchases();
      await refreshAccess();
    } catch (e, st) {
      debugPrint('Adapty restorePurchases failed: $e\n$st');
    }
  }
}
