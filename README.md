# suantechs_flutter_auth

Reusable Flutter client for **suantechs-auth** (the suantechs IdP). It wraps the
OAuth2 **PKCE browser flow** (`ASWebAuthenticationSession` on iOS, Chrome Custom
Tabs on Android) so any suantechs app can offer social sign-in for **every
provider enabled in the IdP** — google, apple, microsoft, github, discord — with
a single code path and **no per-provider native wiring**.

It is the Dart mirror of `@suantechs/angular-auth`. Enabling a provider in the
IdP automatically lights it up in the app; nothing to recompile.

> Why browser PKCE and not native SDKs? GitHub and Discord have no native mobile
> SDK, and the IdP has no native id_token exchange endpoint. `ASWebAuthenticationSession`
> is the Apple-recommended pattern (it is **not** a `WebView`), so there is no
> extra App Review risk. Native Google/Apple SDKs can be added later as a UX
> enhancement once the IdP exposes token exchange.

## Usage

```dart
final auth = SuantechsAuth(
  SuantechsAuthConfig(
    authBaseUrl: 'https://auth.suantechs.com/api',
    clientId: 'urbanix-mobile',               // --dart-define=OAUTH_CLIENT_ID
    redirectUri: 'com.suantechs.urbanix://oauth/callback',
  ),
);

// 1. Discover which providers are enabled for this client_id (runtime).
final enabled = await auth.fetchProviders();   // ['google', 'apple', ...]
final views = enabled
    .where(kSuantechsProviders.containsKey)
    .map((p) => kSuantechsProviders[p]!)
    .toList();

// 2. Sign in. Returns the same envelope as POST auth/login.
final result = await auth.signInWithProvider('google');
// result.user / result.accessToken / result.refreshToken
```

The package does **not** persist the session — the host app integrates
`result.raw` with its own storage.

## Native setup (per consuming app)

Register a custom-scheme redirect (`<scheme>://oauth/callback`) and the matching
IdP client app.

- **iOS** `Info.plist`: add a `CFBundleURLTypes` entry for the scheme.
- **Android** `build.gradle(.kts)`: set
  `manifestPlaceholders["appAuthRedirectScheme"] = "<scheme>"` (consumed by
  `flutter_web_auth_2`'s callback activity).
