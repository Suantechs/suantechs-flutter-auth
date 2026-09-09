import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suantechs_flutter_auth/suantechs_flutter_auth.dart';

SuantechsAuth clientAnswering(http.Response Function(http.Request) answer) =>
    SuantechsAuth(
      SuantechsAuthConfig(
        authBaseUrl: 'https://auth.test/api',
        clientId: 'app-test',
        redirectUri: 'com.suantechs.test://oauth/callback',
      ),
      httpClient: MockClient((req) async => answer(req)),
    );

String tokens({int? expiresIn = 900}) => jsonEncode({
      'user': {'id': 'u1', 'email': 'alguien@test.com'},
      'access_token': 'a1',
      'refresh_token': 'r1',
      'token_type': 'Bearer',
      if (expiresIn != null) 'expires_in': expiresIn,
    });

void main() {
  group('loginWithEmail', () {
    test('reads the token envelope and its expiry', () async {
      late Uri called;
      final auth = clientAnswering((req) {
        called = req.url;
        expect(jsonDecode(req.body)['email'], 'alguien@test.com');
        return http.Response(tokens(), 200);
      });

      final result =
          await auth.loginWithEmail(email: 'alguien@test.com', password: 'x');

      expect(called.path, '/api/auth/login');
      expect(result.accessToken, 'a1');
      expect(result.refreshToken, 'r1');
      expect(result.expiresIn, 900);
      expect(result.expiresAt.isAfter(DateTime.now()), isTrue);
    });

    test('no declared expiry counts as already expired, never as forever',
        () async {
      final auth = clientAnswering(
        (_) => http.Response(tokens(expiresIn: null), 200),
      );

      final result =
          await auth.loginWithEmail(email: 'alguien@test.com', password: 'x');

      // The caller refreshes on its next call. Treating it as valid forever is
      // a session that stops working with no way to notice.
      expect(result.expiresAt.isAfter(DateTime.now()), isFalse);
    });

    test('a wrong password is said in the user\'s language', () async {
      final auth = clientAnswering(
        // What the IdP actually answers.
        (_) =>
            http.Response(jsonEncode({'message': 'Invalid credentials'}), 401),
      );

      await expectLater(
        auth.loginWithEmail(email: 'alguien@test.com', password: 'mala'),
        throwsA(
          isA<SuantechsAuthException>()
              .having((e) => e.message, 'message',
                  'Correo o contraseña incorrectos.')
              .having((e) => e.code, 'code', 'invalid_credentials'),
        ),
      );
    });

    test('any other refusal keeps the server\'s own message', () async {
      final auth = clientAnswering(
        (_) => http.Response(
          jsonEncode({'message': 'Demasiados intentos.'}),
          429,
        ),
      );

      await expectLater(
        auth.loginWithEmail(email: 'alguien@test.com', password: 'x'),
        throwsA(
          isA<SuantechsAuthException>()
              .having((e) => e.message, 'message', 'Demasiados intentos.'),
        ),
      );
    });

    test('two-factor is recognised by its shape, not read as a bad response',
        () async {
      final auth = clientAnswering(
        (_) => http.Response(
          jsonEncode({'two_factor_required': true, 'partial_token': 'p1'}),
          200,
        ),
      );

      await expectLater(
        auth.loginWithEmail(email: 'alguien@test.com', password: 'x'),
        throwsA(
          isA<SuantechsAuthException>()
              .having((e) => e.code, 'code', 'two_factor_required'),
        ),
      );
    });
  });

  group('refresh y logout', () {
    test('refresh trades the token for a new pair', () async {
      late Uri called;
      final auth = clientAnswering((req) {
        called = req.url;
        expect(jsonDecode(req.body)['refresh_token'], 'r1');
        return http.Response(tokens(), 200);
      });

      final result = await auth.refresh('r1');

      expect(called.path, '/api/auth/refresh');
      expect(result.accessToken, 'a1');
    });

    test('logout never throws: a device with no network still signs out',
        () async {
      final auth = clientAnswering((_) => throw Exception('sin red'));

      await expectLater(auth.logout('r1'), completes);
    });
  });

  group('proveedores', () {
    test('an unknown provider keeps its place, without a mark', () {
      final provider = SuantechsProvider.of('okta');

      expect(provider.label, 'Okta');
      expect(provider.svg, isEmpty);
      // Dropping it would hide from somebody the only way their account has
      // of getting in.
      expect(provider.name, 'okta');
    });

    test('a known provider carries the platform mark', () {
      expect(SuantechsProvider.of('google').svg, contains('#4285F4'));
    });
  });
}
