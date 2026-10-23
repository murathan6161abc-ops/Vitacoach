import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vitacoach/modules/m17_report/services/report_service.dart';
import 'package:vitacoach/services/demo_data_service.dart';
import 'package:vitacoach/services/hive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vitacoach_report_test_');
    FlutterSecureStorage.setMockInitialValues({});
    await HiveService().init(testPath: dir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('demo verisiyle geçerli bir PDF raporu üretir', () async {
    await DemoDataService.load();
    final data = await ReportData.collect();
    expect(data.pressures.length, 14);
    expect(data.interactions.length, 2);
    expect(data.risks.length, 2);

    final bytes = await ReportService.generate(data);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(20000));
    final out = Platform.environment['VC_REPORT_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });

  test('boş veriyle de çökmeden PDF üretir', () async {
    final bytes = await ReportService.generate(await ReportData.collect());
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
