import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/prediction_models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';

class FormScreen extends StatefulWidget {
  final ApiClient apiClient;
  final AppState appState;
  final VoidCallback onPredictionCreated;

  const FormScreen({
    super.key,
    required this.apiClient,
    required this.appState,
    required this.onPredictionCreated,
  });

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _age = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _glucose = TextEditingController();
  final _bmi = TextEditingController();
  final _sleep = TextEditingController();
  final _exercise = TextEditingController();

  String _gender = 'Male';
  String _hypertension = 'No';
  String _heartDisease = 'No';
  String _married = 'Yes';
  String _workType = 'Private';
  String _residence = 'Urban';
  String _smoking = 'Never';
  String _alcohol = 'No';
  String _familyHistory = 'No';
  String _excessSalt = 'No';

  bool _loading = false;

  @override
  void dispose() {
    _age.dispose();
    _systolic.dispose();
    _diastolic.dispose();
    _glucose.dispose();
    _bmi.dispose();
    _sleep.dispose();
    _exercise.dispose();
    super.dispose();
  }

  void _loadSyntheticExample() {
    setState(() {
      _age.text = '56';
      _systolic.text = '148';
      _diastolic.text = '92';
      _glucose.text = '132.5';
      _bmi.text = '27.2';
      _sleep.text = '6';
      _exercise.text = '25';
      _gender = 'Male';
      _hypertension = 'Yes';
      _heartDisease = 'No';
      _married = 'Yes';
      _workType = 'Private';
      _residence = 'Urban';
      _smoking = 'Formerly';
      _alcohol = 'No';
      _familyHistory = 'Yes';
      _excessSalt = 'Yes';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Synthetic example loaded. No real patient data is used.',
        ),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      for (final controller in [
        _age,
        _systolic,
        _diastolic,
        _glucose,
        _bmi,
        _sleep,
        _exercise,
      ]) {
        controller.clear();
      }
      _gender = 'Male';
      _hypertension = 'No';
      _heartDisease = 'No';
      _married = 'Yes';
      _workType = 'Private';
      _residence = 'Urban';
      _smoking = 'Never';
      _alcohol = 'No';
      _familyHistory = 'No';
      _excessSalt = 'No';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final request = PredictionRequestData(
        age: int.parse(_age.text.trim()),
        gender: _gender,
        hypertension: _hypertension,
        heartDisease: _heartDisease,
        everMarried: _married,
        workType: _workType,
        residenceType: _residence,
        avgGlucoseLevel: double.parse(_glucose.text.trim()),
        bmi: double.parse(_bmi.text.trim()),
        smokingStatus: _smoking,
        systolicBp: int.parse(_systolic.text.trim()),
        diastolicBp: int.parse(_diastolic.text.trim()),
        alcoholic: _alcohol,
        familyHistory: _familyHistory,
        sleepHours: int.parse(_sleep.text.trim()),
        exerciseMins: int.parse(_exercise.text.trim()),
        excessSalt: _excessSalt,
      );

      final result = await widget.apiClient.predict(request);
      widget.appState.setLatestInput(request);
      widget.appState.setLatestResult(result);

      try {
        final aiPlan = await widget.apiClient.generateAiPlan(
          userInputs: request,
          predictionOutput: result,
        );
        widget.appState.setLatestAiPlan(aiPlan);
      } on ApiException {
        // Keep core prediction flow available even if AI plan generation fails.
      } catch (_) {
        // Keep core prediction flow available even if AI plan generation fails.
      }

      if (!mounted) return;
      widget.onPredictionCreated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Educational profile generated.')),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please try again.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error occurred.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth > 900 ? 760.0 : double.infinity;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: maxWidth,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Educational Stroke Profile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.science_outlined),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Synthetic data only. This unvalidated heuristic demonstrates explainable scoring; it is not a medical risk estimate or diagnostic tool.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _loadSyntheticExample,
                          icon: const Icon(Icons.auto_fix_high_outlined),
                          label: const Text('Load synthetic example'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _clearForm,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle(context, 'Profile context'),
                    _numberField(_age, 'Age', min: 1, max: 120),
                    _dropdown('Gender', _gender, const [
                      'Male',
                      'Female',
                      'Other',
                    ], (v) => _gender = v),
                    _dropdown('Hypertension', _hypertension, const [
                      'Yes',
                      'No',
                    ], (v) => _hypertension = v),
                    _dropdown('Heart Disease', _heartDisease, const [
                      'Yes',
                      'No',
                    ], (v) => _heartDisease = v),
                    _dropdown('Ever Married', _married, const [
                      'Yes',
                      'No',
                    ], (v) => _married = v),
                    _dropdown('Work Type', _workType, const [
                      'Private',
                      'Self-employed',
                      'Govt',
                      'Children',
                      'Never worked',
                    ], (v) => _workType = v),
                    _dropdown('Residence Type', _residence, const [
                      'Urban',
                      'Rural',
                    ], (v) => _residence = v),
                    const SizedBox(height: 4),
                    _sectionTitle(context, 'Health indicators'),
                    _numberField(_systolic, 'Systolic BP', min: 60, max: 260),
                    _numberField(_diastolic, 'Diastolic BP', min: 30, max: 180),
                    _numberField(
                      _glucose,
                      'Average Glucose Level',
                      decimal: true,
                      min: 20,
                      max: 600,
                    ),
                    _numberField(_bmi, 'BMI', decimal: true, min: 10, max: 80),
                    const SizedBox(height: 4),
                    _sectionTitle(context, 'Lifestyle context'),
                    _dropdown('Smoking Status', _smoking, const [
                      'Never',
                      'Formerly',
                      'Smokes',
                    ], (v) => _smoking = v),
                    _numberField(_sleep, 'Sleep Hours / day', min: 0, max: 24),
                    _numberField(
                      _exercise,
                      'Exercise Minutes / day',
                      min: 0,
                      max: 600,
                    ),
                    _dropdown('Alcoholic', _alcohol, const [
                      'Yes',
                      'No',
                    ], (v) => _alcohol = v),
                    _dropdown('Family History', _familyHistory, const [
                      'Yes',
                      'No',
                    ], (v) => _familyHistory = v),
                    _dropdown('Excess Salt', _excessSalt, const [
                      'Yes',
                      'No',
                    ], (v) => _excessSalt = v),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.insights),
                      label: Text(
                        _loading
                            ? 'Generating...'
                            : 'Generate educational profile',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool decimal = false,
    required num min,
    required num max,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          if (decimal)
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          else
            FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Required';
          final parsed = decimal ? double.tryParse(text) : int.tryParse(text);
          if (parsed == null) return 'Invalid number';
          if (parsed < min || parsed > max) {
            return 'Must be between $min and $max';
          }
          return null;
        },
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (newValue) {
          if (newValue == null) return;
          setState(() => onChanged(newValue));
        },
      ),
    );
  }
}
