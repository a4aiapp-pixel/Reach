import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/geo_places.dart';
import 'package:reach_network/reach_permission_intro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Offline GeoNames countries suggest filtered real place names', () async {
    await GeoDirectory.load();
    expect(GeoDirectory.ready, isTrue);
    expect(GeoDirectory.suggestCountries('pak').map((p) => p.name),
        contains('Pakistan'));
    expect(GeoDirectory.suggestCountries('unit').length,
        greaterThan(1));
    expect(GeoDirectory.canonicalCountry('UK'), 'United Kingdom');
    expect(GeoDirectory.canonicalCountry('usa'), 'United States');
    expect(GeoDirectory.isoForCountry('Pakistan'), 'PK');
  });

  test('City lookup follows country, supports prefix and name fragments', () async {
    await GeoDirectory.load();
    final lahore = GeoDirectory.suggestCities('lah', 'Pakistan');
    expect(lahore.map((p) => p.name), contains('Lahore'));
    expect(lahore.every((p) => p.iso == 'PK'), isTrue);
    final islamabad = GeoDirectory.suggestCities('slamab', 'Pakistan');
    expect(islamabad.map((p) => p.name), contains('Islamabad'));
    final london = GeoDirectory.suggestCities('lond', 'United Kingdom');
    expect(london.map((p) => p.name), contains('London'));
    expect(GeoDirectory.suggestCities('', 'Pakistan'), isEmpty);
    expect(GeoDirectory.suggestCities('zzzzzzzz', 'Pakistan'), isEmpty);
  });

  testWidgets('First-use permission screen permits skip without Android access',
      (tester) async {
    var skipped = false;
    await tester.pumpWidget(MaterialApp(home: ReachPermissionIntro(
      onEnableNearby: () async => true,
      onContinueWithout: () async { skipped = true; },
    )));
    expect(find.text('Enable approximate nearby discovery'), findsOneWidget);
    expect(find.text('Continue without location'), findsOneWidget);
    expect(find.text('Microphone and camera'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue without location'));
    await tester.tap(find.text('Continue without location'));
    await tester.pump();
    expect(skipped, isTrue);
  });
}
