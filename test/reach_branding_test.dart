import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/main.dart';

void main() {
  test('selected Reach icon has a valid WebP header and is in source', () {
    final asset = File('assets/branding/reach_selected_icon.webp');
    expect(asset.existsSync(), isTrue);
    final bytes = asset.readAsBytesSync();
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
  });

  testWidgets('in-app ReachMark uses the selected published artwork', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ReachMark(size: 72)),
    ));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName,
        'assets/branding/reach_selected_icon.webp');
    expect(image.width, 72);
    expect(image.height, 72);
    expect(tester.takeException(), isNull);
  });
}
