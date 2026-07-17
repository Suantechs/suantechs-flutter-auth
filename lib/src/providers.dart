/// Display metadata for a social identity provider supported by suantechs-auth.
class SuantechsProvider {
  const SuantechsProvider({
    required this.name,
    required this.label,
    required this.svg,
  });

  /// The provider key as returned by the IdP (`google`, `apple`, …).
  final String name;

  /// Human label for the button (`Continuar con …` is added by the app).
  final String label;

  /// Brand mark as a raw SVG string (24x24 viewBox), for `flutter_svg`.
  final String svg;
}

/// Local registry of every provider this package knows how to render.
///
/// The UI intersects this with [SuantechsAuth.fetchProviders] so only the
/// providers actually enabled for the app's `client_id` in the IdP are shown.
/// Enabling a new provider in the IdP requires no app change as long as it is
/// listed here.
const Map<String, SuantechsProvider> kSuantechsProviders = {
  'google': SuantechsProvider(
    name: 'google',
    label: 'Google',
    svg:
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">'
        '<path fill="#4285F4" d="M23.5 12.3c0-.8-.1-1.6-.2-2.3H12v4.5h6.5a5.6 5.6 0 0 1-2.4 3.7v3h3.9c2.3-2.1 3.5-5.2 3.5-8.9z"/>'
        '<path fill="#34A853" d="M12 24c3.2 0 5.9-1.1 7.9-2.9l-3.9-3c-1 .7-2.4 1.1-4 1.1-3 0-5.6-2-6.6-4.8H1.4v3C3.4 21.3 7.4 24 12 24z"/>'
        '<path fill="#FBBC05" d="M5.4 14.4a7.2 7.2 0 0 1 0-4.8v-3H1.4a12 12 0 0 0 0 10.8l4-3z"/>'
        '<path fill="#EA4335" d="M12 4.8c1.8 0 3.3.6 4.6 1.8l3.4-3.4C17.9 1.2 15.2 0 12 0 7.4 0 3.4 2.7 1.4 6.6l4 3C6.4 6.8 9 4.8 12 4.8z"/>'
        '</svg>',
  ),
  'apple': SuantechsProvider(
    name: 'apple',
    label: 'Apple',
    svg:
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">'
        '<path fill="#000000" d="M16.4 12.7c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.8-3.5.8-.7 0-1.8-.8-3-.8-1.5 0-2.9.9-3.7 2.3-1.6 2.7-.4 6.8 1.1 9 .7 1.1 1.6 2.3 2.7 2.3 1.1 0 1.5-.7 2.8-.7s1.6.7 2.8.7c1.2 0 1.9-1.1 2.6-2.2.8-1.2 1.2-2.4 1.2-2.5-.1 0-2.3-.9-2.3-3.6zM14.3 5.8c.6-.7 1-1.7.9-2.8-.9 0-2 .6-2.6 1.3-.6.6-1.1 1.7-1 2.7 1 .1 2-.5 2.7-1.2z"/>'
        '</svg>',
  ),
  'microsoft': SuantechsProvider(
    name: 'microsoft',
    label: 'Microsoft',
    svg:
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">'
        '<path fill="#F25022" d="M2 2h9.5v9.5H2z"/>'
        '<path fill="#7FBA00" d="M12.5 2H22v9.5h-9.5z"/>'
        '<path fill="#00A4EF" d="M2 12.5h9.5V22H2z"/>'
        '<path fill="#FFB900" d="M12.5 12.5H22V22h-9.5z"/>'
        '</svg>',
  ),
  'github': SuantechsProvider(
    name: 'github',
    label: 'GitHub',
    svg:
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">'
        '<path fill="#181717" d="M12 .5C5.7.5.5 5.7.5 12c0 5.1 3.3 9.4 7.9 10.9.6.1.8-.3.8-.6v-2c-3.2.7-3.9-1.5-3.9-1.5-.5-1.4-1.3-1.7-1.3-1.7-1.1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1 1.8 2.8 1.3 3.5 1 .1-.8.4-1.3.8-1.6-2.6-.3-5.3-1.3-5.3-5.8 0-1.3.5-2.3 1.2-3.1-.1-.3-.5-1.5.1-3.1 0 0 1-.3 3.3 1.2a11.5 11.5 0 0 1 6 0c2.3-1.5 3.3-1.2 3.3-1.2.6 1.6.2 2.8.1 3.1.8.8 1.2 1.8 1.2 3.1 0 4.5-2.7 5.5-5.3 5.8.4.4.8 1.1.8 2.2v3.3c0 .3.2.7.8.6 4.6-1.5 7.9-5.8 7.9-10.9C23.5 5.7 18.3.5 12 .5z"/>'
        '</svg>',
  ),
  'discord': SuantechsProvider(
    name: 'discord',
    label: 'Discord',
    svg:
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">'
        '<path fill="#5865F2" d="M20.3 4.4A19.8 19.8 0 0 0 15.4 3l-.2.5c1.6.4 2.9 1 4.2 1.8a13 13 0 0 0-11-.5l-.6.5c1.3-.7 2.6-1.3 4.2-1.8L11.8 3a19.8 19.8 0 0 0-4.9 1.4C3.2 9.9 2.2 15.3 2.7 20.6a20 20 0 0 0 6 3l.4-.6c-1-.4-1.9-.9-2.7-1.5l.7-.5a14.2 14.2 0 0 0 12.2 0l.7.5c-.8.6-1.7 1.1-2.7 1.5l.4.6a20 20 0 0 0 6-3c.6-6.1-1-11.5-3.4-16.2zM9.2 16.2c-1.2 0-2.1-1.1-2.1-2.4 0-1.3.9-2.4 2.1-2.4s2.2 1.1 2.1 2.4c0 1.3-.9 2.4-2.1 2.4zm5.6 0c-1.2 0-2.1-1.1-2.1-2.4 0-1.3.9-2.4 2.1-2.4s2.2 1.1 2.1 2.4c0 1.3-.9 2.4-2.1 2.4z"/>'
        '</svg>',
  ),
};
