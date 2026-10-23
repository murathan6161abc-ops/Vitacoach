import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/core/utils/input_utils.dart';

void main() {
  group('InputUtils.parseDecimal', () {
    test('Türkçe virgüllü ondalığı kabul eder', () {
      expect(InputUtils.parseDecimal('72,5'), 72.5);
      expect(InputUtils.parseDecimal(' 72.5 '), 72.5);
      expect(InputUtils.parseDecimal('1.250,5'), 1250.5);
      expect(InputUtils.parseDecimal('1,250.5'), 1250.5);
    });

    test('geçersiz girdide null döner', () {
      expect(InputUtils.parseDecimal(''), isNull);
      expect(InputUtils.parseDecimal('abc'), isNull);
      expect(InputUtils.parseDecimal(null), isNull);
    });

    test('parseInt virgüllü tam sayıyı yuvarlar', () {
      expect(InputUtils.parseInt('15'), 15);
      expect(InputUtils.parseInt('15,4'), 15);
      expect(InputUtils.parseInt('x'), isNull);
    });

    test('inRange aralık dışını reddeder', () {
      expect(InputUtils.inRange<double>(95, 20, 600), 95);
      expect(InputUtils.inRange<double>(0, 20, 600), isNull);
      expect(InputUtils.inRange<double>(null, 20, 600), isNull);
    });
  });

  group('InputUtils.normalizeForSearch', () {
    test('Türkçe büyük/küçük harf ve aksanları katlar', () {
      expect(
        InputUtils.normalizeForSearch('Izgara köfte'),
        InputUtils.normalizeForSearch('ızgara KÖFTE'),
      );
      expect(InputUtils.normalizeForSearch('İshal'), 'ishal');
      expect(InputUtils.normalizeForSearch('Çay'), 'cay');
      expect(
        InputUtils.normalizeForSearch('İnsülin Glarjin').contains('insulin'),
        isTrue,
      );
    });
  });

  test('Türkçe büyük harf', () {
    expect(InputUtils.upperTr('Kalp Krizi Şüphesi'), 'KALP KRİZİ ŞÜPHESİ');
    expect(InputUtils.upperTr('ılık'), 'ILIK');
  });
}
