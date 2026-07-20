class PredictionRequestData {
  final int age;
  final String gender;
  final String hypertension;
  final String heartDisease;
  final String everMarried;
  final String workType;
  final String residenceType;
  final double avgGlucoseLevel;
  final double bmi;
  final String smokingStatus;
  final int systolicBp;
  final int diastolicBp;
  final String alcoholic;
  final String familyHistory;
  final int sleepHours;
  final int exerciseMins;
  final String excessSalt;

  const PredictionRequestData({
    required this.age,
    required this.gender,
    required this.hypertension,
    required this.heartDisease,
    required this.everMarried,
    required this.workType,
    required this.residenceType,
    required this.avgGlucoseLevel,
    required this.bmi,
    required this.smokingStatus,
    required this.systolicBp,
    required this.diastolicBp,
    required this.alcoholic,
    required this.familyHistory,
    required this.sleepHours,
    required this.exerciseMins,
    required this.excessSalt,
  });

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'gender': gender,
      'hypertension': hypertension,
      'heart_disease': heartDisease,
      'ever_married': everMarried,
      'work_type': workType,
      'Residence_type': residenceType,
      'avg_glucose_level': avgGlucoseLevel,
      'bmi': bmi,
      'smoking_status': smokingStatus,
      'systolic_bp': systolicBp,
      'diastolic_bp': diastolicBp,
      'alcoholic': alcoholic,
      'family_history': familyHistory,
      'sleep_hours': sleepHours,
      'exercise_mins': exerciseMins,
      'excess_salt': excessSalt,
    };
  }

  PredictionRequestData copyWith({
    int? age,
    String? gender,
    String? hypertension,
    String? heartDisease,
    String? everMarried,
    String? workType,
    String? residenceType,
    double? avgGlucoseLevel,
    double? bmi,
    String? smokingStatus,
    int? systolicBp,
    int? diastolicBp,
    String? alcoholic,
    String? familyHistory,
    int? sleepHours,
    int? exerciseMins,
    String? excessSalt,
  }) {
    return PredictionRequestData(
      age: age ?? this.age,
      gender: gender ?? this.gender,
      hypertension: hypertension ?? this.hypertension,
      heartDisease: heartDisease ?? this.heartDisease,
      everMarried: everMarried ?? this.everMarried,
      workType: workType ?? this.workType,
      residenceType: residenceType ?? this.residenceType,
      avgGlucoseLevel: avgGlucoseLevel ?? this.avgGlucoseLevel,
      bmi: bmi ?? this.bmi,
      smokingStatus: smokingStatus ?? this.smokingStatus,
      systolicBp: systolicBp ?? this.systolicBp,
      diastolicBp: diastolicBp ?? this.diastolicBp,
      alcoholic: alcoholic ?? this.alcoholic,
      familyHistory: familyHistory ?? this.familyHistory,
      sleepHours: sleepHours ?? this.sleepHours,
      exerciseMins: exerciseMins ?? this.exerciseMins,
      excessSalt: excessSalt ?? this.excessSalt,
    );
  }
}

class TopFactor {
  final String feature;
  final double value;
  final double contribution;
  final String direction;

  const TopFactor({
    required this.feature,
    required this.value,
    required this.contribution,
    required this.direction,
  });

  factory TopFactor.fromJson(Map<String, dynamic> json) {
    return TopFactor(
      feature: (json['feature'] ?? '-').toString(),
      value: (json['value'] as num?)?.toDouble() ?? 0,
      contribution: (json['contribution'] as num?)?.toDouble() ?? 0,
      direction: (json['direction'] ?? 'increase').toString(),
    );
  }
}

class PredictionResult {
  final double riskProbability;
  final String riskLabel;
  final List<TopFactor> topFactors;
  final List<String> recommendations;
  final String interpretation;
  final String aiSummary;
  final String disclaimer;
  final Map<String, dynamic> assistantContext;
  final AiPlanPreview? aiPlanPreview;

