import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/fonts/font_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppFont catalog', () {
    test('every non-system font asset exists and looks like a TTF', () async {
      for (final font in AppFont.values) {
        if (font == AppFont.system) continue;
        final data = await rootBundle.load(font.assetPath!);
        expect(data.lengthInBytes, greaterThan(1024 * 1024),
            reason: '${font.label} 字体文件过小');
        // TTF sfnt magic: 0x00010000 (TrueType) or 'OTTO' (CFF).
        final magic = data.getUint32(0);
        expect(
          magic == 0x00010000 || magic == 0x4F54544F,
          isTrue,
          reason: '${font.label} 不是有效的 TTF/OTF（magic=0x${magic.toRadixString(16)}）',
        );
      }
    });

    test('keys round-trip and system is the fallback', () {
      expect(AppFont.fromKey('lxgw'), AppFont.lxgw);
      expect(AppFont.fromKey(''), AppFont.system);
      expect(AppFont.fromKey('nonsense'), AppFont.system);
      expect(AppFont.system.familyName, isNull);
    });
  });

  group('FontService', () {
    test('loads the smallest font via FontLoader and is idempotent', () async {
      final service = FontService();
      expect(service.isLoaded(AppFont.wqwh), isFalse);

      await service.ensure(AppFont.wqwh);
      expect(service.isLoaded(AppFont.wqwh), isTrue);

      // Second call resolves without reloading.
      await service.ensure(AppFont.wqwh);
      expect(service.isLoaded(AppFont.wqwh), isTrue);

      // System font never needs loading.
      expect(service.isLoaded(AppFont.system), isTrue);
    });
  });
}
