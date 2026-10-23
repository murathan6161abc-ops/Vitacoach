import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vitacoach/modules/m10_environment/providers/environment_provider.dart';
import 'package:vitacoach/services/hive_service.dart';

import 'helpers/memory_hive.dart';

// Open-Meteo yanıtının gerçek biçimi (24.10.2026, İstanbul).
const _sample =
    '{"latitude":41.0,"longitude":29.0,"current":{"time":"2026-10-24T00:00",'
    '"interval":3600,"us_aqi":85,"pm2_5":7.2}}';

void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  test('API anahtarı olmadan, yuvarlanmış yaklaşık konumla sorgular', () async {
    Uri? requested;
    final provider = EnvironmentProvider(
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(_sample, 200);
      }),
      locate: () async => (lat: 41.01234, lon: 28.98765),
    );

    await provider.fetchAqi();

    expect(provider.aqi, 85);
    expect(provider.pm25, 7.2);
    expect(provider.aqiError, isNull);
    expect(requested!.host, 'air-quality-api.open-meteo.com');
    expect(requested!.queryParameters['latitude'], '41.0');
    expect(requested!.queryParameters['longitude'], '29.0');
    expect(requested!.toString(), isNot(contains('key')));
    expect(HiveService().getSettingsBox().get('cached_aqi'), 85);
  });

  test('konum yoksa istek atılmaz ve neden söylenir', () async {
    var calls = 0;
    final provider = EnvironmentProvider(
      client: MockClient((_) async {
        calls++;
        return http.Response(_sample, 200);
      }),
      locate: () async => null,
    );

    await provider.fetchAqi();

    expect(calls, 0);
    expect(provider.aqi, isNull);
    expect(provider.aqiError, contains('konum'));
  });

  test('servis hata verirse anlaşılır mesaj gösterilir', () async {
    final provider = EnvironmentProvider(
      client: MockClient((_) async => http.Response('oops', 503)),
      locate: () async => (lat: 41.0, lon: 29.0),
    );

    await provider.fetchAqi();

    expect(provider.aqi, isNull);
    expect(provider.aqiError, contains('alınamadı'));
  });

  test('renk ölçeği kötüleştikçe koyulaşır (sarı -> turuncu)', () {
    expect(
      EnvironmentProvider.colorFor(75),
      isNot(EnvironmentProvider.colorFor(125)),
    );
    expect(EnvironmentProvider.colorFor(75).toARGB32(), 0xFFF9A825);
    expect(EnvironmentProvider.colorFor(125).toARGB32(), 0xFFEF6C00);
  });
}
