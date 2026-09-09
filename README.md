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

## What it covers

| Camino | Método |
|---|---|
| Correo y contraseña | `loginWithEmail` |
| Cualquier proveedor social habilitado en el IdP | `signInWithProvider` (PKCE en el navegador) |
| Renovar la sesión | `refresh` |
| Cerrar sesión | `logout` (best effort) |
| Los botones con la marca de cada proveedor | `SuantechsSocialButtons` |

Los botones viven aquí a propósito: las marcas ya estaban en este paquete, el
dashboard web se pegó su propia copia de los SVG y la app de cocina dibujó
botones de texto. Un logo copiado dentro de una app es un logo que envejece
solo en esa app.

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
// result.user / result.accessToken / result.refreshToken / result.expiresAt

// …or with the account's own password, same envelope:
final session = await auth.loginWithEmail(email: email, password: password);
```

Y los botones, con la marca de cada proveedor:

```dart
SuantechsSocialButtons(
  providers: enabled,               // lo que devolvió fetchProviders()
  enabled: !busy,
  onSelected: (provider) => _enterWith(provider),
)
```

Un proveedor que el IdP encienda mañana y este paquete no conozca **se pinta
igual**, sin marca: esconderlo le quitaría a alguien la única forma que tiene
de entrar.

Dos cosas que el paquete decide por el consumidor, y conviene saber por qué:
un 401 se traduce al español (el IdP contesta «Invalid credentials» y estas
apps se leen en español), y un `expires_in` ausente cuenta como **ya vencido**
— así el consumidor refresca en la siguiente llamada en vez de arrastrar una
sesión que dejó de servir sin avisar.

The package does **not** persist the session — the host app integrates
`result.raw` with its own storage.

## Native setup (per consuming app)

Register a custom-scheme redirect (`<scheme>://oauth/callback`) and the matching
IdP client app.

- **iOS** `Info.plist`: add a `CFBundleURLTypes` entry for the scheme.
- **Android**: two things, and the second one is the one that bites.
  In `build.gradle(.kts)`, set
  `manifestPlaceholders["appAuthRedirectScheme"] = "<scheme>"`; then declare the
  callback activity **in your own `AndroidManifest.xml`**, because
  `flutter_web_auth_2` 5.x no longer ships it:

  ```xml
  <activity
      android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
      android:exported="true"
      android:taskAffinity="">
      <intent-filter android:label="flutter_web_auth_2">
          <action android:name="android.intent.action.VIEW" />
          <category android:name="android.intent.category.DEFAULT" />
          <category android:name="android.intent.category.BROWSABLE" />
          <data android:scheme="${appAuthRedirectScheme}" />
      </intent-filter>
  </activity>
  ```

  Without it nothing on the device claims the scheme: the IdP answers its 302,
  the browser has nowhere to send it, and the user is left looking at a **blank
  page with no error anywhere** — not in the app, not in the server log, which
  shows a perfectly healthy 302. The scheme itself must not contain an
  underscore: Android tolerates it, a URI scheme does not (RFC 3986), and an
  `applicationId` very often has one.
