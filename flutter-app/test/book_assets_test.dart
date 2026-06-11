import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/data/datasources/local/book_assets.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bundled scripture assets', () {
    test('loads and parses 般若波罗蜜多心经 (0017)', () async {
      final asset = await BookAssets.tryLoad('0017');
      expect(asset, isNotNull, reason: 'assets/books/0017.json.gz 应已打包');

      final meta = BookMeta.fromJson(
        jsonDecode(asset!.metaJson) as Map<String, dynamic>,
      );
      expect(meta.title, contains('心经'));

      final juans = jsonDecode(asset.juansJson) as List<dynamic>;
      final blocks = juans
          .whereType<Map<String, dynamic>>()
          .map(JuanBlock.fromJson)
          .whereType<JuanBlock>()
          .toList();
      expect(blocks, isNotEmpty);
      final fullText = blocks.expand((b) => b.paragraphs).join();
      expect(fullText, contains('观自在菩萨'));
    });

    test('loads the largest volume without error (0001-01)', () async {
      final asset = await BookAssets.tryLoad('0001-01');
      expect(asset, isNotNull);
      final juans = jsonDecode(asset!.juansJson) as List<dynamic>;
      expect(juans.length, greaterThan(10));
    });

    test('returns null for a non-existent volume id', () async {
      expect(await BookAssets.tryLoad('no-such-book'), isNull);
    });
  });
}
