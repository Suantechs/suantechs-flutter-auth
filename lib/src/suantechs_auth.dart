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
}

/// Thrown when a social sign-in fails or is cancelled. [code] mirrors the
/// IdP's `error=oauth_*` / `two_factor_required` query values when present.
class SuantechsAuthException implements Exception {
  SuantechsAuthException(this.message, {this.code});
  final String message;
  final String? code;

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
    final error = returned.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      throw SuantechsAuthException(_messageForError(error), code: error);
    }

    if (returned.queryParameters['state'] != pkce.state) {
      throw SuantechsAuthException('Estado OAuth inválido.',
          code: 'invalid_state');
    }

    final code = returned.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw SuantechsAuthException('No se recibió el código de autorización.',
          code: 'oauth_no_code');
    }

    return _exchangeCode(code, pkce.verifier);
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
        return 'Tu cuenta tiene verificación en dos pasos, aún no disponible en la app.';
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
