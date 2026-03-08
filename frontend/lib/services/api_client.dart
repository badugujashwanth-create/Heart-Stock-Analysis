import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/prediction_models.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsClient;

  Duration get _timeout => const Duration(seconds: 45);

  Uri _uri(String path) {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    return Uri.parse('$base$path');
  }

  Future<PredictionResult> predict(PredictionRequestData input) async {
    final response = await _httpClient
        .post(
          _uri('/v1/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(input.toJson()),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response));
    }

    final body = jsonDecode(response.body);
    if (body is! Map) {
      throw const ApiException('Invalid API response format.');
    }
    return PredictionResult.fromJson(Map<String, dynamic>.from(body));
  }

  Future<List<HistoryRecord>> fetchPredictions({int limit = 20}) async {
    final response = await _httpClient
        .get(_uri('/v1/predictions?limit=$limit'))
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response));
    }

    final body = jsonDecode(response.body);
    if (body is! Map) {
      throw const ApiException('Invalid history response format.');
    }

    final records = (body['records'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((row) => HistoryRecord.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);

    return records;
  }

  Future<SimulationResult> simulate({
    required PredictionRequestData baselineInput,
    required Map<String, dynamic> overrides,
  }) async {
    final response = await _httpClient
        .post(
          _uri('/v1/simulate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
            {
              'input': baselineInput.toJson(),
              'overrides': overrides,
            },
          ),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response));
    }

    final body = jsonDecode(response.body);
    if (body is! Map) {
      throw const ApiException('Invalid simulation response format.');
    }
    return SimulationResult.fromJson(Map<String, dynamic>.from(body));
  }

  Future<AiPlan> generateAiPlan({
    required PredictionRequestData userInputs,
    required PredictionResult predictionOutput,
    AiUserPreferences? userPreferences,
  }) async {
    final response = await _httpClient
        .post(
          _uri('/v1/ai/plan'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
            {
              'user_inputs': userInputs.toJson(),
              'prediction_output': {
                'risk_probability': predictionOutput.riskProbability,
                'risk_label': predictionOutput.riskLabel,
                'top_factors': predictionOutput.topFactors
                    .map(
                      (f) => {
                        'feature': f.feature,
                        'value': f.value,
                        'contribution': f.contribution,
                        'direction': f.direction,
                      },
                    )
                    .toList(growable: false),
                'recommendations': predictionOutput.recommendations,
                'interpretation': predictionOutput.interpretation,
                'ai_summary': predictionOutput.aiSummary,
                'disclaimer': predictionOutput.disclaimer,
              },
              if (userPreferences != null) 'user_preferences': userPreferences.toJson(),
            },
          ),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response));
    }

    final body = jsonDecode(response.body);
    if (body is! Map) {
      throw const ApiException('Invalid AI plan response format.');
    }
    return AiPlan.fromJson(Map<String, dynamic>.from(body));
  }

  Future<AiChatResponseData> aiChat({
    required String message,
    PredictionRequestData? userInputs,
    PredictionResult? predictionOutput,
    AiPlan? aiPlan,
  }) async {
    final response = await _httpClient
        .post(
          _uri('/v1/ai/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
            {
              'message': message,
              if (userInputs != null) 'user_inputs': userInputs.toJson(),
              if (predictionOutput != null)
                'prediction_output': {
                  'risk_probability': predictionOutput.riskProbability,
                  'risk_label': predictionOutput.riskLabel,
                  'top_factors': predictionOutput.topFactors
                      .map(
                        (f) => {
                          'feature': f.feature,
                          'value': f.value,
                          'contribution': f.contribution,
                          'direction': f.direction,
                        },
                      )
                      .toList(growable: false),
                  'recommendations': predictionOutput.recommendations,
                  'interpretation': predictionOutput.interpretation,
                  'ai_summary': predictionOutput.aiSummary,
                  'disclaimer': predictionOutput.disclaimer,
                },
              if (aiPlan != null)
                'ai_plan': {
                  'summary': aiPlan.summary,
                  'top_priorities': aiPlan.topPriorities
                      .map((p) => {'title': p.title, 'why': p.why, 'how': p.how})
                      .toList(growable: false),
                  'diet_plan': {
                    'notes': aiPlan.dietPlan.notes,
                    'daily_targets': {
                      'water_liters': aiPlan.dietPlan.dailyTargets.waterLiters,
                      'steps': aiPlan.dietPlan.dailyTargets.steps,
                      'sleep_hours': aiPlan.dietPlan.dailyTargets.sleepHours,
                    },
                    'day_plan': aiPlan.dietPlan.dayPlan
                        .map(
                          (d) => {
                            'meal': d.meal,
                            'items': d.items
                                .map(
                                  (i) => {
                                    'name': i.name,
                                    'portion': i.portion,
                                    'reason': i.reason,
                                  },
                                )
                                .toList(growable: false),
                            'avoid': d.avoid,
                          },
                        )
                        .toList(growable: false),
                    'weekly_plan': aiPlan.dietPlan.weeklyPlan
                        .map((w) => {'day': w.day, 'focus': w.focus, 'meals': w.meals})
                        .toList(growable: false),
                  },
                  'exercise_plan': {
                    'safety_notes': aiPlan.exercisePlan.safetyNotes,
                    'weekly_schedule': aiPlan.exercisePlan.weeklySchedule
                        .map(
                          (s) => {
                            'day': s.day,
                            'workout': s.workout,
                            'duration_min': s.durationMin,
                            'intensity': s.intensity,
                          },
                        )
                        .toList(growable: false),
                    'progression': aiPlan.exercisePlan.progression,
                  },
                  'habits': aiPlan.habits
                      .map((h) => {'habit': h.habit, 'target': h.target, 'tips': h.tips})
                      .toList(growable: false),
                  'red_flags': aiPlan.redFlags,
                  'disclaimer': aiPlan.disclaimer,
                },
            },
          ),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response));
    }

    final body = jsonDecode(response.body);
    if (body is! Map) {
      throw const ApiException('Invalid AI chat response format.');
    }
    return AiChatResponseData.fromJson(Map<String, dynamic>.from(body));
  }

  String _extractError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        if (body['error'] != null && body['details'] is List) {
          final details = (body['details'] as List)
              .whereType<Map>()
              .map((d) => '${d['field']}: ${d['message']}')
              .join(', ');
          return 'Request failed (${response.statusCode}): $details';
        }
        if (body['error'] != null) {
          return 'Request failed (${response.statusCode}): ${body['error']}';
        }
      }
    } catch (_) {
      // fall through
    }
    return 'Request failed (${response.statusCode}).';
  }

  void dispose() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }
}
