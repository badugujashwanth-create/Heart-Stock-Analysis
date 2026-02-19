import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/prediction_parser.dart';

class PredictionResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final Map<String, dynamic> input;

  const PredictionResultScreen({super.key, required this.result, required this.input});

  @override
  State<PredictionResultScreen> createState() => _PredictionResultScreenState();
}

class _PredictionResultScreenState extends State<PredictionResultScreen> {
  late final Map<String, dynamic> _normalized;

  @override
  void initState() {
    super.initState();
    _normalized = _normalizeSafely();
    _persist();
  }

  Map<String, dynamic> _normalizeSafely() {
    try {
      return PredictionParser.normalize(widget.result);
    } catch (_) {
      return {
        'stroke_prediction': 0.0,
        'risk_label': 'Low Risk',
        'recommendations': const <String>[],
      };
    }
  }

  double _predictionFraction() {
    final value = _normalized['stroke_prediction'];
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString('last_prediction', _predictionFraction().toString());
    await prefs.setString('last_prediction_time', now);
  }

  String _stage(double pct) {
    if (pct >= 0.75) return 'Very High Risk';
    if (pct >= 0.50) return 'High Risk';
    if (pct >= 0.25) return 'Moderate Risk';
    return 'Low Risk';
  }

  bool _yes(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value > 0;
    if (value is String) {
      final text = value.trim().toLowerCase();
      return text == 'yes' || text == 'true' || text == '1';
    }
    return false;
  }

  List<String> _fallbackTips(String stage) {
    switch (stage) {
      case 'Very High Risk':
      case 'High Risk':
        return const [
          'Book an appointment with your clinician.',
          'Check blood pressure twice daily and log readings.',
          'Reduce salt, avoid smoking and alcohol, and manage stress.',
          'Aim for at least 150 minutes/week of moderate exercise.',
        ];
      case 'Moderate Risk':
        return const [
          'Adopt a DASH or Mediterranean-style diet.',
          'Exercise 30 minutes most days; add two strength sessions weekly.',
          'Maintain healthy weight and sleep 7-9 hours each night.',
        ];
      default:
        return const [
          'Continue healthy habits and regular preventive checkups.',
          'Stay active and limit excess salt and sugar.',
        ];
    }
  }

