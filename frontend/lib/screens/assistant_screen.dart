import 'dart:async';

import 'package:flutter/material.dart';

import '../models/prediction_models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final ApiClient apiClient;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;
  bool _generatingPlan = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({
    required PredictionResult prediction,
    required PredictionRequestData? input,
    required AiPlan? aiPlan,
  }) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _sending = true;
    });
    _messageController.clear();

    try {
      final response = await widget.apiClient.aiChat(
        message: text,
        userInputs: input,
        predictionOutput: prediction,
        aiPlan: aiPlan,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            text: response.answer,
            disclaimer: response.disclaimer,
          ),
        );
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage(
            role: 'assistant',
            text: 'Assistant request timed out. Please try again.',
          ),
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: e.message));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage(
            role: 'assistant',
            text: 'Unable to fetch assistant response right now.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _generatePlan(
    PredictionResult prediction,
    PredictionRequestData? input,
  ) async {
    if (input == null || _generatingPlan) {
      return;
    }
    setState(() => _generatingPlan = true);
    try {
      final plan = await widget.apiClient.generateAiPlan(
        userInputs: input,
        predictionOutput: prediction,
      );
      widget.appState.setLatestAiPlan(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI plan generated for assistant context.'),
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
        const SnackBar(content: Text('Unable to generate AI plan right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _generatingPlan = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final prediction = widget.appState.latestResult;
        final input = widget.appState.latestInput;
        final aiPlan = widget.appState.latestAiPlan;
        final aiPreview = prediction?.aiPlanPreview;

        if (prediction == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No educational profile is available yet. Generate one from synthetic inputs before using the assistant.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'AI Assistant',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Latest AI Plan Context',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              if (aiPlan != null) ...[
                                Text(aiPlan.summary),
                                const SizedBox(height: 8),
                                ...aiPlan.topPriorities
                                    .take(3)
                                    .map((p) => Text('- ${p.title}: ${p.why}')),
                                const SizedBox(height: 8),
                                Text(
                                  aiPlan.disclaimer,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ] else if (aiPreview != null) ...[
                                Text(aiPreview.summary),
                                const SizedBox(height: 8),
                                ...aiPreview.topPriorities
                                    .take(3)
                                    .map((p) => Text('- ${p.title}: ${p.why}')),
                                const SizedBox(height: 8),
                                Text(
                                  aiPreview.disclaimer,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                FilledButton.tonalIcon(
                                  onPressed: _generatingPlan
                                      ? null
                                      : () => _generatePlan(prediction, input),
                                  icon: _generatingPlan
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.psychology_outlined),
                                  label: Text(
                                    _generatingPlan
                                        ? 'Generating...'
                                        : 'Generate Full AI Plan',
                                  ),
                                ),
                              ] else ...[
                                const Text(
                                  'No full AI plan yet. Generate one to improve assistant answers.',
                                ),
                                const SizedBox(height: 8),
                                FilledButton.tonalIcon(
                                  onPressed: _generatingPlan
                                      ? null
                                      : () => _generatePlan(prediction, input),
                                  icon: _generatingPlan
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.psychology_outlined),
                                  label: Text(
                                    _generatingPlan
                                        ? 'Generating...'
                                        : 'Generate AI Plan',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Not medical advice. Use this assistant for educational planning and consult a clinician for diagnosis or treatment decisions.',
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_messages.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Ask about diet, exercise, sleep, smoking reduction, or how to prioritize your weekly actions.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        ..._messages.map((m) => _ChatBubble(message: m)),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Ask assistant',
                              hintText:
                                  'What are the top 3 things to focus this week?',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _sendMessage(
                              prediction: prediction,
                              input: input,
                              aiPlan: aiPlan,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _sendMessage(
                                  prediction: prediction,
                                  input: input,
                                  aiPlan: aiPlan,
                                ),
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(_sending ? 'Sending...' : 'Send'),
                        ),
                      ],
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
}

class _ChatMessage {
  final String role;
  final String text;
  final String? disclaimer;

  const _ChatMessage({required this.role, required this.text, this.disclaimer});
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final bgColor = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerLowest;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text),
            if (message.disclaimer != null &&
                message.disclaimer!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message.disclaimer!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
