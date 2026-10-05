import 'package:shared_preferences/shared_preferences.dart';

import 'update_policy_env_stub.dart'
    if (dart.library.io) 'update_policy_env_io.dart' as env;

/// SharedPreferences key for managed disable / notify-only policy.
const kUpdatePolicyPrefsKey = 'instalay_update_policy_v1';

/// Environment variable (also accepted as `UpdatePolicy` for IT muscle-memory).
const kUpdatePolicyEnvKey = 'INSTALAY_UPDATE_POLICY';

/// Values: `enabled` (default), `disabled`, `notify` (check only, never apply).
class UpdatePolicy {
  const UpdatePolicy(this.value);

  final String value;

  static const enabled = UpdatePolicy('enabled');
  static const disabled = UpdatePolicy('disabled');
  static const notify = UpdatePolicy('notify');

  bool get isDisabled => value == 'disabled';
  bool get allowApply => value == 'enabled';
  bool get allowCheck => value != 'disabled';

  static UpdatePolicy parse(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v == 'disabled' || v == 'off' || v == '0' || v == 'false') {
      return disabled;
    }
    if (v == 'notify' || v == 'check-only' || v == 'notifyonly') {
      return notify;
    }
    return enabled;
  }

  /// Env wins over SharedPreferences (fleet policy).
  static Future<UpdatePolicy> load({
    Map<String, String>? environment,
    SharedPreferences? prefs,
  }) async {
    final envMap = environment ?? env.processEnvironment();
    final fromEnv = envMap[kUpdatePolicyEnvKey] ?? envMap['UpdatePolicy'];
    if (fromEnv != null && fromEnv.trim().isNotEmpty) {
      return parse(fromEnv);
    }
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      return parse(p.getString(kUpdatePolicyPrefsKey));
    } catch (_) {
      return enabled;
    }
  }

  Future<void> persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(kUpdatePolicyPrefsKey, value);
    } catch (_) {}
  }
}
