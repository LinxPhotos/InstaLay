import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart';

import '../providers/app_providers.dart';

/// Keeps the HTML Linx pairing form and [LinxAuthStore] in sync on Flutter web.
abstract final class LinxWebAuthBridge {
  static bool _wired = false;

  static Future<void> install(WidgetRef ref) async {
    if (_wired) return;
    _wired = true;
    await _applyFromBrowserStorage(ref);
    void onAuthSaved(Event _) {
      unawaited(_applyFromBrowserStorage(ref));
    }

    window.addEventListener('instalay-linx-auth', onAuthSaved.toJS);
  }

  static Future<void> _applyFromBrowserStorage(WidgetRef ref) async {
    final token =
        window.localStorage.getItem('flutter.linx_desktop_access_token_v1');
    if (token == null || token.isEmpty) return;
    final base = window.localStorage.getItem('flutter.linx_api_base_url_v1');
    final store = ref.read(linxAuthStoreProvider);
    await store.saveSession(
      accessToken: token,
      apiBase: base,
    );
    ref.invalidate(linxAuthProvider);
  }
}
