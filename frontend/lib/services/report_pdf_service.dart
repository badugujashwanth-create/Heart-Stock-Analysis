import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/prediction_models.dart';

class ReportPdfService {
  Future<void> export(
    PredictionResult result, {
    AiPlan? aiPlan,
    String? patientName,
  }) async {
    final doc = pw.Document();
    final percent = (result.riskProbability * 100).toStringAsFixed(1);
    final footerDisclaimer = aiPlan?.disclaimer ?? result.disclaimer;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerLeft,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            footerDisclaimer,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.Text(
            'HeartAnalysis Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Patient: ${patientName == null || patientName.trim().isEmpty ? "N/A" : patientName}',
          ),
          pw.Text('Educational Profile Score: $percent / 100'),
          pw.Text('Score Band: ${result.riskLabel}'),
          pw.SizedBox(height: 10),
          pw.Text(
            'Interpretation',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(result.interpretation),
          pw.SizedBox(height: 10),
          pw.Text(
            'AI Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(result.aiSummary),
          pw.SizedBox(height: 10),
          pw.Text(
            'Top Factors',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          ...result.topFactors.map(
            (f) => pw.Bullet(
              text:
                  '${f.feature}: contribution ${f.contribution.toStringAsFixed(3)} (${f.direction})',
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Recommendations',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          ...result.recommendations.map((rec) => pw.Bullet(text: rec)),
          if (aiPlan != null) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'AI Top Priorities',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ...aiPlan.topPriorities.map(
              (p) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Bullet(text: '${p.title}: ${p.why}'),
                  ...p.how.map(
                    (step) => pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
                      child: pw.Text('- $step'),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Diet Plan (Day View)',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ...aiPlan.dietPlan.dayPlan.map(
              (meal) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      meal.meal.toUpperCase(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    ...meal.items.map(
                      (item) => pw.Bullet(
                        text: '${item.name} (${item.portion}) - ${item.reason}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Exercise Weekly Schedule',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ...aiPlan.exercisePlan.weeklySchedule.map(
              (row) => pw.Bullet(
                text:
                    '${row.day}: ${row.workout} (${row.durationMin} min, ${row.intensity})',
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              result.disclaimer,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'heartanalysis_report.pdf',
    );
  }
}
