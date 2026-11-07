import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A PKCE (RFC 7636) verifier/challenge pair plus an anti-CSRF `state`.
class PkcePair {
  PkcePair({
    required this.verifier,
    required this.challenge,
    required this.state,
  });

  /// High-entropy random string sent (kept secret) to `auth/token`.
  final String verifier;

  /// `base64url(sha256(verifier))` sent to `auth/{provider}/redirect`.
  final String challenge;

  /// Opaque value echoed back on the callback to bind the round-trip.
  final String state;

  static const String _unreserved =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// Generates a fresh PKCE pair with a 64-char verifier and S256 challenge.
  factory PkcePair.generate() {
    final rng = Random.secure();
    String randomString(int length, String alphabet) => List.generate(
          length,
          (_) => alphabet[rng.nextInt(alphabet.length)],
        ).join();

    final verifier = randomString(64, _unreserved);
    final digest = sha256.convert(ascii.encode(verifier));
    final challenge = base64Url.encode(digest.bytes).replaceAll('=', '');
    final state = randomString(32, _unreserved);

    return PkcePair(verifier: verifier, challenge: challenge, state: state);
  }
}
