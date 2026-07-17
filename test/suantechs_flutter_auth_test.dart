import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suantechs_flutter_auth/src/pkce.dart';
import 'package:suantechs_flutter_auth/suantechs_flutter_auth.dart';

void main() {
  group('PkcePair', () {
    test('verifier is 64 unreserved chars and unique', () {
      final a = PkcePair.generate();
      final b = PkcePair.generate();
      expect(a.verifier.length, 64);
      expect(RegExp(r'^[A-Za-z0-9\-._~]{64}$').hasMatch(a.verifier), isTrue);
      expect(a.verifier, isNot(b.verifier));
    });

    test('challenge is S256(verifier) base64url without padding', () {
      final p = PkcePair.generate();
      final expected = base64Url
          .encode(sha256.convert(ascii.encode(p.verifier)).bytes)
          .replaceAll('=', '');
      expect(p.challenge, expected);
      expect(p.challenge.contains('='), isFalse);
    });
  });

  group('SuantechsAuthConfig', () {
    test('strips trailing slash and derives callback scheme', () {
      final cfg = SuantechsAuthConfig(
        authBaseUrl: 'https://auth.suantechs.com/api/',
        clientId: 'urbanix-mobile',
        redirectUri: 'com.suantechs.urbanix://oauth/callback',
      );
      expect(cfg.authBaseUrl, 'https://auth.suantechs.com/api');
      expect(cfg.callbackUrlScheme, 'com.suantechs.urbanix');
    });
  });

  group('kSuantechsProviders', () {
    test('covers the five IdP providers', () {
      expect(
        kSuantechsProviders.keys.toSet(),
        {'google', 'apple', 'microsoft', 'github', 'discord'},
      );
    });
  });
}
