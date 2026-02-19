class PredictionFormatException implements Exception {
  final String message;
  const PredictionFormatException(this.message);

  @override
  String toString() => message;
}

class PredictionParser {
  static Map<String, dynamic> normalize(dynamic decoded) {
    final payload = _asMap(decoded);
    final risk = _extractRisk(payload);

    final normalized = Map<String, dynamic>.from(payload)
      ..['stroke_prediction'] = risk.value
      ..['risk_label'] = _resolveRiskLabel(payload['risk_label'], risk.value)
      ..['response_normalized'] = risk.wasNormalized;

    return normalized;
  }

  static Map<String, dynamic> _asMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    throw const PredictionFormatException(
      'Prediction API response has an unexpected structure.',
    );
  }

  static _RiskValue _extractRisk(Map<String, dynamic> payload) {
    if (payload.containsKey('stroke_prediction')) {
      return _normalizeProbability(payload['stroke_prediction']);
    }
    if (payload.containsKey('stroke_probability')) {
      return _normalizeProbability(payload['stroke_probability']);
    }
    throw const PredictionFormatException(
      'Prediction API response is missing stroke risk value.',
    );
  }

  static _RiskValue _normalizeProbability(dynamic raw) {
    final parsed = _tryParseNum(raw);
    if (parsed == null) {
      throw const PredictionFormatException(
        'Prediction API response contains a non-numeric risk value.',
      );
    }

    if (parsed < 0) {
      throw const PredictionFormatException('Prediction risk cannot be negative.');
    }

    if (parsed <= 1) {
      return _RiskValue(parsed.toDouble(), false);
    }

    if (parsed <= 100) {
      return _RiskValue(parsed.toDouble() / 100.0, true);
    }

    throw const PredictionFormatException(
      'Prediction risk value is out of supported range.',
    );
  }

  static num? _tryParseNum(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final cleaned = value.trim().replaceAll('%', '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  static String _resolveRiskLabel(dynamic label, double fraction) {
    if (label is String && label.trim().isNotEmpty) {
      return label.trim();
    }
    if (fraction >= 0.75) return 'Very High Risk';
    if (fraction >= 0.50) return 'High Risk';
    if (fraction >= 0.25) return 'Moderate Risk';
    return 'Low Risk';
  }
}

class _RiskValue {
  final double value;
  final bool wasNormalized;
  const _RiskValue(this.value, this.wasNormalized);
}
