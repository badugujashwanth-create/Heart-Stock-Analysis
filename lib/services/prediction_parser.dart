class PredictionFormatException implements Exception {
  final String message;
  const PredictionFormatException(this.message);

  @override
  String toString() => message;
}

class PredictionParser {
  static Map<String, dynamic> normalize(dynamic decoded) {
    final payload = _asMap(decoded);
    final flattened = _flatten(payload);
    final risk = _extractRisk(flattened);

    final normalized = Map<String, dynamic>.from(flattened)
      ..['stroke_prediction'] = risk.value
      ..['risk_label'] = _resolveRiskLabel(flattened['risk_label'], risk.value)
      ..['response_normalized'] = risk.wasNormalized
      ..['recommendations'] = _asStringList(flattened['recommendations'])
      ..['top_factors'] = _asFactorList(flattened['top_factors']);

    final summary = flattened['ai_summary'];
    if (summary is String && summary.trim().isNotEmpty) {
      normalized['ai_summary'] = summary.trim();
    }

    return normalized;
  }

  static Map<String, dynamic> _asMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    throw const PredictionFormatException(
      'Prediction API response has an unexpected structure.',
    );
  }

  static Map<String, dynamic> _flatten(Map<String, dynamic> payload) {
    final out = Map<String, dynamic>.from(payload);

    final prediction = payload['prediction'];
    if (prediction is Map) {
      final p = Map<String, dynamic>.from(prediction);
      if (!out.containsKey('stroke_prediction') && p.containsKey('stroke_prediction')) {
        out['stroke_prediction'] = p['stroke_prediction'];
      }
      if (!out.containsKey('stroke_probability') && p.containsKey('stroke_probability')) {
        out['stroke_probability'] = p['stroke_probability'];
      }
      if (!out.containsKey('risk_label') && p.containsKey('risk_label')) {
        out['risk_label'] = p['risk_label'];
      }
    }

    final explanations = payload['explanations'];
    if (explanations is Map) {
      final e = Map<String, dynamic>.from(explanations);
      if (!out.containsKey('ai_summary') && e['summary'] is String) {
        out['ai_summary'] = e['summary'];
      }
      if (!out.containsKey('top_factors') && e['top_factors'] is List) {
        out['top_factors'] = e['top_factors'];
      }
    }

    final model = payload['model'];
    if (model is Map) {
      final m = Map<String, dynamic>.from(model);
      if (!out.containsKey('model_name') && m['name'] is String) {
        out['model_name'] = m['name'];
      }
      if (!out.containsKey('model_version') && m['version'] is String) {
        out['model_version'] = m['version'];
      }
    }

    return out;
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

  static List<String> _asStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .where((e) => e is String && e.trim().isNotEmpty)
        .map((e) => (e as String).trim())
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _asFactorList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }
}

class _RiskValue {
  final double value;
  final bool wasNormalized;
  const _RiskValue(this.value, this.wasNormalized);
}
