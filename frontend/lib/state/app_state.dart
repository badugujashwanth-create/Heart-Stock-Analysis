import 'package:flutter/foundation.dart';

import '../models/prediction_models.dart';

class AppState extends ChangeNotifier {
  PredictionResult? _latestResult;
  PredictionRequestData? _latestInput;
  SimulationResult? _latestSimulation;
  AiPlan? _latestAiPlan;
  List<HistoryRecord> _history = const [];
  bool _historyLoading = false;
  String? _historyError;
  DateTime? _historyFetchedAt;

  PredictionResult? get latestResult => _latestResult;
  PredictionRequestData? get latestInput => _latestInput;
  SimulationResult? get latestSimulation => _latestSimulation;
  AiPlan? get latestAiPlan => _latestAiPlan;
  List<HistoryRecord> get history => _history;
  bool get historyLoading => _historyLoading;
  String? get historyError => _historyError;
  DateTime? get historyFetchedAt => _historyFetchedAt;

  void setLatestResult(PredictionResult result) {
    _latestResult = result;
    _latestSimulation = null;
    _latestAiPlan = null;
    notifyListeners();
  }

  void setLatestInput(PredictionRequestData input) {
    _latestInput = input;
    _latestSimulation = null;
    _latestAiPlan = null;
    notifyListeners();
  }

  void setLatestSimulation(SimulationResult simulation) {
    _latestSimulation = simulation;
    notifyListeners();
  }

  void setLatestAiPlan(AiPlan plan) {
    _latestAiPlan = plan;
    notifyListeners();
  }

  void setHistoryLoading(bool value) {
    _historyLoading = value;
    if (value) {
      _historyError = null;
    }
    notifyListeners();
  }

  void setHistory(List<HistoryRecord> records) {
    _history = records;
    _historyError = null;
    _historyFetchedAt = DateTime.now();
    notifyListeners();
  }

  void setHistoryError(String message) {
    _historyError = message;
    notifyListeners();
  }
}
