import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'providers.dart';

/// The platform's sign-in buttons, brand marks included.
///
/// It lives here so no app has to keep its own copy of a provider's logo --
/// which is exactly what had happened: the marks were in this package, the
/// web dashboard had pasted its own, and the kitchen app had drawn plain
/// text buttons. A logo copied into an app is a logo that goes stale in that
/// app alone.
///
/// The look follows the host's `Theme`, so a product with its own palette
/// (recash's green, for one) stays itself; what this widget fixes is the mark,
/// the wording and the shape, which are the platform's.
class SuantechsSocialButtons extends StatelessWidget {
  const SuantechsSocialButtons({
    super.key,
    required this.providers,
    required this.onSelected,
    this.enabled = true,
    this.labelBuilder = _defaultLabel,
    this.minHeight = 52,
    this.spacing = 10,
  });

  /// Provider ids as the IdP returned them (`SuantechsAuth.fetchProviders`).
  /// Unknown ids are rendered too, without a mark.
  final List<String> providers;

  final ValueChanged<String> onSelected;

  /// False while a sign-in is already running, so a second tap cannot start a
  /// second browser round trip.
  final bool enabled;

  /// How the button reads. The default is Spanish because every product on
  /// this platform ships in Spanish; a host that needs another language
  /// passes its own.
  final String Function(SuantechsProvider provider) labelBuilder;

  final double minHeight;
  final double spacing;

  static String _defaultLabel(SuantechsProvider provider) =>
      'Entrar con ${provider.label}';

  /// The one title Apple's guidelines accept in Spanish for this button. It
  /// is not run through [labelBuilder]: a host wording of its own is exactly
  /// what App Review rejects (STP-369).
  static const appleLabel = 'Continuar con Apple';

  /// Apple first, then the rest in the IdP's order.
  ///
  /// App Store Review 4.8 and Apple's HIG ask that Sign in with Apple be at
  /// least as prominent as any other sign-in option: never smaller, never
  /// below them, and drawn in one of Apple's own styles. Same height as the
  /// others is how it stays "not smaller"; first is how it stays "not below".
  static List<SuantechsProvider> ordered(List<String> providers) {
    final views = providers.map(SuantechsProvider.of).toList();
    final apple = views.where((v) => v.name == 'apple').toList();
    return [...apple, ...views.where((v) => v.name != 'apple')];
  }

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();

    final views = ordered(providers);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < views.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          SizedBox(
            height: minHeight,
            width: double.infinity,
            child: views[i].name == 'apple'
                ? _AppleButton(
                    svg: views[i].svg,
                    onPressed: enabled ? () => onSelected('apple') : null,
                  )
                : OutlinedButton(
                    onPressed: enabled ? () => onSelected(views[i].name) : null,
                    child: _Content(
                      svg: views[i].svg,
                      label: labelBuilder(views[i]),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

/// Apple's black style on a light screen and its white style on a dark one
/// (HIG, "Sign in with Apple" buttons): the mark and the title take the
/// opposite colour, the corners follow the host's other buttons.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.svg, required this.onPressed});

  final String svg;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? Colors.white : Colors.black;
    final foreground = dark ? Colors.black : Colors.white;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: 0.4),
        disabledForegroundColor: foreground.withValues(alpha: 0.7),
      ),
      child: _Content(
        svg: svg,
        label: SuantechsSocialButtons.appleLabel,
        markColor: foreground,
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.svg, required this.label, this.markColor});

  final String svg;
  final String label;

  /// Repaints a single-colour mark (Apple's) to match its button.
  final Color? markColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (svg.isNotEmpty) ...[
          SvgPicture.string(
            svg,
            width: 22,
            height: 22,
            colorFilter: markColor == null
                ? null
                : ColorFilter.mode(markColor!, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
