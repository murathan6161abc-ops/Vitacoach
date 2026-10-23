import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/speak_button.dart';
import '../../../shared/widgets/vc_card.dart';
import '../models/heart_measurement.dart';
import '../services/ppg_processor.dart';
import '../widgets/breathing_exercise.dart';

enum _Phase {
  intro,
  starting,
  placeFinger,
  measuring,
  analyzing,
  result,
  failed,
}

class HeartRateScreen extends StatefulWidget {
  const HeartRateScreen({super.key});

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen>
    with WidgetsBindingObserver {
  static const int _measureMs = 30000;
  static const int _warmupMs = 2000;

  CameraController? _camera;
  _Phase _phase = _Phase.intro;
  String? _error;
  bool _permissionError = false;
  bool _torchAvailable = true;
  bool _fingerLost = false;

  final List<PpgSample> _samples = [];
  final List<double> _wave = [];
  final Stopwatch _clock = Stopwatch();
  int? _fingerSinceMs;
  int _lastFingerMs = 0;
  int _frames = 0;
  double? _liveBpm;
  bool _finishing = false;

  String _context = 'rest';
  PpgResult? _result;
  HeartMeasurement? _before;
  List<HeartMeasurement> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _history = HeartMeasurement.loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plana geçerse kamera ve flaş hemen kapatılır.
    if (state != AppLifecycleState.resumed &&
        (_phase == _Phase.placeFinger || _phase == _Phase.measuring)) {
      _stopCamera();
      _fail('Ölçüm yarıda kaldı. Tekrar başlatabilirsiniz.');
    }
  }

  bool get _active =>
      _phase == _Phase.placeFinger || _phase == _Phase.measuring;

  Future<void> _start({String context = 'rest'}) async {
    _context = context;
    setState(() {
      _phase = _Phase.starting;
      _error = null;
      _permissionError = false;
      _result = null;
      _fingerLost = false;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail('Bu cihazda kamera bulunamadı.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _camera = controller;
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.torch);
        _torchAvailable = true;
      } catch (_) {
        _torchAvailable = false;
      }
      _samples.clear();
      _wave.clear();
      _frames = 0;
      _liveBpm = null;
      _fingerSinceMs = null;
      _finishing = false;
      _clock
        ..reset()
        ..start();
      if (!mounted) return;
      setState(() => _phase = _Phase.placeFinger);
      await controller.startImageStream(_onFrame);
    } on CameraException catch (e) {
      final denied =
          e.code.startsWith('CameraAccessDenied') ||
          e.code == 'CameraAccessRestricted' ||
          e.code == 'cameraPermission';
      await _stopCamera();
      _fail(
        denied
            ? 'Ölçüm için kamera izni gerekiyor.'
            : 'Kamera açılamadı (${e.code}).',
        permission: denied,
      );
    } catch (e) {
      await _stopCamera();
      _fail('Kamera açılamadı.');
    }
  }

  FrameStats _stats(CameraImage image) {
    final planes = image.planes;
    if (image.format.group == ImageFormatGroup.bgra8888) {
      return FrameStats.fromBgra(
        bytes: planes[0].bytes,
        width: image.width,
        height: image.height,
        rowStride: planes[0].bytesPerRow,
      );
    }
    return FrameStats.fromYuv(
      y: planes[0].bytes,
      width: image.width,
      height: image.height,
      yRowStride: planes[0].bytesPerRow,
      v: planes.length > 2 ? planes[2].bytes : null,
      vRowStride: planes.length > 2 ? planes[2].bytesPerRow : 0,
      vPixelStride: planes.length > 2 ? (planes[2].bytesPerPixel ?? 1) : 1,
    );
  }

