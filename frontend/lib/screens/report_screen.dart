import 'dart:async';

import 'package:flutter/material.dart';

import '../models/prediction_models.dart';
import '../services/api_client.dart';
import '../services/report_pdf_service.dart';
import '../state/app_state.dart';
import '../widgets/risk_gauge.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final ApiClient apiClient;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportPdfService _pdfService = ReportPdfService();
  bool _exporting = false;
  bool _generatingAiPlan = false;
  final Map<int, bool> _habitChecks = {};
  String _habitPlanSignature = '';

  Future<void> _exportReport(PredictionResult result, AiPlan? aiPlan) async {
    if (_exporting) {
      return;
    }
    setState(() => _exporting = true);
    try {
      await _pdfService.export(result, aiPlan: aiPlan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF export opened successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to export PDF report.')),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _generateAiPlan(
    PredictionResult result,
    PredictionRequestData? input,
  ) async {
    if (_generatingAiPlan || input == null) {
      return;
    }
    setState(() => _generatingAiPlan = true);
    try {
      final plan = await widget.apiClient.generateAiPlan(
        userInputs: input,
        predictionOutput: result,
      );
      widget.appState.setLatestAiPlan(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI plan generated.')));
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI plan request timed out.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to generate AI plan.')),
      );
    } finally {
      if (mounted) {
        setState(() => _generatingAiPlan = false);
      }
    }
  }

  void _syncHabitChecks(AiPlan? plan) {
    if (plan == null) {
      _habitChecks.clear();
      _habitPlanSignature = '';
      return;
    }
    final nextSignature = plan.habits
        .map(
          (habit) => '${habit.habit}|${habit.target}|${habit.tips.join(",")}',
        )
        .join('||');
    if (_habitPlanSignature == nextSignature) return;
    _habitChecks
      ..clear()
      ..addEntries(plan.habits.asMap().keys.map((idx) => MapEntry(idx, false)));
    _habitPlanSignature = nextSignature;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final result = widget.appState.latestResult;
        final aiPlan = widget.appState.latestAiPlan;
        final latestInput = widget.appState.latestInput;

        if (result == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monitor_heart_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No report yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Load the synthetic example in the Input tab to generate an educational scorecard.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        _syncHabitChecks(aiPlan);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Educational Scorecard',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (aiPlan == null)
                      FilledButton.tonalIcon(
                        onPressed: _generatingAiPlan
                            ? null
                            : () => _generateAiPlan(result, latestInput),
                        icon: _generatingAiPlan
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.psychology_outlined),
                        label: Text(
                          _generatingAiPlan
                              ? 'Generating...'
                              : 'Generate AI Plan',
                        ),
                      ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _exporting
                          ? null
                          : () => _exportReport(result, aiPlan),
                      icon: _exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(_exporting ? 'Exporting...' : 'Export PDF'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RiskGauge(
                  probability: result.riskProbability,
                  label: result.riskLabel,
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'Interpretation',
                  child: Text(result.interpretation),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'Top Factors',
                  child: Column(
                    children: result.topFactors
                        .map(
                          (factor) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(_pretty(factor.feature)),
                            subtitle: Text(
                              'Contribution: ${factor.contribution.toStringAsFixed(3)}',
                            ),
                            trailing: Text(
                              factor.direction,
                              style: TextStyle(
                                color: factor.direction == 'increase'
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'Recommendations',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.recommendations
                        .map(
                          (rec) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('- $rec'),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'AI Summary',
                  child: Text(result.aiSummary),
                ),
                const SizedBox(height: 12),
                _aiPlanSection(
                  context,
                  result: result,
                  aiPlan: aiPlan,
                  latestInput: latestInput,
                ),
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      aiPlan?.disclaimer ?? result.disclaimer,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _aiPlanSection(
    BuildContext context, {
    required PredictionResult result,
    required AiPlan? aiPlan,
    required PredictionRequestData? latestInput,
  }) {
    if (aiPlan == null) {
      final preview = result.aiPlanPreview;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Plan', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (preview != null) ...[
                Text(preview.summary),
                const SizedBox(height: 8),
                ...preview.topPriorities.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('- ${item.title}: ${item.why}'),
                  ),
                ),
              ] else
                const Text('No AI plan generated yet.'),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: _generatingAiPlan
                    ? null
                    : () => _generateAiPlan(result, latestInput),
                child: Text(
                  _generatingAiPlan ? 'Generating...' : 'Generate Full AI Plan',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final completedHabits = _habitChecks.values.where((v) => v).length;
    return Column(
      children: [
        _sectionCard(
          context,
          title: 'AI Plan Summary',
          child: Text(aiPlan.summary),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          context,
          title: 'Top Priorities',
          child: Column(
            children: aiPlan.topPriorities
                .map(
                  (priority) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(priority.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(priority.why),
                        ...priority.how.map((step) => Text('- $step')),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          context,
          title: 'Diet Plan (Day View)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily targets: water ${aiPlan.dietPlan.dailyTargets.waterLiters}L, '
                'steps ${aiPlan.dietPlan.dailyTargets.steps}, '
                'sleep ${aiPlan.dietPlan.dailyTargets.sleepHours}h',
              ),
              const SizedBox(height: 8),
              ...aiPlan.dietPlan.dayPlan.map(
                (meal) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.meal.toUpperCase(),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          ...meal.items.map(
                            (item) => Text(
                              '- ${item.name} (${item.portion}): ${item.reason}',
                            ),
                          ),
                          if (meal.avoid.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Avoid: ${meal.avoid.join(", ")}'),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          context,
          title: 'Exercise Weekly Schedule',
          child: Column(
            children: aiPlan.exercisePlan.weeklySchedule
                .map(
                  (row) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${row.day}: ${row.workout}'),
                    subtitle: Text(
                      '${row.durationMin} min - ${row.intensity} intensity',
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          context,
          title: 'Habits Checklist ($completedHabits/${aiPlan.habits.length})',
          child: Column(
            children: aiPlan.habits
                .asMap()
                .entries
                .map((entry) {
                  final index = entry.key;
                  final habit = entry.value;
                  return CheckboxListTile(
                    value: _habitChecks[index] ?? false,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(habit.habit),
                    subtitle: Text(
                      '${habit.target}\n${habit.tips.join(" - ")}',
                    ),
                    onChanged: (value) {
                      setState(() => _habitChecks[index] = value ?? false);
                    },
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  String _pretty(String name) {
    switch (name) {
      case 'systolic_bp':
        return 'Systolic BP';
      case 'diastolic_bp':
        return 'Diastolic BP';
      default:
        return name.replaceAll('_', ' ');
    }
  }
}
