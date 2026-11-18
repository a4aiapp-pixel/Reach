import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/community_catalog.dart';

void main() {
  test('activity categories are unique, short and contain legacy choices', () {
    expect(categories.first, 'All');
    expect(categories.toSet().length, categories.length);
    expect(categories.length, greaterThanOrEqualTo(20));
    expect(categories.every((c) => c.length <= 40 && c.isNotEmpty), isTrue);
    for (final old in const [
      'Technology', 'Learning', 'Career', 'Home & repairs',
      'Sports', 'Creative', 'Local knowledge', 'Other',
    ]) {
      expect(categories.contains(old), isTrue);
    }
  });

  test('starter groups are suggestions with valid classifications', () {
    expect(communityTemplates.length, greaterThanOrEqualTo(10));
    expect(communityTemplates.map((g) => g.name).toSet().length,
        communityTemplates.length);
    for (final group in communityTemplates) {
      expect(group.name.length, inInclusiveRange(3, 70));
      expect(group.description.length, lessThanOrEqualTo(240));
      expect(categories.contains(group.category), isTrue);
      expect(group.name.toLowerCase(), isNot(contains('official')));
    }
  });
}
