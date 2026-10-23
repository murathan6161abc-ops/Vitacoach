import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../services/hive_service.dart';
import '../../../services/secure_storage_service.dart';

class EnvironmentProvider extends ChangeNotifier {
  int? _aqi;
  String? _aqiCity;
  String? _aqiError;
  bool _isLoadingAqi = false;
  List<dynamic> _firstAidGuides = [];

  int? get aqi => _aqi;
  String? get aqiCity => _aqiCity;
  String? get aqiError => _aqiError;
  bool get isLoadingAqi => _isLoadingAqi;
  List<dynamic> get firstAidGuides => _firstAidGuides;

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

  Color get aqiColor {
    if (_aqi == null) return Colors.grey;
    if (_aqi! <= 50) return const Color(0xFF2E7D32);
    if (_aqi! <= 100) return const Color(0xFFF57C00);
    if (_aqi! <= 150) return const Color(0xFFFF8A65);
    if (_aqi! <= 200) return const Color(0xFFD32F2F);
    if (_aqi! <= 300) return const Color(0xFFAB47BC);
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
    await _migrateLegacyApiKey();
    await _loadFirstAid();
    _loadCachedAqi();
  }

  Future<void> _migrateLegacyApiKey() async {
    final settingsBox = HiveService().getSettingsBox();
    final legacyKey = settingsBox.get('iqair_api_key');
    final secureStorage = SecureStorageService();
    final currentKey = await secureStorage.read(
      SecureStorageService.iqAirApiKey,
    );
    if (currentKey == null &&
        legacyKey is String &&
        legacyKey.trim().isNotEmpty) {
      await secureStorage.write(SecureStorageService.iqAirApiKey, legacyKey);
    }
    await settingsBox.delete('iqair_api_key');
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
    final cachedTime = box.get('cached_aqi_time');
    if (cached != null && cachedTime != null) {
      final time = DateTime.tryParse(cachedTime);
      // Cache valid for 1 hour
      if (time != null && DateTime.now().difference(time).inHours < 1) {
        _aqi = (cached as num?)?.round();
        _aqiCity = box.get('cached_aqi_city')?.toString();
      }
    }
  }

  Future<void> fetchAqi({String? apiKey}) async {
    _isLoadingAqi = true;
    _aqiError = null;
    notifyListeners();

    try {
      final key =
          apiKey?.trim() ??
          await SecureStorageService().read(SecureStorageService.iqAirApiKey);
      if (key == null || key.isEmpty) {
        _aqiError =
            'AQI verisi için IQAir API anahtarı gereklidir. Aşağıdaki düğmeden girebilirsiniz.';
        _isLoadingAqi = false;
        notifyListeners();
        return;
      }

      final response = await http
          .get(Uri.parse('https://api.airvisual.com/v2/nearest_city?key=$key'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // API sayıyı double olarak da döndürebilir; int alana doğrudan
          // atamak TypeError fırlatıp "servis kullanılamıyor" gösteriyordu.
          _aqi = (data['data']['current']['pollution']['aqius'] as num).round();
          _aqiCity = data['data']['city']?.toString();

          // Cache
          final box = HiveService().getSettingsBox();
          await box.put('cached_aqi', _aqi);
          await box.put('cached_aqi_city', _aqiCity);
          await box.put('cached_aqi_time', DateTime.now().toIso8601String());
        } else {
          _aqiError =
              'API yanıt hatası: ${data['data']?['message'] ?? 'Bilinmeyen hata'}';
        }
      } else if (response.statusCode == 429) {
        // Rate limit — fallback to cached data
        _loadCachedAqi();
        if (_aqi == null) {
          _aqiError =
              'API istek limiti aşıldı. Lütfen daha sonra tekrar deneyin.';
        }
      } else {
        _aqiError =
            'Hava kalitesi verisi alınamadı (HTTP ${response.statusCode}).';
      }
    } on TimeoutException {
      // Timeout fallback — try cache
      _loadCachedAqi();
      if (_aqi == null) {
        _aqiError =
            'Bağlantı zaman aşımına uğradı. İnternet bağlantınızı kontrol edin.';
      }
    } catch (e) {
      // Network error fallback — try cache
      _loadCachedAqi();
      if (_aqi == null) {
        _aqiError =
            'Hava kalitesi servisi şu an kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
      }
    } finally {
      _isLoadingAqi = false;
      notifyListeners();
    }
  }

  Future<void> setApiKey(String key) async {
    final normalized = key.trim();
    if (normalized.isEmpty) return;
    await SecureStorageService().write(
      SecureStorageService.iqAirApiKey,
      normalized,
    );
    await fetchAqi(apiKey: normalized);
  }
}
