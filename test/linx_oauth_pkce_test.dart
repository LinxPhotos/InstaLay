import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/services/linx_oauth_pkce.dart';

void main() {
  group('LinxOauthPkce', () {
    test('code verifier length and charset', () {
      final v = LinxOauthPkce.generateCodeVerifier();
      expect(v.length, greaterThanOrEqualTo(43));
      expect(v.length, lessThanOrEqualTo(128));
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(v), isTrue);
    });

    test('S256 challenge is stable for a verifier', () {
      const verifier = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJK';
      final a = LinxOauthPkce.codeChallengeS256(verifier);
      final b = LinxOauthPkce.codeChallengeS256(verifier);
      expect(a, equals(b));
      expect(a.contains('='), isFalse);
      expect(a.contains('+'), isFalse);
      expect(a.contains('/'), isFalse);
    });

    test('state match accepts equal values and rejects mismatches', () {
      final state = LinxOauthPkce.generateState();
      expect(LinxOauthPkce.statesMatch(state, state), isTrue);
      expect(LinxOauthPkce.statesMatch(state, 'other'), isFalse);
      expect(LinxOauthPkce.statesMatch(null, state), isFalse);
      expect(LinxOauthPkce.statesMatch(state, null), isFalse);
      expect(LinxOauthPkce.statesMatch('', ''), isTrue);
    });
  });
}
