import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suantechs_flutter_auth/suantechs_flutter_auth.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('paints one branded button per provider', (tester) async {
    final tapped = <String>[];

    await tester.pumpWidget(
      host(
        SuantechsSocialButtons(
          providers: const ['google', 'apple'],
          onSelected: tapped.add,
        ),
      ),
    );

    expect(find.text('Entrar con Google'), findsOneWidget);
    expect(find.text('Entrar con Apple'), findsOneWidget);

    await tester.tap(find.text('Entrar con Google'));
    expect(tapped, ['google']);
  });

  testWidgets('while a sign-in runs, a second tap cannot start another',
      (tester) async {
    final tapped = <String>[];

    await tester.pumpWidget(
      host(
        SuantechsSocialButtons(
          providers: const ['google'],
          onSelected: tapped.add,
          enabled: false,
        ),
      ),
    );

    await tester.tap(find.text('Entrar con Google'));
    expect(tapped, isEmpty);
  });

  testWidgets('no providers means no chrome at all', (tester) async {
    await tester.pumpWidget(
      host(SuantechsSocialButtons(providers: const [], onSelected: (_) {})),
    );

    expect(find.byType(OutlinedButton), findsNothing);
  });
}
