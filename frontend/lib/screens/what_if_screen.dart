import 'dart:async';

import 'package:flutter/material.dart';

import '../models/prediction_models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';

class WhatIfScreen extends StatefulWidget {
  const WhatIfScreen({
    super.key,
    required this.apiClient,
    required this.appState,
  });

  final ApiClient apiClient;
  final AppState appState;

  @override
  State<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends State<WhatIfScreen> {
  PredictionRequestData? _seedInput;
  SimulationResult? _result;
  bool _loading = false;

  double _bmi = 24.0;
  double _sleepHours = 7.0;
  double _exerciseMins = 30.0;
  String _smoking = 'Never';

  void _syncWithLatestInput() {
    final latestInput = widget.appState.latestInput;
    if (latestInput == null || identical(_seedInput, latestInput)) {
      return;
    }
    _seedInput = latestInput;
    _bmi = latestInput.bmi;
    _sleepHours = latestInput.sleepHours.toDouble();
    _exerciseMins = latestInput.exerciseMins.toDouble();
    _smoking = latestInput.smokingStatus;
    _result = widget.appState.latestSimulation;
  }

  Future<void> _simulate() async {
    final baseline = widget.appState.latestInput;
    if (baseline == null) {
      return;
    }

    final overrides = <String, dynamic>{};
    if ((_bmi - baseline.bmi).abs() > 0.01) {
      overrides['bmi'] = double.parse(_bmi.toStringAsFixed(1));
    }
    if (_sleepHours.round() != baseline.sleepHours) {
      overrides['sleep'] = _sleepHours.round();
    }
    if (_exerciseMins.round() != baseline.exerciseMins) {
      overrides['exercise'] = _exerciseMins.round();
    }
    if (_smoking != baseline.smokingStatus) {
      overrides['smoking'] = _smoking.toLowerCase();
    }

    if (overrides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adjust at least one field to run simulation.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await widget.apiClient.simulate(
        baselineInput: baseline,
        overrides: overrides,
      );
      widget.appState.setLatestSimulation(response);
      if (!mounted) return;
      setState(() => _result = response);
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Simulation timed out. Please try again.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to run simulation right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        _syncWithLatestInput();
        final baselinePrediction = widget.appState.latestResult;
        final hasBaseline = _seedInput != null && baselinePrediction != null;

        if (!hasBaseline) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Generate an educational profile first. The What-If simulator uses that synthetic input as its baseline.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final baselineProbability =
            _result?.baselineRiskProbability ??
            baselinePrediction.riskProbability;
        final baselineLabel =
            _result?.baselineRiskLabel ?? baselinePrediction.riskLabel;
        final simulatedProbability = _result?.simulatedRiskProbability;
        final simulatedLabel = _result?.simulatedRiskLabel;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'What-If Simulator',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                _riskCard(
                  title: 'Baseline Score',
                  probability: baselineProbability,
                  label: baselineLabel,
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adjust Factors',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _sliderRow(
                          context,
                          label: 'BMI',
                          value: _bmi,
                          min: 10,
                          max: 50,
                          divisions: 80,
                          display: _bmi.toStringAsFixed(1),
                          onChanged: (value) => setState(() => _bmi = value),
                        ),
                        _sliderRow(
                          context,
                          label: 'Sleep Hours',
                          value: _sleepHours,
                          min: 0,
                          max: 12,
                          divisions: 24,
                          display: _sleepHours.toStringAsFixed(1),
                          onChanged: (value) =>
                              setState(() => _sleepHours = value),
                        ),
                        _sliderRow(
                          context,
                          label: 'Exercise Minutes',
                          value: _exerciseMins,
                          min: 0,
                          max: 180,
                          divisions: 36,
                          display: _exerciseMins.round().toString(),
                          onChanged: (value) =>
                              setState(() => _exerciseMins = value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _smoking,
                          decoration: const InputDecoration(
                            labelText: 'Smoking Status',
                            border: OutlineInputBorder(),
                          ),
                          items: const ['Never', 'Formerly', 'Smokes']
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _smoking = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _loading ? null : _simulate,
                          icon: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_graph),
                          label: Text(
                            _loading ? 'Simulating...' : 'Run What-If',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (simulatedProbability != null && simulatedLabel != null) ...[
                  const SizedBox(height: 10),
                  _riskCard(
                    title: 'Simulated Score',
                    probability: simulatedProbability,
                    label: simulatedLabel,
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 10),
                  _deltaCard(context, _result!),
                  const SizedBox(height: 10),
                  _changesCard(context, _result!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sliderRow(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            Text(display),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: display,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _riskCard({
    required String title,
    required double probability,
    required String label,
  }) {
    final percent = (probability * 100).toStringAsFixed(1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 6),
                  Text(
                    '$percent / 100',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F6FA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A6D86),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deltaCard(BuildContext context, SimulationResult result) {
    final delta = result.deltaRiskProbability;
    final deltaPct = (delta * 100).toStringAsFixed(2);
    final improved = delta < 0;
    final neutral = delta.abs() < 1e-6;

    final bgColor = neutral
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : improved
        ? const Color(0xFFE8F6EA)
        : const Color(0xFFFDEBEC);
    final fgColor = neutral
        ? Theme.of(context).colorScheme.onSurface
        : improved
        ? const Color(0xFF1B7F3C)
        : const Color(0xFFB3261E);

    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Score delta: ${delta > 0 ? '+' : ''}$deltaPct points',
                style: TextStyle(
                  color: fgColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              result.deltaDirection,
              style: TextStyle(color: fgColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _changesCard(BuildContext context, SimulationResult result) {
    final changes = result.changedFactors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Changed Factors',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (changes.isEmpty)
              const Text('No fields changed.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: changes
                    .map(
                      (change) => Chip(
                        label: Text(
                          '${change.field}: ${change.before} -> ${change.after}',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 8),
            Text(
              result.disclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