  List<String> _recommendations(String stage) {
    final raw = _normalized['recommendations'];
    if (raw is List) {
      final parsed = raw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parsed.isNotEmpty) return parsed;
    }
    return _fallbackTips(stage);
  }

  List<Map<String, dynamic>> _topFactors() {
    final raw = _normalized['top_factors'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  Future<void> _downloadPdf(
    BuildContext context,
    double prediction,
    String stage,
    List<String> recommendations,
    String interpretation,
    String aiSummary,
  ) async {
    final doc = pw.Document();
    final name = (widget.input['name'] as String? ?? '').trim();
    final dt = DateTime.now();
    final displayNow =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final pct = (prediction * 100).toStringAsFixed(0);

    pw.Widget row(String k, String v) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.2, color: PdfColors.grey300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(k, style: const pw.TextStyle(color: PdfColors.grey800)),
              pw.Text(v, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );

    final fields = <MapEntry<String, String>>[
      MapEntry('Name', name.isEmpty ? '-' : name),
      MapEntry('Age', (widget.input['age'] ?? '-').toString()),
      MapEntry('Gender', (widget.input['gender'] ?? '-').toString()),
      MapEntry('Systolic BP', (widget.input['systolic_bp'] ?? '-').toString()),
      MapEntry('Diastolic BP', (widget.input['diastolic_bp'] ?? '-').toString()),
      MapEntry('BMI', (widget.input['bmi'] ?? '-').toString()),
      MapEntry('Glucose', (widget.input['avg_glucose_level'] ?? '-').toString()),
      MapEntry('Smoking', (widget.input['smoking_status'] ?? '-').toString()),
      MapEntry('Alcoholic', _yes(widget.input['alcoholic']) ? 'Yes' : 'No'),
      MapEntry('Family History', _yes(widget.input['family_history']) ? 'Yes' : 'No'),
      MapEntry('Residence', (widget.input['Residence_type'] ?? '-').toString()),
      MapEntry('Work Type', (widget.input['work_type'] ?? '-').toString()),
    ];

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Heart Stroke Risk Report',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text(displayNow, style: const pw.TextStyle(color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.cyan50,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Risk Percentage', style: const pw.TextStyle(color: PdfColors.grey700)),
                  pw.Text('$pct%',
                      style: pw.TextStyle(
                        fontSize: 42,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.cyan800,
                      )),
                ]),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: stage.contains('Low')
                        ? PdfColors.green100
                        : (stage.contains('Moderate') ? PdfColors.orange100 : PdfColors.red100),
                    borderRadius: pw.BorderRadius.circular(24),
                  ),
                  child: pw.Text(
                    stage,
                    style: pw.TextStyle(
                      color: stage.contains('Low')
                          ? PdfColors.green900
                          : (stage.contains('Moderate') ? PdfColors.orange900 : PdfColors.red900),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text('Interpretation', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(interpretation),
          pw.SizedBox(height: 10),
          pw.Text('AI Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(aiSummary),
          pw.SizedBox(height: 16),
          pw.Text('Patient Details', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(children: fields.map((e) => row(e.key, e.value)).toList()),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Recommendations', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          for (final tip in recommendations) pw.Bullet(text: tip),
          pw.SizedBox(height: 8),
          pw.Text(
            'This report is informational and not a medical diagnosis.',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'heart_stroke_risk_$pct.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prediction = _predictionFraction();
    final percentage = (prediction * 100).toStringAsFixed(0);
    final stage = ((_normalized['risk_label'] as String?)?.trim().isNotEmpty ?? false)
        ? (_normalized['risk_label'] as String).trim()
        : _stage(prediction);

    final name = (widget.input['name'] as String? ?? '').trim();
    final isHighRisk = prediction > 0.5;
    final isModerateRisk = !isHighRisk && prediction >= 0.25;
    final badgeBackground = isHighRisk
        ? theme.colorScheme.errorContainer
        : (isModerateRisk ? theme.colorScheme.tertiaryContainer : theme.colorScheme.secondaryContainer);
    final badgeForeground = isHighRisk
        ? theme.colorScheme.onErrorContainer
        : (isModerateRisk ? theme.colorScheme.onTertiaryContainer : theme.colorScheme.onSecondaryContainer);

    final interpretation = (_normalized['interpretation'] as String?)?.trim() ??
        'Use this estimate with clinical context. It is not a diagnosis.';
    final aiSummary = (_normalized['ai_summary'] as String?)?.trim() ??
        'The model combines your risk factors and estimated their relative impact.';
    final recommendations = _recommendations(stage);
    final factors = _topFactors();

    final modelName = (_normalized['model_name'] as String?)?.trim();
    final modelVersion = (_normalized['model_version'] as String?)?.trim();
    final apiVersion = (_normalized['api_version'] as String?)?.trim();
    final disclaimer = (_normalized['disclaimer'] as String?)?.trim() ??
        'This output is informational and should not replace professional medical advice.';

    return Scaffold(
      appBar: AppBar(title: const Text('Prediction Result')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.08),
                  theme.colorScheme.surface,
                ],
              ),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'Result' : 'Result for $name', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text('Risk Percentage', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: badgeBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    stage,
                    style: TextStyle(color: badgeForeground, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Insights', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(interpretation),
                  const SizedBox(height: 8),
                  Text(aiSummary, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  if ((modelName?.isNotEmpty ?? false) || (modelVersion?.isNotEmpty ?? false) || (apiVersion?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 10),
                    Text(
                      [
                        if (modelName?.isNotEmpty ?? false) modelName,
                        if (modelVersion?.isNotEmpty ?? false) 'v$modelVersion',
                        if (apiVersion?.isNotEmpty ?? false) 'API $apiVersion',
                      ].whereType<String>().join(' | '),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (factors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Top Contributing Factors', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final factor in factors)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              (factor['effect'] == 'decrease') ? Icons.trending_down : Icons.trending_up,
                              size: 18,
                              color: (factor['effect'] == 'decrease')
                                  ? Colors.green.shade700
                                  : theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                factor['label']?.toString() ?? factor['feature']?.toString() ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              'Impact ${(factor['impact_score'] ?? 0).toString()}',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _kv('Age', '${widget.input['age'] ?? '-'}'),
                  _kv('Gender', '${widget.input['gender'] ?? '-'}'),
                  _kv('Blood Pressure', '${widget.input['systolic_bp'] ?? '-'}/${widget.input['diastolic_bp'] ?? '-'}'),
                  _kv('BMI', '${widget.input['bmi'] ?? '-'}'),
                  _kv('Glucose', '${widget.input['avg_glucose_level'] ?? '-'}'),
                  _kv('Smoking', '${widget.input['smoking_status'] ?? '-'}'),
                  _kv('Alcoholic', _yes(widget.input['alcoholic']) ? 'Yes' : 'No'),
                  _kv('Family History', _yes(widget.input['family_history']) ? 'Yes' : 'No'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recommendations', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final tip in recommendations)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(tip)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                disclaimer,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  onPressed: () => _downloadPdf(
                    context,
                    prediction,
                    stage,
                    recommendations,
                    interpretation,
                    aiSummary,
                  ),
                  label: const Text('Download PDF'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Form'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
