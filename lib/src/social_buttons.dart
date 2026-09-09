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

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();

    final views = providers.map(SuantechsProvider.of).toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < views.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          SizedBox(
            height: minHeight,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: enabled ? () => onSelected(views[i].name) : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (views[i].svg.isNotEmpty) ...[
                    SvgPicture.string(views[i].svg, width: 22, height: 22),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      labelBuilder(views[i]),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
