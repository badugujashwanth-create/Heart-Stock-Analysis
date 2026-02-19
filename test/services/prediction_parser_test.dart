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
  });
}
