import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PKCE helpers (RFC 7636) and OAuth `state` generation — pure Dart for unit tests.
abstract final class LinxOauthPkce {
  static final _rand = Random.secure();

  /// 43–128 char verifier from unreserved characters.
  static String generateCodeVerifier({int length = 64}) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      buf.write(chars[_rand.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  static String codeChallengeS256(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static String generateState({int bytes = 16}) {
    final data = Uint8List(bytes);
    for (var i = 0; i < bytes; i++) {
      data[i] = _rand.nextInt(256);
    }
    return base64Url.encode(data).replaceAll('=', '');
  }

  /// Returns true when [returnedState] matches [expectedState] (constant-time-ish).
  static bool statesMatch(String? expectedState, String? returnedState) {
    if (expectedState == null || returnedState == null) return false;
    if (expectedState.length != returnedState.length) return false;
    var diff = 0;
    for (var i = 0; i < expectedState.length; i++) {
      diff |= expectedState.codeUnitAt(i) ^ returnedState.codeUnitAt(i);
    }
    return diff == 0;
  }
}
