import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfGenerator {
  PdfGenerator._();

  static Future<void> generateAndShare({
    required String title,
    required String content,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#0F172A'), // Premium Dark Slate
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 3,
                color: PdfColor.fromHex('#3B82F6'), // Primary Blue line
              ),
              pw.SizedBox(height: 30),
              pw.Expanded(
                child: pw.Text(
                  content,
                  style: pw.TextStyle(
                    fontSize: 11,
                    lineSpacing: 5,
                    color: PdfColor.fromHex('#334155'), // Slate 700 body
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Fly AI - Scholarship Platform',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    'Generated on ${DateTime.now().toIso8601String().split('T').first}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${title.replaceAll(' ', '_')}.pdf',
    );
  }
}
