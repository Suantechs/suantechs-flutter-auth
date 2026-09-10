import 'dart:convert';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'pkce.dart';
import 'suantechs_auth_config.dart';

/// Result of a successful social sign-in: the raw token envelope returned by
/// `POST auth/token`, identical in shape to `auth/login`.
class SuantechsAuthResult {
  SuantechsAuthResult(this.raw);

  /// Decoded JSON body: `{ user, access_token, refresh_token, token_type,
  /// expires_in }`.
  final Map<String, dynamic> raw;

  Map<String, dynamic> get user => (raw['user'] as Map).cast<String, dynamic>();
  String? get accessToken => raw['access_token'] as String?;
  String? get refreshToken => raw['refresh_token'] as String?;

  /// Seconds the access token is good for, as the IdP declared it.
  int? get expiresIn => (raw['expires_in'] as num?)?.toInt();

  /// When the access token stops being accepted, as an instant this device can
  /// compare against. **Absent `expires_in` counts as already expired**: the
  /// caller then refreshes on its next call, which costs one request and never
  /// costs a session that silently stops working.
  DateTime get expiresAt =>
      DateTime.now().add(Duration(seconds: expiresIn ?? 0));
}

/// Thrown when a social sign-in fails or is cancelled. [code] mirrors the
/// IdP's `error=oauth_*` / `two_factor_required` query values when present.
class SuantechsAuthException implements Exception {
  SuantechsAuthException(this.message, {this.code, this.partialToken});
  final String message;
  final String? code;

  /// Present only with `two_factor_required`: the short-lived token that
  /// [SuantechsAuth.verifyTwoFactor] exchanges for a session once the person
  /// types their code. Without it a `two_factor_required` is a dead end, which
  /// is what left the owner of a shop — the one account that has 2FA — outside
  /// their own kitchen.
  final String? partialToken;

  @override
  String toString() => 'SuantechsAuthException(${code ?? '-'}): $message';
}

