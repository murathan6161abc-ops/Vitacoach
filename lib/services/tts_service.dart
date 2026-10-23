import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Cihazın kendi metin-okuma motorunu kullanır (internet gerekmez).
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _turkishAvailable = true;

  /// Şu an konuşulan metnin kimliği; düğmelerin durumunu göstermek için.
  final ValueNotifier<String?> speakingId = ValueNotifier(null);

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final available = await _tts.isLanguageAvailable('tr-TR');
      _turkishAvailable = available == true;
      if (_turkishAvailable) await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() => speakingId.value = null);
      _tts.setCancelHandler(() => speakingId.value = null);
      _tts.setErrorHandler((_) => speakingId.value = null);
    } catch (error) {
      debugPrint('Metin okuma başlatılamadı: $error');
    }
  }

  /// Türkçe ses paketi yoksa false döner; çağıran kullanıcıyı bilgilendirir.
  Future<bool> speak(String text, {String id = 'default'}) async {
    await _init();
    try {
      await _tts.stop();
      if (speakingId.value == id) {
        speakingId.value = null;
        return true;
      }
      speakingId.value = id;
      final result = await _tts.speak(text);
      if (result != 1) speakingId.value = null;
      return _turkishAvailable && result == 1;
    } catch (error) {
      debugPrint('Metin okunamadı: $error');
      speakingId.value = null;
      return false;
    }
  }

  Future<void> stop() async {
    speakingId.value = null;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