  void _onFrame(CameraImage image) {
    if (!mounted || !_active || _finishing) return;
    final now = _clock.elapsedMilliseconds;
    final stats = _stats(image);

    if (!stats.fingerDetected) {
      if (_phase == _Phase.measuring && now - _lastFingerMs > 1200) {
        // Parmak kalktı: ölçüm baştan başlar.
        _samples.clear();
        _wave.clear();
        _fingerSinceMs = null;
        _liveBpm = null;
        setState(() {
          _phase = _Phase.placeFinger;
          _fingerLost = true;
        });
      }
      return;
    }

    _lastFingerMs = now;
    _fingerSinceMs ??= now;
    if (_phase == _Phase.placeFinger) {
      setState(() => _phase = _Phase.measuring);
    }
    final t = now - _fingerSinceMs!;
    if (t < _warmupMs) return; // otomatik pozlama otursun

    _samples.add(PpgSample(now, stats.brightness));
    _wave.add(stats.brightness);
    if (_wave.length > 150) _wave.removeAt(0);
    _frames++;
    if (_frames % 30 == 0 && _samples.length > 150) {
      final recent = _samples.sublist(math.max(0, _samples.length - 300));
      _liveBpm = PpgProcessor.analyze(recent)?.bpm ?? _liveBpm;
    }
    if (t - _warmupMs >= _measureMs) {
      _finish();
    } else if (_frames % 3 == 0) {
      setState(() {});
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    setState(() => _phase = _Phase.analyzing);
    final samples = List<PpgSample>.of(_samples);
    await _stopCamera();
    final result = PpgProcessor.analyze(samples);
    if (result == null || !result.reliable) {
      _fail(
        'Sinyal yeterince net değildi. Parmağınızı kamerayı ve flaşı tamamen '
        'kapatacak şekilde, bastırmadan koyun ve ölçüm boyunca hareket etmeyin.',
      );
      return;
    }
    final measurement = HeartMeasurement.fromResult(result, context: _context);
    await HeartMeasurement.save(measurement);
    if (!mounted) return;
    setState(() {
      _result = result;
      _history = HeartMeasurement.loadAll();
      _phase = _Phase.result;
    });
  }

  void _fail(String message, {bool permission = false}) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = message;
      _permissionError = permission;
    });
  }

  Future<void> _stopCamera() async {
    final camera = _camera;
    _camera = null;
    _clock.stop();
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } catch (_) {}
    try {
      await camera.setFlashMode(FlashMode.off);
    } catch (_) {}
    try {
      await camera.dispose();
    } catch (_) {}
  }

  Future<void> _breatheAndRemeasure() async {
    _before = _history.isNotEmpty ? _history.first : null;
    final done = await showBreathingExercise(context);
    if (done == true && mounted) await _start(context: 'after_breathing');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, _) => _stopCamera(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Nabız ve Stres')),
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.intro:
        return _intro();
      case _Phase.starting:
      case _Phase.analyzing:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _phase == _Phase.starting
                    ? 'Kamera açılıyor…'
                    : 'Sinyal çözümleniyor…',
              ),
            ],
          ),
        );
      case _Phase.placeFinger:
      case _Phase.measuring:
        return _measuring();
      case _Phase.result:
        return _resultView();
      case _Phase.failed:
        return _failed();
    }
  }

  Widget _intro() {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        VcCard(
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentRisk.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: 56,
                  color: AppColors.accentRisk,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kamerayla nabız ve stres ölçümü',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              for (final step in const [
                'Oturun ve 1 dakika dinlenin.',
                'İşaret parmağınızla arka kamerayı ve flaşı hafifçe kapatın (bastırmayın).',
                '30 saniye boyunca hareket etmeyin ve konuşmayın.',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(step)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _start(),
                  icon: const Icon(Icons.favorite),
                  label: const Text('Ölçümü başlat'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _historyCard(),
        const SizedBox(height: 16),
        _methodCard(),
      ],
    );
  }

  Widget _measuring() {
    final measuring = _phase == _Phase.measuring;
    final elapsed = _fingerSinceMs == null
        ? 0
        : (_clock.elapsedMilliseconds - _fingerSinceMs! - _warmupMs).clamp(
            0,
            _measureMs,
          );
    final progress = measuring ? elapsed / _measureMs : 0.0;
    final remaining = ((_measureMs - elapsed) / 1000).ceil();
    final camera = _camera;

    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    color: AppColors.accentRisk,
                    backgroundColor: AppColors.accentRisk.withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
                if (camera != null && camera.value.isInitialized)
                  ClipOval(
                    child: SizedBox(
                      width: 140,
                      height: 140,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: camera.value.previewSize?.height ?? 140,
                          height: camera.value.previewSize?.width ?? 140,
                          child: CameraPreview(camera),
                        ),
                      ),
                    ),
                  ),
                if (measuring && _liveBpm != null)
                  Text(
                    '${_liveBpm!.round()}',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 8)],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          measuring
              ? 'Hareket etmeyin… $remaining sn'
              : (_fingerLost
                    ? 'Parmak algılanmadı. Kamerayı ve flaşı tekrar kapatın.'
                    : 'Parmağınızı arka kameraya ve flaşın üzerine yerleştirin.'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (!_torchAvailable) ...[
          const SizedBox(height: 8),
          Text(
            'Bu cihazda flaş bulunamadı; parmağınızı kameraya koyup parlak bir '
            'ışığa doğru tutun.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.warning),
          ),
        ],
        const SizedBox(height: 20),
        VcCard(
          child: SizedBox(
            height: 90,
            child: _wave.length < 10
                ? Center(
                    child: Text(
                      'Nabız dalgası burada görünecek',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  )
                : CustomPaint(
                    painter: _WavePainter(List.of(_wave), AppColors.accentRisk),
                    size: Size.infinite,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () async {
              await _stopCamera();
              if (mounted) setState(() => _phase = _Phase.intro);
            },
            child: const Text('İptal'),
          ),
        ),
      ],
    );
  }

  Widget _resultView() {
    final r = _result!;
    final bpm = r.bpm.round();
    final stressColor = switch (r.stress) {
      StressLevel.low => AppColors.success,
      StressLevel.moderate => AppColors.warning,
      StressLevel.high => AppColors.danger,
    };
    final bpmNote = bpm < 50
        ? 'Dinlenik nabız düşük (<50). Sporcu değilseniz ve baş dönmesi, '
              'halsizlik varsa doktorunuza danışın.'
        : bpm > 100
        ? 'Dinlenik nabız yüksek (>100). 5 dakika dinlenip tekrar ölçün; '
              'sürerse doktorunuza danışın.'
        : 'Dinlenik nabız normal aralıkta (60-100).';
    final stressNote = switch (r.stress) {
      StressLevel.low =>
        'Kalp hızı değişkenliğiniz iyi; vücudunuz dinlenme modunda görünüyor.',
      StressLevel.moderate =>
        'Orta düzey stres göstergesi. Kısa bir nefes egzersizi iyi gelebilir.',
      StressLevel.high =>
        'Kalp hızı değişkenliğiniz düşük; stres, yorgunluk veya uykusuzluk '
            'göstergesi olabilir.',
    };
    final before = _context == 'after_breathing' ? _before : null;

    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        VcCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite, color: AppColors.accentRisk, size: 36),
                  const SizedBox(width: 12),
                  Text(
                    '$bpm',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'atım/dk',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SpeakButton(
                    id: 'heart-result',
                    text:
                        'Nabzınız dakikada $bpm. $bpmNote Stres göstergesi '
                        '${r.stress.label.toLowerCase()}. $stressNote',
                  ),
                ],
              ),
              Text(bpmNote, textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 12),
        VcCard(
          borderColor: stressColor.withValues(alpha: 0.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.self_improvement, color: stressColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stres göstergesi: ${r.stress.label}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: stressColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(stressNote),
              const SizedBox(height: 8),
              Text(
                'HRV (RMSSD): ${r.rmssdMs.toStringAsFixed(0)} ms · '
                'Sinyal kalitesi: %${(r.quality * 100).round()} · '
                '${r.beats} atım',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (before != null) ...[
          const SizedBox(height: 12),
          _comparisonCard(before, r),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _breatheAndRemeasure,
          icon: const Icon(Icons.air),
          label: const Text('1 dk nefes egzersizi, sonra tekrar ölç'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _start(),
          icon: const Icon(Icons.refresh),
          label: const Text('Tekrar ölç'),
        ),
        const SizedBox(height: 16),
        _historyCard(),
        const SizedBox(height: 12),
        Text(
          'Bu ölçüm tıbbi cihaz değildir; tanı veya tedavi için kullanılamaz. '
          '${AppConstants.medicalDisclaimer}',
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _comparisonCard(HeartMeasurement before, PpgResult after) {
    final dHrv = after.rmssdMs - before.rmssdMs;
    final dBpm = after.bpm.round() - before.bpm;
    final improved = dHrv > 0;
    String signed(num v, [int digits = 0]) =>
        '${v >= 0 ? '+' : ''}${v.toStringAsFixed(digits)}';
    return VcCard(
      borderColor: (improved ? AppColors.success : AppColors.warning)
          .withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nefes egzersizinin etkisi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'HRV: ${before.rmssdMs.toStringAsFixed(0)} → '
            '${after.rmssdMs.toStringAsFixed(0)} ms (${signed(dHrv)})',
          ),
          Text(
            'Nabız: ${before.bpm} → ${after.bpm.round()} atım/dk (${signed(dBpm)})',
          ),
          const SizedBox(height: 6),
          Text(
            improved
                ? 'Kalp hızı değişkenliğiniz arttı: vücudunuz sakinleşme '
                      'moduna geçiyor.'
                : 'Bu kez belirgin bir değişim olmadı; düzenli uygulamada '
                      'etkisi artar.',
            style: TextStyle(
              color: improved ? AppColors.success : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _failed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: AppColors.warning),
            const SizedBox(height: 12),
            Text(_error ?? 'Ölçüm yapılamadı.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (_permissionError)
              FilledButton(
                onPressed: openAppSettings,
                child: const Text('Uygulama izinlerini aç'),
              )
            else
              FilledButton(
                onPressed: () => _start(context: _context),
                child: const Text('Tekrar dene'),
              ),
            TextButton(
              onPressed: () => setState(() => _phase = _Phase.intro),
              child: const Text('Geri'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard() {
    if (_history.isEmpty) return const SizedBox.shrink();
    String two(int v) => v.toString().padLeft(2, '0');
    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Son ölçümler',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final m in _history.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    m.afterBreathing ? Icons.air : Icons.favorite_border,
                    size: 18,
                    color: AppColors.accentRisk,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${two(m.date.day)}.${two(m.date.month)} ${two(m.date.hour)}:${two(m.date.minute)}'
                      '${m.afterBreathing ? ' · nefes sonrası' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${m.bpm} atım/dk · HRV ${m.rmssdMs.toStringAsFixed(0)} ms',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _methodCard() {
    return VcCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Nasıl çalışır?'),
          children: [
            Text(
              'Fotopletismografi (PPG): Flaş parmağınızdan geçerken her kalp '
              'atımında artan kan hacmi ışığı biraz daha emer. Kamera bu küçük '
              'parlaklık değişimini saniyede ~30 kez ölçer. Uygulama sinyali '
              'süzer, atımları bulur ve atımlar arası süreden nabzı, bu sürelerin '
              'değişkenliğinden (RMSSD) stres göstergesini hesaplar.\n\n'
              'Görüntüler kaydedilmez ve telefondan çıkmaz; tüm işlem cihazda '
              'yapılır.\n\n'
              'Kaynaklar: Jonathan & Leahy, "Investigating a smartphone imaging '
              'unit for photoplethysmography", Physiol. Meas. 2010; Task Force '
              'of ESC/NASPE, "Heart rate variability: standards of measurement", '
              'Circulation 1996.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Son ~5 saniyenin nabız dalgası (atımlar tepe olarak görünür).
class _WavePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _WavePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    // Yavaş kaymayı çıkarmak için 15 örneklik ortalamadan farkı çiz.
    final detrended = <double>[];
    for (var i = 0; i < values.length; i++) {
      final lo = math.max(0, i - 7), hi = math.min(values.length, i + 8);
      var s = 0.0;
      for (var j = lo; j < hi; j++) {
        s += values[j];
      }
      detrended.add(-(values[i] - s / (hi - lo)));
    }
    final lo = detrended.reduce(math.min), hi = detrended.reduce(math.max);
    final range = (hi - lo).abs() < 1e-6 ? 1.0 : hi - lo;
    final path = Path();
    for (var i = 0; i < detrended.length; i++) {
      final x = size.width * i / (detrended.length - 1);
      final y =
          size.height * (1 - (detrended[i] - lo) / range) * 0.9 +
          size.height * 0.05;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => true;
}
