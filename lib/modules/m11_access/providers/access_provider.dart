import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/input_utils.dart';

class AccessProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _genericDrugs = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get genericDrugs => _genericDrugs;
  bool get isLoading => _isLoading;

  // Facility types for nearby search
  static final List<Map<String, dynamic>> facilityTypes = [
    {
      'name': 'Hastane',
      'query': 'hastane',
      'icon': Icons.local_hospital,
      'color': const Color(0xFFD32F2F),
    },
    {
      'name': 'Eczane',
      'query': 'eczane',
      'icon': Icons.local_pharmacy,
      'color': const Color(0xFF2E7D32),
    },
    {
      'name': 'Aile Hekimi',
      'query': 'aile sağlık merkezi',
      'icon': Icons.person,
      'color': const Color(0xFF2A7D4F),
    },
    {
      'name': 'Acil Servis',
      'query': 'acil servis',
      'icon': Icons.emergency,
      'color': const Color(0xFFD32F2F),
    },
    {
      'name': 'Diş Hastanesi',
      'query': 'diş hastanesi',
      'icon': Icons.medical_services,
      'color': const Color(0xFF42A5F5),
    },
    {
      'name': 'Göz Hastanesi',
      'query': 'göz hastanesi',
      'icon': Icons.visibility,
      'color': const Color(0xFF5C6BC0),
    },
  ];

  // Emergency numbers
  static const Map<String, String> emergencyNumbers = {
    'Acil Çağrı Merkezi': '112',
    'Ruh Sağlığı Acil Desteği': '112',
    'MHRS': '182',
    'Sağlık Bakanlığı ALO': '184',
    'Zehir Danışma': '114',
    'Kadın Destek Hattı': '183',
  };

  String _searchQuery = '';

  /// Türkçe'ye duyarlı arama: "ibuprofen", "İBUPROFEN" ve "insulin"
  /// sırasıyla "İbuprofen" ve "İnsülin"i bulur. Dart'ın toLowerCase'i
  /// "I"yı "ı" yerine "i" yaptığı için önceki arama tutarsızdı.
  List<Map<String, dynamic>> get filteredDrugs {
    final q = InputUtils.normalizeForSearch(_searchQuery);
    if (q.isEmpty) return _genericDrugs;
    return _genericDrugs.where((d) {
      final haystack = InputUtils.normalizeForSearch(
        '${d['original'] ?? ''} ${d['generic'] ?? ''} ${d['use'] ?? ''}',
      );
      return haystack.contains(q);
    }).toList();
  }

  Future<void> init() async {
    await _loadDrugsFromJson();
  }

  Future<void> _loadDrugsFromJson() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/generic_drugs.json',
      );
      final data = json.decode(jsonString);
      _genericDrugs = List<Map<String, dynamic>>.from(data['drugs']);
    } catch (e) {
      debugPrint('Jenerik ilaç verisi yükleme hatası: $e');
      // Fallback: Boş liste, JSON yüklenemezse
      _genericDrugs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchDrugs(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> openMapsSearch(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final uri = Uri.parse('https://www.google.com/maps/search/$encodedQuery');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Harita açılamadı: $e');
    }
  }

  /// Arama başlatmayı dener ve gerçekten başlatılıp başlatılamadığını
  /// döndürür. Önceden launchUrl'nin false dönmesi (uygulama bulunamadı vb.)
  /// tamamen yutuluyordu; acil durum numaraları için bu, kullanıcının
  /// aramanın başarısız olduğunu hiç fark etmemesi anlamına gelebilir.
  Future<bool> callNumber(String number) async {
    try {
      final uri = Uri.parse('tel:$number');
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('Arama yapılamadı: $e');
      return false;
    }
  }

  Future<void> openMhrs() async {
    try {
      final uri = Uri.parse('https://mhrs.gov.tr');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('MHRS açılamadı: $e');
    }
  }
}
