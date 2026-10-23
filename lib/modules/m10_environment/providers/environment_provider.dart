import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../services/hive_service.dart';

typedef ApproximateLocation = ({double lat, double lon});

/// Hava kalitesi: Open-Meteo Hava Kalitesi API'si (CAMS verisi; anahtar
/// gerekmez). Önceden kullanıcıdan kendi IQAir API anahtarını alması
/// isteniyordu; sıradan bir kullanıcı için bu özellik fiilen çalışmıyordu.
///
/// Gizlilik: yalnızca yaklaşık konum kullanılır ve koordinatlar
/// gönderilmeden önce 0,1 dereceye (yaklaşık 10 km) yuvarlanır; başka hiçbir
/// veri gönderilmez.
class EnvironmentProvider extends ChangeNotifier {
  EnvironmentProvider({
    http.Client? client,
    Future<ApproximateLocation?> Function()? locate,
  }) : _client = client ?? http.Client(),
       _locate = locate ?? _approximateLocation;

  final http.Client _client;
  final Future<ApproximateLocation?> Function() _locate;

  int? _aqi;
  double? _pm25;
  String? _aqiError;
  bool _isLoadingAqi = false;
  List<dynamic> _firstAidGuides = [];

  int? get aqi => _aqi;
  double? get pm25 => _pm25;
  String? get aqiError => _aqiError;
  bool get isLoadingAqi => _isLoadingAqi;
  List<dynamic> get firstAidGuides => _firstAidGuides;

  static const String attribution =
      'Veri: Open-Meteo.com (CAMS), CC BY 4.0. Yaklaşık konumunuz için.';

  // Trafik güvenliği içerikleri (SDG 3.6)
  static const List<Map<String, dynamic>> trafficSafetyTips = [
    {
      'title': 'Emniyet Kemeri',
      'icon': Icons.airline_seat_recline_normal,
      'content':
          'Araçta ön ve arka koltukta emniyet kemeri takmak zorunludur. '
          'Emniyet kemeri kazalarda ölüm riskini %45 azaltır. '
          'Çocuklar için yaşa uygun oto koltuğu kullanılmalıdır.',
      'category': 'araç',
    },
    {
      'title': 'Hız Sınırları',
      'icon': Icons.speed,
      'content':
          'Şehir içi: 50 km/s, şehir dışı: 90 km/s, otoyol: 120 km/s. '
          'Hız her 1 km/s arttığında kaza riski %3 artar. '
          'Okul ve hastane çevrelerinde 30 km/s\'ye dikkat edin.',
      'category': 'araç',
    },
    {
      'title': 'Alkollü Araç Kullanmayın',
      'icon': Icons.no_drinks,
      'content':
          'Yasal alkol sınırı 0.50 promildir. '
          'Alkollü araç kullanımı kaza riskini 13 kat artırır. '
          'Az miktarda alkol bile tepki süresini ve karar vermeyi olumsuz etkiler.',
      'category': 'araç',
    },
    {
      'title': 'Telefon Kullanımı',
      'icon': Icons.phone_disabled,
      'content':
          'Araç kullanırken telefon tutmak yasaktır. '
          'Mesaj yazmak gözleri yoldan 5 saniye uzaklaştırır. '
          'Hands-free kullanımı bile dikkati %37 azaltır.',
      'category': 'araç',
    },
    {
      'title': 'Yaya Güvenliği',
      'icon': Icons.directions_walk,
      'content':
          'Yaya geçidinden karşıya geçin. '
          'Karanlıkta açık renkli veya yansıtıcı giysiler giyin. '
          'Kulaklık takmadan yürüyün, çevrenizi duyabilmeniz önemlidir.',
      'category': 'yaya',
    },
    {
      'title': 'Bisiklet Güvenliği',
      'icon': Icons.pedal_bike,
      'content':
          'Mutlaka kask takın (kafa yaralanma riskini %85 azaltır). '
          'Gece bisiklet sürerken ön beyaz, arka kırmızı ışık kullanın. '
          'Araç trafiğiyle aynı yönde sürün.',
      'category': 'bisiklet',
    },
    {
      'title': 'Çocuk Güvenliği',
      'icon': Icons.child_care,
      'content':
          '0-1 yaş: Arkaya bakan bebek koltuğu. '
          '1-4 yaş: İleriye bakan çocuk koltuğu. '
          '4-12 yaş: Yükseltici koltuk. Çocuklar 12 yaşına kadar arka koltukta oturmalıdır.',
      'category': 'araç',
    },
    {
      'title': 'Kötü Hava Koşulları',
      'icon': Icons.thunderstorm,
      'content':
          'Yağmur ve siste hızı %30 düşürün. '
          'Takip mesafesini iki katına çıkarın. '
          'Sis farlarını kullanın. Buzlanmada ani fren yapmayın.',
      'category': 'araç',
    },
  ];

