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
    expect(find.text('Continuar con Apple'), findsOneWidget);

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

  testWidgets('Apple va primero aunque el IdP lo mande después (STP-369)',
      (tester) async {
    await tester.pumpWidget(
      host(
        SuantechsSocialButtons(
          providers: const ['google', 'microsoft', 'apple'],
          onSelected: (_) {},
        ),
      ),
    );

    final apple = tester.getTopLeft(find.text('Continuar con Apple')).dy;
    final google = tester.getTopLeft(find.text('Entrar con Google')).dy;
    expect(apple, lessThan(google));
    expect(
      SuantechsSocialButtons.ordered(const ['google', 'apple', 'github'])
          .map((p) => p.name),
      ['apple', 'google', 'github'],
    );
  });

  testWidgets('Apple con su estilo negro y del mismo alto que los demás',
      (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 360,
          child: SuantechsSocialButtons(
            providers: const ['google', 'apple'],
            onSelected: tapped.add,
            labelBuilder: (p) => 'Usar ${p.label}',
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(
      button.style!.backgroundColor!.resolve(<WidgetState>{}),
      Colors.black,
    );
    // El título de Apple no lo cambia el host: es el que Apple acepta.
    expect(find.text('Continuar con Apple'), findsOneWidget);
    expect(find.text('Usar Google'), findsOneWidget);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      tester.getSize(find.byType(OutlinedButton)).height,
    );

    await tester.tap(find.text('Continuar con Apple'));
    expect(tapped, ['apple']);
  });

  testWidgets('en tema oscuro Apple pasa a su estilo blanco', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: SuantechsSocialButtons(
            providers: const ['apple'],
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(
      button.style!.backgroundColor!.resolve(<WidgetState>{}),
      Colors.white,
    );
  });
}
