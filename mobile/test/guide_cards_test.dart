import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('each exercise without motion has an original static guide card', () async {
    final catalog = (jsonDecode(await rootBundle.loadString('assets/catalog.json')) as List)
        .cast<Map<String, dynamic>>();
    final motions = jsonDecode(await rootBundle.loadString('assets/motion_index.json')) as Map;
    final guides = jsonDecode(await rootBundle.loadString('assets/guide_index.json')) as Map;
    for (final exercise in catalog) {
      final id = exercise['id'] as String;
      if (motions.containsKey(id)) continue;
      expect(guides.containsKey(id), isTrue, reason: 'Missing visual guide for $id');
      final path = guides[id] as String;
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(100), reason: 'Empty visual guide: $path');
    }
  });
}