  String get aqiLevel {
    if (_aqi == null) return '';
    if (_aqi! <= 50) return 'İyi';
    if (_aqi! <= 100) return 'Orta';
    if (_aqi! <= 150) return 'Hassas Gruplar İçin Sağlıksız';
    if (_aqi! <= 200) return 'Sağlıksız';
    if (_aqi! <= 300) return 'Çok Sağlıksız';
    return 'Tehlikeli';
  }

  Color get aqiColor => _aqi == null ? Colors.grey : colorFor(_aqi!);

  /// Standart AQI renk sırası: yeşil, sarı, turuncu, kırmızı, mor, bordo.
  /// Önceden 101-150 aralığı 51-100'den daha açık bir tonla gösteriliyor,
  /// kötüleşme renkte görünmüyordu.
  static Color colorFor(int aqi) {
    if (aqi <= 50) return const Color(0xFF2E7D32);
    if (aqi <= 100) return const Color(0xFFF9A825);
    if (aqi <= 150) return const Color(0xFFEF6C00);
    if (aqi <= 200) return const Color(0xFFD32F2F);
    if (aqi <= 300) return const Color(0xFF8E24AA);
    return const Color(0xFF880E4F);
  }

  String get aqiRecommendation {
    if (_aqi == null) return '';
    if (_aqi! <= 50) return 'Açık hava aktiviteleri için uygun.';
    if (_aqi! <= 100) {
      return 'Hassas bireyler uzun süreli dış mekan aktivitelerini sınırlamalı.';
    }
    if (_aqi! <= 150) {
      return 'Hassas gruplar (astım, yaşlılar, çocuklar) dışarı çıkmaktan kaçınmalı.';
    }
    if (_aqi! <= 200) {
      return 'Herkes dış mekan aktivitelerini azaltmalı. Maske takın.';
    }
    return 'Dışarı çıkmayın. Pencere ve kapıları kapalı tutun.';
  }

  Future<void> init() async {
    await _loadFirstAid();
    _loadCachedAqi();
  }

  Future<void> _loadFirstAid() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/first_aid.json',
      );
      final data = json.decode(jsonString);
      _firstAidGuides = data['guides'];
      notifyListeners();
    } catch (e) {
      debugPrint('İlk yardım verisi yükleme hatası: $e');
    }
  }

  void _loadCachedAqi() {
    final box = HiveService().getSettingsBox();
    final cached = box.get('cached_aqi');
    final time = DateTime.tryParse('${box.get('cached_aqi_time') ?? ''}');
    // Önbellek 1 saat geçerli.
    if (cached is num &&
        time != null &&
        DateTime.now().difference(time).inHours < 1) {
      _aqi = cached.round();
      _pm25 = (box.get('cached_pm25') as num?)?.toDouble();
    }
  }

  /// 0,1 derece (yaklaşık 10 km): hava kalitesi modelinin çözünürlüğü de
  /// bu düzeyde olduğu için daha hassas konum göndermeye gerek yok.
  static double roundCoordinate(double value) => (value * 10).round() / 10;

  static Future<ApproximateLocation?> _approximateLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
        return (lat: p.latitude, lon: p.longitude);
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : (lat: last.latitude, lon: last.longitude);
      }
    } catch (error) {
      debugPrint('Konum alınamadı: $error');
      return null;
    }
  }

  Future<void> fetchAqi() async {
    _isLoadingAqi = true;
    _aqiError = null;
    notifyListeners();

    try {
      final location = await _locate();
      if (location == null) {
        _aqiError =
            'Hava kalitesi için yaklaşık konumunuz gerekiyor. Konum iznini '
            'verip tekrar deneyin.';
        return;
      }
      final uri =
          Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
            'latitude': '${roundCoordinate(location.lat)}',
            'longitude': '${roundCoordinate(location.lon)}',
            'current': 'us_aqi,pm2_5',
            'timezone': 'auto',
          });
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}', uri);
      }
      final current =
          (json.decode(response.body) as Map<String, dynamic>)['current'];
      final aqi = (current is Map ? current['us_aqi'] as num? : null)?.round();
      if (aqi == null) {
        throw const FormatException('us_aqi yok');
      }
      _aqi = aqi;
      _pm25 = (current['pm2_5'] as num?)?.toDouble();
      await HiveService().getSettingsBox().putAll({
        'cached_aqi': _aqi,
        'cached_pm25': _pm25,
        'cached_aqi_time': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      debugPrint('Hava kalitesi alınamadı: $error');
      _loadCachedAqi();
      if (_aqi == null) {
        _aqiError =
            'Hava kalitesi verisi alınamadı. İnternet bağlantınızı kontrol '
            'edip tekrar deneyin.';
      }
    } finally {
      _isLoadingAqi = false;
      notifyListeners();
    }
  }
}
