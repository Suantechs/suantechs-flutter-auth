/// Per-app configuration for [SuantechsAuth].
///
/// Every value is app-specific and is normally injected at build time via
/// `--dart-define` so the same package binary works across apps and
/// environments.
class SuantechsAuthConfig {
  SuantechsAuthConfig({
    required String authBaseUrl,
    required this.clientId,
    required this.redirectUri,
    this.askWhichAccount = false,
  }) : authBaseUrl = _stripTrailingSlash(authBaseUrl);

  /// Base URL of suantechs-auth, including the `/api` prefix.
  /// Example: `https://auth.suantechs.com/api`.
  final String authBaseUrl;

  /// The IdP client app id registered for this app (e.g. `urbanix-mobile`).
  final String clientId;

  /// The custom-scheme redirect registered for [clientId] in the IdP.
  /// Example: `com.suantechs.urbanix://oauth/callback`.
  final String redirectUri;

  /// Whether to make the provider ask which account, every time.
  ///
  /// Off by default: on a personal phone with one session it is a pointless
  /// extra tap. On a **shared device** — a kitchen tablet installed by one
  /// person and used by another — leaving the choice to the browser means
  /// staying signed in as whoever installed it, and that does not show up as
  /// an error: it shows up as a missing permission, days later.
  final bool askWhichAccount;

  /// Scheme portion of [redirectUri] — what `flutter_web_auth_2` listens on.
  /// For `com.suantechs.urbanix://oauth/callback` this is
  /// `com.suantechs.urbanix`.
  String get callbackUrlScheme {
    final scheme = Uri.parse(redirectUri).scheme;
    if (scheme.isEmpty) {
      throw ArgumentError(
        'redirectUri "$redirectUri" must include a custom scheme, '
        'e.g. com.suantechs.urbanix://oauth/callback',
      );
    }
    return scheme;
  }

  static String _stripTrailingSlash(String url) =>
      url.trim().replaceFirst(RegExp(r'/+$'), '');
}
