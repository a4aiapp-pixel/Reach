import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/reach_themes.dart';

void main() {
  test('Every visual style has a distinct stable identifier and palette', () {
    expect(reachLooks.length, 10);
    expect(reachLooks.map((x) => x.id).toSet().length, reachLooks.length);
    expect(reachLooks.map((x) => x.seed.toARGB32()).toSet().length,
        reachLooks.length);
    for (final look in reachLooks) {
      expect(look.build(Brightness.light).brightness, Brightness.light);
      expect(look.build(Brightness.dark).brightness, Brightness.dark);
      expect(look.build(Brightness.light).useMaterial3, isTrue);
      expect(look.build(Brightness.light).navigationBarTheme.height,
          greaterThanOrEqualTo(64));
      expect(look.build(Brightness.light).scaffoldBackgroundColor,
          isNot(equals(Colors.transparent)));
      expect(reachLookById(look.id).name, look.name);
    }
  });

  testWidgets('Appearance gallery renders named styles and can select one',
      (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(
      home: ReachThemeGallery(
        selected: 'aurora',
        onSelected: (id) => chosen = id,
      ),
    ));
    expect(find.text('Design studio'), findsOneWidget);
    expect(find.text('Aurora'), findsOneWidget);
    expect(find.text('Editorial'), findsOneWidget);
    await tester.tap(find.text('Editorial'));
    await tester.pump();
    expect(chosen, 'editorial');
  });
}
