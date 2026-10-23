import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../services/report_service.dart';

/// PDF raporunu önizler; yazdırma ve paylaşma düğmeleri sunar.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final Future<ReportData> _data = ReportData.collect();

  @override
  Widget build(BuildContext context) {
    final fileName =
        'vitacoach-rapor-${DateTime.now().toIso8601String().substring(0, 10)}.pdf';
    return Scaffold(
      appBar: AppBar(title: const Text('Doktor Raporu')),
      body: FutureBuilder<ReportData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Rapor hazırlanamadı: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return PdfPreview(
            build: (_) => ReportService.generate(snapshot.data!),
            initialPageFormat: PdfPageFormat.a4,
            pdfFileName: fileName,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            loadingWidget: const CircularProgressIndicator(),
          );
        },
      ),
    );
  }
}