/// Client for the suantechs-auth OAuth2 PKCE browser flow.
///
/// The flow mirrors `@suantechs/angular-auth`: open
/// `auth/{provider}/redirect`, capture the `code` on the custom-scheme
/// callback, then exchange it at `auth/token`. Works for every provider the
/// IdP supports (google, apple, microsoft, github, discord) with one code path.
class SuantechsAuth {
  SuantechsAuth(this.config, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final SuantechsAuthConfig config;
  final http.Client _http;

  /// Providers enabled for this app's `client_id` in the IdP. Queried at
  /// runtime so toggling a provider in the IdP needs no rebuild.
  Future<List<String>> fetchProviders() async {
    final uri = Uri.parse('${config.authBaseUrl}/apps/config').replace(
      queryParameters: {'client_id': config.clientId},
    );
    final res = await _http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw SuantechsAuthException(
        'No se pudo cargar la configuración de proveedores (${res.statusCode}).',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final providers = body['providers'];
    return providers is List ? providers.cast<String>() : <String>[];
  }

  /// Signs in with the account's own email and password.
  ///
  /// Not every account has one -- an owner who signed up with Google never set
  /// a password -- but many do, and a device that is not a person's phone (a
  /// kitchen tablet, a counter terminal) is better off with the shop's own
  /// account than with somebody's Google session. Same envelope as the social
  /// flow, so everything after this point is one code path.
  Future<SuantechsAuthResult> loginWithEmail({
    required String email,
    required String password,
  }) =>
      _postForTokens('/auth/login', {'email': email, 'password': password});

  /// Trades a refresh token for a fresh pair.
  ///
  /// A failure here ends the session: there is nothing left to try that does
  /// not involve a person typing something.
  Future<SuantechsAuthResult> refresh(String refreshToken) =>
      _postForTokens('/auth/refresh', {'refresh_token': refreshToken});

  /// Ends the session on the server. Best effort on purpose: the caller drops
  /// the session locally whatever this answers, so a device with no network
  /// can still sign out.
  Future<void> logout(String refreshToken) async {
    try {
      await _http
          .post(
            Uri.parse('${config.authBaseUrl}/auth/logout'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Nothing to do about it, and nothing worth telling the user.
    }
  }

  Future<SuantechsAuthResult> _postForTokens(
    String path,
    Map<String, dynamic> body,
  ) async {
    late final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('${config.authBaseUrl}$path'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw SuantechsAuthException(
        'No se pudo hablar con el servidor de cuentas.',
        code: 'network',
      );
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw SuantechsAuthException(
        'El servidor de cuentas respondió algo inesperado.',
        code: 'bad_response',
      );
    }

    if (res.statusCode >= 400) {
      // A 401 is said in our own words: the IdP answers "Invalid credentials"
      // in English, and these apps are read in Spanish. Every other status
      // keeps the server's message, which carries information this package
      // does not have.
      throw SuantechsAuthException(
        res.statusCode == 401
            ? 'Correo o contraseña incorrectos.'
            : json['message'] as String? ?? 'No se pudo iniciar sesión.',
        code: res.statusCode == 401 ? 'invalid_credentials' : 'login_failed',
      );
    }

    // An account with two-factor answers 200 with a partial token and no
    // session. Only the shape tells the two apart, and reading it as a
    // malformed response would tell somebody their password was wrong when it
    // was right.
    if (json['partial_token'] is String && json['access_token'] == null) {
      throw SuantechsAuthException(
        'Esta cuenta tiene verificación en dos pasos.',
        code: 'two_factor_required',
        partialToken: json['partial_token'] as String,
      );
    }

    return SuantechsAuthResult(json);
  }

  /// Runs the full PKCE flow for [provider] and returns the token envelope.
  ///
  /// Throws [SuantechsAuthException] on cancel/error (the caller can inspect
  /// [SuantechsAuthException.code], e.g. `two_factor_required`).
  Future<SuantechsAuthResult> signInWithProvider(String provider) async {
    final pkce = PkcePair.generate();

    final authorizeUrl =
        Uri.parse('${config.authBaseUrl}/auth/$provider/redirect').replace(
      queryParameters: {
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        'code_challenge': pkce.challenge,
        'code_challenge_method': 'S256',
        'state': pkce.state,
        // El IdP sólo lo reenvía al proveedor si vale exactamente esto
        // (AUTH-12). Sin él, con varias sesiones abiertas el navegador entrega
        // la cuenta activa y no pregunta — en un dispositivo compartido eso es
        // quedar dentro con la identidad de quien lo instaló.
        if (config.askWhichAccount) 'prompt': 'select_account',
      },
    );

    final String callback;
    try {
      callback = await FlutterWebAuth2.authenticate(
        url: authorizeUrl.toString(),
        callbackUrlScheme: config.callbackUrlScheme,
      );
    } catch (_) {
      // User dismissed the browser sheet, or the OS cancelled it.
      throw SuantechsAuthException('Inicio de sesión cancelado.',
          code: 'cancelled');
    }

    final returned = Uri.parse(callback);

    // El estado se comprueba antes que nada, incluso antes del error: lo que
    // vuelve por un esquema propio lo pudo escribir cualquiera, y más abajo
    // esta respuesta entrega un token parcial. Comprobarlo después del error
    // dejaba fuera de la verificación justo al camino que trae ese token.
    if (returned.queryParameters['state'] != pkce.state) {
      throw SuantechsAuthException('Estado OAuth inválido.',
          code: 'invalid_state');
    }

    final error = returned.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      throw SuantechsAuthException(
        _messageForError(error),
        code: error,
        partialToken: returned.queryParameters['partial_token'],
      );
    }

    final code = returned.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw SuantechsAuthException('No se recibió el código de autorización.',
          code: 'oauth_no_code');
    }

    return _exchangeCode(code, pkce.verifier);
  }

  /// Completes a `two_factor_required` with the code the person typed.
  ///
  /// Same envelope as any other sign-in, so the caller stores the session the
  /// way it already does. The IdP spends the partial token **only when the
  /// code works**, so a typo is retried right here — asking the person to go
  /// through the browser again for a mistyped digit would be the app's fault,
  /// not theirs. What does run out is the clock: the token lives a few
  /// minutes, and after that the sign-in starts over.
  Future<SuantechsAuthResult> verifyTwoFactor({
    required String partialToken,
    required String code,
  }) async {
    final res = await _http
        .post(
          Uri.parse('${config.authBaseUrl}/auth/2fa/verify'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'partial_token': partialToken, 'code': code}),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 422 || res.statusCode == 401) {
      throw SuantechsAuthException('Código incorrecto o vencido.',
          code: 'two_factor_invalid_code');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SuantechsAuthException(
        'No se pudo verificar el código (${res.statusCode}).',
        code: 'two_factor_verify_failed',
      );
    }
    return SuantechsAuthResult(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SuantechsAuthResult> _exchangeCode(
    String code,
    String verifier,
  ) async {
    final res = await _http
        .post(
          Uri.parse('${config.authBaseUrl}/auth/token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_id': config.clientId,
            'code': code,
            'redirect_uri': config.redirectUri,
            'code_verifier': verifier,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SuantechsAuthException(
        'No se pudo completar el inicio de sesión (${res.statusCode}).',
        code: 'token_exchange_failed',
      );
    }
    return SuantechsAuthResult(jsonDecode(res.body) as Map<String, dynamic>);
  }

  String _messageForError(String code) {
    switch (code) {
      case 'two_factor_required':
        return 'Tu cuenta pide un código de verificación.';
      case 'oauth_access_denied':
        return 'Inicio de sesión cancelado.';
      case 'oauth_authentication_failed':
      case 'oauth_failed':
        return 'Error al iniciar sesión con el proveedor. Intenta de nuevo.';
      case 'oauth_unsupported_provider':
        return 'Proveedor no soportado.';
      case 'oauth_no_code':
        return 'No se recibió el código de autorización.';
      default:
        return 'Error de autenticación.';
    }
  }
}
