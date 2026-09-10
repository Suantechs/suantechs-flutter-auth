import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  group('el dispositivo compartido pide elegir cuenta', () {
    test('por defecto no lo pide: en un teléfono es un toque de más', () {
      final cfg = SuantechsAuthConfig(
        authBaseUrl: 'https://auth.suantechs.com/api',
        clientId: 'urbanix-mobile',
        redirectUri: 'com.suantechs.urbanix://oauth/callback',
      );
      expect(cfg.askWhichAccount, isFalse);
    });

    test('una app que comparte dispositivo lo declara', () {
      final cfg = SuantechsAuthConfig(
        authBaseUrl: 'https://auth.suantechs.com/api',
        clientId: 'recash-kds',
        redirectUri: 'com.suantechs.recashkds://oauth/callback',
        askWhichAccount: true,
      );
      expect(cfg.askWhichAccount, isTrue);
    });
  });

  group('two_factor_required deja de ser un callejón sin salida', () {
    test('la excepción lleva el token parcial que el IdP devolvió', () {
      final e = SuantechsAuthException('x',
          code: 'two_factor_required', partialToken: 'pt-123');
      expect(e.code, 'two_factor_required');
      expect(e.partialToken, 'pt-123');
    });

    test('verifyTwoFactor canjea el código por una sesión', () async {
      late http.Request sent;
      final auth = SuantechsAuth(
        SuantechsAuthConfig(
          authBaseUrl: 'https://auth.suantechs.com/api',
          clientId: 'recash-kds',
          redirectUri: 'com.suantechs.recashkds://oauth/callback',
        ),
        httpClient: MockClient((r) async {
          sent = r;
          return http.Response(
            jsonEncode({
              'user': {'id': 'u1'},
              'access_token': 'at',
              'refresh_token': 'rt',
            }),
            200,
          );
        }),
      );

      final result =
          await auth.verifyTwoFactor(partialToken: 'pt-123', code: '123456');

      expect(sent.url.path, '/api/auth/2fa/verify');
      expect(
          jsonDecode(sent.body), {'partial_token': 'pt-123', 'code': '123456'});
      expect(result.accessToken, 'at');
    });

    /// Un código equivocado no es un fallo de red: el token parcial es de un
    /// solo uso, así que reintentar esta llamada no sirve — hay que volver a
    /// entrar.
    test('un código inválido se distingue de un fallo cualquiera', () async {
      final auth = SuantechsAuth(
        SuantechsAuthConfig(
          authBaseUrl: 'https://auth.suantechs.com/api',
          clientId: 'recash-kds',
          redirectUri: 'com.suantechs.recashkds://oauth/callback',
        ),
        httpClient: MockClient(
          (_) async => http.Response(jsonEncode({'message': 'Invalid'}), 422),
        ),
      );

      await expectLater(
        auth.verifyTwoFactor(partialToken: 'pt', code: '000000'),
        throwsA(isA<SuantechsAuthException>()
            .having((e) => e.code, 'code', 'two_factor_invalid_code')),
      );
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