  const PredictionResult({
    required this.riskProbability,
    required this.riskLabel,
    required this.topFactors,
    required this.recommendations,
    required this.interpretation,
    required this.aiSummary,
    required this.disclaimer,
    required this.assistantContext,
    this.aiPlanPreview,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final probability = _readProbability(json);
    final factors = (json['top_factors'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => TopFactor.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    final recommendations =
        (json['recommendations'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);

    return PredictionResult(
      riskProbability: probability,
      riskLabel: (json['risk_label'] ?? _fallbackLabel(probability)).toString(),
      topFactors: factors,
      recommendations: recommendations,
      interpretation: (json['interpretation'] ?? 'No interpretation available.')
          .toString(),
      aiSummary: (json['ai_summary'] ?? 'No AI summary available.').toString(),
      disclaimer:
          (json['disclaimer'] ??
                  'This output is informational and not a medical diagnosis.')
              .toString(),
      assistantContext: Map<String, dynamic>.from(
        json['assistant_context'] as Map? ?? const {},
      ),
      aiPlanPreview: _parseAiPlanPreview(json['ai_plan_preview']),
    );
  }

  static double _readProbability(Map<String, dynamic> json) {
    final raw =
        json['risk_probability'] ??
        json['stroke_prediction'] ??
        json['stroke_probability'];
    if (raw is num) {
      final value = raw.toDouble();
      if (value > 1) return value / 100.0;
      return value.clamp(0, 1);
    }
    return 0.0;
  }

  static String _fallbackLabel(double probability) {
    if (probability < 0.2) return 'Low';
    if (probability < 0.4) return 'Moderate';
    if (probability < 0.6) return 'Elevated';
    if (probability < 0.8) return 'High';
    return 'Very high';
  }

  static AiPlanPreview? _parseAiPlanPreview(dynamic raw) {
    if (raw is Map) {
      return AiPlanPreview.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

class HistoryRecord {
  final int id;
  final String timestamp;
  final double riskProbability;
  final String riskLabel;
  final Map<String, dynamic> inputPayload;
  final Map<String, dynamic> outputPayload;

  const HistoryRecord({
    required this.id,
    required this.timestamp,
    required this.riskProbability,
    required this.riskLabel,
    required this.inputPayload,
    required this.outputPayload,
  });

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      timestamp: (json['timestamp'] ?? '').toString(),
      riskProbability:
          (json['risk_probability'] as num?)?.toDouble() ??
          (json['riskProbability'] as num?)?.toDouble() ??
          0,
      riskLabel: (json['risk_label'] ?? '').toString(),
      inputPayload: Map<String, dynamic>.from(
        json['input_payload'] as Map? ?? const {},
      ),
      outputPayload: Map<String, dynamic>.from(
        json['output_payload'] as Map? ?? const {},
      ),
    );
  }
}

class SimulationChange {
  final String field;
  final dynamic before;
  final dynamic after;

  const SimulationChange({
    required this.field,
    required this.before,
    required this.after,
  });

  factory SimulationChange.fromJson(Map<String, dynamic> json) {
    return SimulationChange(
      field: (json['field'] ?? '').toString(),
      before: json['before'],
      after: json['after'],
    );
  }
}

class SimulationResult {
  final double baselineRiskProbability;
  final String baselineRiskLabel;
  final double simulatedRiskProbability;
  final String simulatedRiskLabel;
  final double deltaRiskProbability;
  final String deltaDirection;
  final List<SimulationChange> changedFactors;
  final String disclaimer;

  const SimulationResult({
    required this.baselineRiskProbability,
    required this.baselineRiskLabel,
    required this.simulatedRiskProbability,
    required this.simulatedRiskLabel,
    required this.deltaRiskProbability,
    required this.deltaDirection,
    required this.changedFactors,
    required this.disclaimer,
  });

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    final baseline = Map<String, dynamic>.from(
      json['baseline'] as Map? ?? const {},
    );
    final simulated = Map<String, dynamic>.from(
      json['simulated'] as Map? ?? const {},
    );
    final delta = Map<String, dynamic>.from(json['delta'] as Map? ?? const {});
    final changes = (json['changed_factors'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => SimulationChange.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);

    return SimulationResult(
      baselineRiskProbability:
          (baseline['risk_probability'] as num?)?.toDouble() ?? 0,
      baselineRiskLabel: (baseline['risk_label'] ?? '').toString(),
      simulatedRiskProbability:
          (simulated['risk_probability'] as num?)?.toDouble() ?? 0,
      simulatedRiskLabel: (simulated['risk_label'] ?? '').toString(),
      deltaRiskProbability:
          (delta['risk_probability'] as num?)?.toDouble() ?? 0,
      deltaDirection: (delta['direction'] ?? 'unchanged').toString(),
      changedFactors: changes,
      disclaimer:
          (json['disclaimer'] ??
                  'This output is informational and not a medical diagnosis.')
              .toString(),
    );
  }
}

class AiUserPreferences {
  final String dietType;
  final List<String> allergies;
  final List<String> cuisine;
  final String budget;
  final String activityLevel;
  final String goal;

  const AiUserPreferences({
    this.dietType = 'any',
    this.allergies = const [],
    this.cuisine = const [],
    this.budget = 'medium',
    this.activityLevel = 'light',
    this.goal = 'balanced',
  });

  Map<String, dynamic> toJson() {
    return {
      'diet_type': dietType,
      'allergies': allergies,
      'cuisine': cuisine,
      'budget': budget,
      'activity_level': activityLevel,
      'goal': goal,
    };
  }
}

class AiPlanPreviewPriority {
  final String title;
  final String why;

  const AiPlanPreviewPriority({required this.title, required this.why});

  factory AiPlanPreviewPriority.fromJson(Map<String, dynamic> json) {
    return AiPlanPreviewPriority(
      title: (json['title'] ?? '').toString(),
      why: (json['why'] ?? '').toString(),
    );
  }
}

class AiPlanPreview {
  final String summary;
  final List<AiPlanPreviewPriority> topPriorities;
  final String disclaimer;

  const AiPlanPreview({
    required this.summary,
    required this.topPriorities,
    required this.disclaimer,
  });

  factory AiPlanPreview.fromJson(Map<String, dynamic> json) {
    return AiPlanPreview(
      summary: (json['summary'] ?? '').toString(),
      topPriorities: (json['top_priorities'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (row) =>
                AiPlanPreviewPriority.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false),
      disclaimer:
          (json['disclaimer'] ??
                  'This output is informational and not a medical diagnosis.')
              .toString(),
    );
  }
}

class AiPlanPriority {
  final String title;
  final String why;
  final List<String> how;

  const AiPlanPriority({
    required this.title,
    required this.why,
    required this.how,
  });

  factory AiPlanPriority.fromJson(Map<String, dynamic> json) {
    return AiPlanPriority(
      title: (json['title'] ?? '').toString(),
      why: (json['why'] ?? '').toString(),
      how: (json['how'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class AiDietItem {
  final String name;
  final String portion;
  final String reason;

  const AiDietItem({
    required this.name,
    required this.portion,
    required this.reason,
  });

  factory AiDietItem.fromJson(Map<String, dynamic> json) {
    return AiDietItem(
      name: (json['name'] ?? '').toString(),
      portion: (json['portion'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

class AiDietDayPlan {
  final String meal;
  final List<AiDietItem> items;
  final List<String> avoid;

  const AiDietDayPlan({
    required this.meal,
    required this.items,
    required this.avoid,
  });

  factory AiDietDayPlan.fromJson(Map<String, dynamic> json) {
    return AiDietDayPlan(
      meal: (json['meal'] ?? '').toString(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((row) => AiDietItem.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      avoid: (json['avoid'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class AiDietDailyTargets {
  final double waterLiters;
  final int steps;
  final double sleepHours;

  const AiDietDailyTargets({
    required this.waterLiters,
    required this.steps,
    required this.sleepHours,
  });

  factory AiDietDailyTargets.fromJson(Map<String, dynamic> json) {
    return AiDietDailyTargets(
      waterLiters: (json['water_liters'] as num?)?.toDouble() ?? 2.0,
      steps: (json['steps'] as num?)?.toInt() ?? 7000,
      sleepHours: (json['sleep_hours'] as num?)?.toDouble() ?? 7.5,
    );
  }
}

class AiDietWeeklyPlan {
  final String day;
  final String focus;
  final List<String> meals;

  const AiDietWeeklyPlan({
    required this.day,
    required this.focus,
    required this.meals,
  });

  factory AiDietWeeklyPlan.fromJson(Map<String, dynamic> json) {
    return AiDietWeeklyPlan(
      day: (json['day'] ?? '').toString(),
      focus: (json['focus'] ?? '').toString(),
      meals: (json['meals'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class AiDietPlan {
  final List<String> notes;
  final AiDietDailyTargets dailyTargets;
  final List<AiDietDayPlan> dayPlan;
  final List<AiDietWeeklyPlan> weeklyPlan;

  const AiDietPlan({
    required this.notes,
    required this.dailyTargets,
    required this.dayPlan,
    required this.weeklyPlan,
  });

  factory AiDietPlan.fromJson(Map<String, dynamic> json) {
    return AiDietPlan(
      notes: (json['notes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      dailyTargets: AiDietDailyTargets.fromJson(
        Map<String, dynamic>.from(json['daily_targets'] as Map? ?? const {}),
      ),
      dayPlan: (json['day_plan'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((row) => AiDietDayPlan.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      weeklyPlan: (json['weekly_plan'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (row) => AiDietWeeklyPlan.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false),
    );
  }
}

class AiExerciseWeeklySchedule {
  final String day;
  final String workout;
  final int durationMin;
  final String intensity;

  const AiExerciseWeeklySchedule({
    required this.day,
    required this.workout,
    required this.durationMin,
    required this.intensity,
  });

  factory AiExerciseWeeklySchedule.fromJson(Map<String, dynamic> json) {
    return AiExerciseWeeklySchedule(
      day: (json['day'] ?? '').toString(),
      workout: (json['workout'] ?? '').toString(),
      durationMin: (json['duration_min'] as num?)?.toInt() ?? 20,
      intensity: (json['intensity'] ?? 'low').toString(),
    );
  }
}

class AiExercisePlan {
  final List<String> safetyNotes;
  final List<AiExerciseWeeklySchedule> weeklySchedule;
  final List<String> progression;

  const AiExercisePlan({
    required this.safetyNotes,
    required this.weeklySchedule,
    required this.progression,
  });

  factory AiExercisePlan.fromJson(Map<String, dynamic> json) {
    return AiExercisePlan(
      safetyNotes: (json['safety_notes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      weeklySchedule: (json['weekly_schedule'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (row) => AiExerciseWeeklySchedule.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false),
      progression: (json['progression'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class AiHabit {
  final String habit;
  final String target;
  final List<String> tips;

  const AiHabit({
    required this.habit,
    required this.target,
    required this.tips,
  });

  factory AiHabit.fromJson(Map<String, dynamic> json) {
    return AiHabit(
      habit: (json['habit'] ?? '').toString(),
      target: (json['target'] ?? '').toString(),
      tips: (json['tips'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class AiPlan {
  final String summary;
  final List<AiPlanPriority> topPriorities;
  final AiDietPlan dietPlan;
  final AiExercisePlan exercisePlan;
  final List<AiHabit> habits;
  final List<String> redFlags;
  final String disclaimer;

  const AiPlan({
    required this.summary,
    required this.topPriorities,
    required this.dietPlan,
    required this.exercisePlan,
    required this.habits,
    required this.redFlags,
    required this.disclaimer,
  });

  factory AiPlan.fromJson(Map<String, dynamic> json) {
    return AiPlan(
      summary: (json['summary'] ?? '').toString(),
      topPriorities: (json['top_priorities'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((row) => AiPlanPriority.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      dietPlan: AiDietPlan.fromJson(
        Map<String, dynamic>.from(json['diet_plan'] as Map? ?? const {}),
      ),
      exercisePlan: AiExercisePlan.fromJson(
        Map<String, dynamic>.from(json['exercise_plan'] as Map? ?? const {}),
      ),
      habits: (json['habits'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((row) => AiHabit.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      redFlags: (json['red_flags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      disclaimer:
          (json['disclaimer'] ??
                  'This output is informational and not a medical diagnosis.')
              .toString(),
    );
  }
}

class AiChatResponseData {
  final String answer;
  final String disclaimer;

  const AiChatResponseData({required this.answer, required this.disclaimer});

  factory AiChatResponseData.fromJson(Map<String, dynamic> json) {
    return AiChatResponseData(
      answer: (json['answer'] ?? '').toString(),
      disclaimer:
          (json['disclaimer'] ??
                  'This output is informational and not a medical diagnosis.')
              .toString(),
    );
  }
}
