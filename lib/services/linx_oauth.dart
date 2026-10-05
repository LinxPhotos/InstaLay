import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'linx_oauth_loopback_stub.dart'
    if (dart.library.io) 'linx_oauth_loopback_io.dart' as loopback;
import 'linx_oauth_pkce.dart';

class LinxOauthTokens {
  const LinxOauthTokens({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });

  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
}

class LinxOauthException implements Exception {
  LinxOauthException(this.message);
  final String message;
  @override
  String toString() => 'LinxOauthException: $message';
}

/// OAuth 2.0 Authorization Code + PKCE against linx.photos for client_id=instalay.
abstract final class LinxOauth {
  static const clientId = 'instalay';
  static const webCallbackPath = '/oauth/callback.html';
  static const nativeCallback = 'instalay://oauth/callback';
  static const productionApiBase = 'https://linx.photos';

  static String resolveApiBase(String storedOrDefault) {
    final trimmed = storedOrDefault.replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty || trimmed.contains('localhost:4321')) {
      if (kIsWeb || kReleaseMode) return productionApiBase;
    }
    return trimmed;
  }

  static Future<LinxOauthTokens> signIn({required String apiBase}) async {
    final base = resolveApiBase(apiBase);
    final verifier = LinxOauthPkce.generateCodeVerifier();
    final challenge = LinxOauthPkce.codeChallengeS256(verifier);
    final state = LinxOauthPkce.generateState();

    late final String redirectUri;
    late final Future<String> callbackFuture;

    if (kIsWeb) {
      redirectUri = '${Uri.base.origin}$webCallbackPath';
      final authorize = _authorizeUri(
        base: base,
        redirectUri: redirectUri,
        challenge: challenge,
        state: state,
      );
      callbackFuture = FlutterWebAuth2.authenticate(
        url: authorize.toString(),
        callbackUrlScheme: Uri.base.scheme,
        options: const FlutterWebAuth2Options(
          timeout: 300,
          windowName: 'linx-oauth',
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      redirectUri = nativeCallback;
      final authorize = _authorizeUri(
        base: base,
        redirectUri: redirectUri,
        challenge: challenge,
        state: state,
      );
      callbackFuture = FlutterWebAuth2.authenticate(
        url: authorize.toString(),
        callbackUrlScheme: 'instalay',
        options: const FlutterWebAuth2Options(timeout: 300),
      );
    } else {
      final started = await loopback.startOauthLoopback();
      redirectUri = started.redirectUri;
      callbackFuture = started.callbackUrl;
      final authorize = _authorizeUri(
        base: base,
        redirectUri: redirectUri,
        challenge: challenge,
        state: state,
      );
      final launched = await launchUrl(
        authorize,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw LinxOauthException('Could not open the browser for Linx sign-in');
      }
    }

    final callbackUrl = await callbackFuture;
    final returned = Uri.parse(callbackUrl);
    final err = returned.queryParameters['error'];
    if (err != null && err.isNotEmpty) {
      throw LinxOauthException(
        returned.queryParameters['error_description'] ?? err,
      );
    }
    final code = returned.queryParameters['code'];
    final returnedState = returned.queryParameters['state'];
    if (code == null || code.isEmpty) {
      throw LinxOauthException('Authorization response missing code');
    }
    if (!LinxOauthPkce.statesMatch(state, returnedState)) {
      throw LinxOauthException('OAuth state mismatch');
    }

    return _exchangeCode(
      apiBase: base,
      code: code,
      redirectUri: redirectUri,
      codeVerifier: verifier,
    );
  }

  static Uri _authorizeUri({
    required String base,
    required String redirectUri,
    required String challenge,
    required String state,
  }) {
    return Uri.parse('$base/oauth/authorize').replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
        'scope': 'linx.library.read',
      },
    );
  }

  static Future<void> revoke({
    required String apiBase,
    required String token,
    String? tokenTypeHint,
  }) async {
    final base = resolveApiBase(apiBase);
    try {
      await http.post(
        Uri.parse('$base/api/oauth/revoke'),
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'token_type_hint': ?tokenTypeHint,
        }),
      );
    } catch (_) {}
  }

  static Future<LinxOauthTokens> _exchangeCode({
    required String apiBase,
    required String code,
    required String redirectUri,
    required String codeVerifier,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/api/oauth/token'),
      headers: {
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'client_id': clientId,
        'code_verifier': codeVerifier,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw LinxOauthException(
        body['error_description']?.toString() ??
            body['error']?.toString() ??
            'Token exchange failed (${res.statusCode})',
      );
    }
    final access = (body['access_token'] ?? body['accessToken'])?.toString();
    if (access == null || access.isEmpty) {
      throw LinxOauthException('Token response missing access_token');
    }
    final refresh = (body['refresh_token'] ?? body['refreshToken'])?.toString();
    final expires = body['expires_in'] ?? body['expiresIn'];
    return LinxOauthTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresIn: expires is int ? expires : int.tryParse('$expires'),
    );
  }
}
