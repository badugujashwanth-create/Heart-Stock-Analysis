import 'package:flutter_test/flutter_test.dart';
import 'package:heartanalysis/services/prediction_parser.dart';

void main() {
  group('PredictionParser', () {
    test('keeps fraction values unchanged', () {
      final payload = {'stroke_prediction': 0.42, 'risk_label': 'Moderate Risk'};

      final normalized = PredictionParser.normalize(payload);

      expect(normalized['stroke_prediction'], 0.42);
      expect(normalized['risk_label'], 'Moderate Risk');
      expect(normalized['response_normalized'], false);
    });

    test('normalizes percentage values to fractions', () {
      final payload = {'stroke_prediction': 67};

      final normalized = PredictionParser.normalize(payload);

      expect(normalized['stroke_prediction'], closeTo(0.67, 0.0001));
      expect(normalized['risk_label'], 'High Risk');
      expect(normalized['response_normalized'], true);
    });

    test('accepts list payload and string percentage', () {
      final payload = [
        {'stroke_probability': '25%'}
      ];

      final normalized = PredictionParser.normalize(payload);

      expect(normalized['stroke_prediction'], closeTo(0.25, 0.0001));
      expect(normalized['risk_label'], 'Moderate Risk');
      expect(normalized['response_normalized'], true);
    });

    test('throws when risk value is missing', () {
      final payload = {'foo': 'bar'};

      expect(
        () => PredictionParser.normalize(payload),
        throwsA(isA<PredictionFormatException>()),
      );
    });

    test('flattens nested prediction and explanation payload', () {
      final payload = {
        'prediction': {
          'stroke_probability': '61%',
          'risk_label': 'High Risk',
        },
        'explanations': {
          'summary': 'Primary drivers are BP and glucose.',
          'top_factors': [
            {'feature': 'systolic_bp', 'label': 'Systolic blood pressure', 'effect': 'increase'}
          ],
        },
        'model': {'name': 'CardioRisk AI', 'version': '2.0.0'},
        'recommendations': ['Check blood pressure daily.'],
      };

      final normalized = PredictionParser.normalize(payload);

      expect(normalized['stroke_prediction'], closeTo(0.61, 0.0001));
      expect(normalized['risk_label'], 'High Risk');
      expect(normalized['ai_summary'], 'Primary drivers are BP and glucose.');
      expect(normalized['top_factors'], isA<List<Map<String, dynamic>>>());
      expect(normalized['recommendations'], ['Check blood pressure daily.']);
      expect(normalized['model_name'], 'CardioRisk AI');
      expect(normalized['model_version'], '2.0.0');
    });
  });
}
