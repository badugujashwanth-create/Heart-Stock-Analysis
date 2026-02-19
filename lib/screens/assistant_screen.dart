import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthAssistantScreen extends StatefulWidget {
  const HealthAssistantScreen({super.key});

  @override
  State<HealthAssistantScreen> createState() => _HealthAssistantScreenState();
}

class _HealthAssistantScreenState extends State<HealthAssistantScreen> {
  final _controller = TextEditingController();
  final List<_Msg> _messages = [];
  bool _typing = false;
  static const _historyKey = 'chat_history_v1';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) {
      setState(() {
        _messages.add(const _Msg(
          bot: true,
          text:
              'Hi! I\'m your health assistant. Ask about blood pressure, diet, exercise, smoking, alcohol, glucose, or your latest prediction.',
        ));
      });
      return;
    }
    try {
      final list = (jsonDecode(raw) as List).cast<Map>().toList();
      for (final m in list) {
        _messages.add(_Msg(bot: m['bot'] == true, text: m['text'] as String? ?? ''));
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Start fresh if corrupted.
      setState(() {
        _messages.clear();
        _messages.add(const _Msg(
          bot: true,
          text:
              'Hi! I\'m your health assistant. Ask about blood pressure, diet, exercise, smoking, alcohol, glucose, or your latest prediction.',
        ));
      });
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _messages.map((m) => {'bot': m.bot, 'text': m.text}).toList();
    await prefs.setString(_historyKey, jsonEncode(data));
  }

  void _send({String? preset}) {
    final txt = (preset ?? _controller.text).trim();
    if (txt.isEmpty) return;
    setState(() {
      _messages.add(_Msg(bot: false, text: txt));
      _controller.clear();
      _typing = true;
    });
    Future.delayed(const Duration(milliseconds: 450), () async {
      final botText = await _reply(txt);
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(bot: true, text: botText));
        _typing = false;
      });
      _saveHistory();
    });
  }

  Future<String> _reply(String input) async {
    final q = input.toLowerCase();

    // Link to latest prediction if asked.
    if (q.contains('result') || q.contains('risk') || q.contains('prediction')) {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString('last_prediction');
      final time = prefs.getString('last_prediction_time');
      if (val != null && val.isNotEmpty) {
        final pct = (double.tryParse(val) ?? 0) * 100;
        final level = pct >= 75
            ? 'very high'
            : pct >= 50
                ? 'high'
                : pct >= 25
                    ? 'moderate'
                    : 'low';
        return 'Your latest prediction is ${pct.toStringAsFixed(0)}% ($level risk) at ${time ?? 'unknown time'}.\n\nSuggestions:\n- Keep BP under control\n- 150 mins/week exercise\n- Reduce salt and avoid smoking\n- Discuss with your clinician.';
      }
      return 'I couldn\'t find a saved prediction yet. Try running a prediction from the Home tab first.';
    }

    if (q.contains('blood pressure') || q.contains('bp') || q.contains('hypertension')) {
      return 'Blood pressure goals: ideally <120/80 mmHg.\n- Limit salt <5g/day\n- Exercise most days\n- Maintain healthy weight\n- Take meds as prescribed\n- Check BP regularly (home monitor recommended).';
    }
    if (q.contains('diet') || q.contains('food') || q.contains('nutrition')) {
      return 'Heart-healthy diet:\n- Fruits/veggies, whole grains\n- Lean protein (fish, legumes)\n- Unsalted nuts, olive/canola oil\n- Limit processed foods, sugary drinks, and excess salt.';
    }
    if (q.contains('exercise') || q.contains('workout') || q.contains('walk') || q.contains('activity')) {
      return 'Exercise target: 150 min/week moderate (e.g., brisk walking) + 2 days strength training. Start slow and build up; even 10-15 min sessions help.';
    }
    if (q.contains('smok')) {
      return 'Quitting smoking reduces stroke risk quickly.\n- Set a quit date\n- Remove triggers\n- Consider NRT (patch/gum)\n- Get support (counseling/app)\n- If you slip, try again; relapse is common.';
    }
    if (q.contains('alcohol') || q.contains('drink')) {
      return 'Keep alcohol to moderate levels or avoid. Excess drinking raises blood pressure and stroke risk. Hydrate and plan alcohol-free days.';
    }
    if (q.contains('glucose') || q.contains('diabetes') || q.contains('sugar')) {
      return 'Keep glucose in target range. Combine diet, activity, adequate sleep, and medications as prescribed. Monitor A1c with your clinician.';
    }
    if (q == 'clear' || q == '/clear') {
      await _clearHistory();
      return 'Cleared previous conversation.';
    }
    return 'I can help with blood pressure, diet, exercise, smoking, alcohol, glucose, or your latest prediction. Try: "How to lower BP?" or "Explain my result"';
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    setState(() {
      _messages
        ..clear()
        ..add(const _Msg(bot: true, text: 'History cleared. How can I help today?'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Assistant'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearHistory,
          )
        ],
      ),
      body: Column(
        children: [
          // Suggestions
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _chip('Lower BP'),
                _chip('Diet plan'),
                _chip('Quit smoking'),
                _chip('Exercise routine'),
                _chip('Explain my result'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_typing ? 1 : 0),
              itemBuilder: (_, i) {
                if (_typing && i == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: _TypingDots(),
                    ),
                  );
                }
                final m = _messages[i];
                final align = m.bot ? Alignment.centerLeft : Alignment.centerRight;
                final theme = Theme.of(context);
                final color = m.bot ? theme.colorScheme.secondaryContainer : theme.colorScheme.primary;
                final txtColor = m.bot ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onPrimary;
                return Align(
                  alignment: align,
                  child: GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: m.text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(m.text, style: TextStyle(color: txtColor)),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(30))),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary), onPressed: _send),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ActionChip(
        label: Text(label),
        onPressed: () {
          switch (label) {
            case 'Lower BP':
              _send(preset: 'How can I lower my blood pressure?');
              break;
            case 'Diet plan':
              _send(preset: 'What is a heart-healthy diet plan?');
              break;
            case 'Quit smoking':
              _send(preset: 'How do I quit smoking?');
              break;
            case 'Exercise routine':
              _send(preset: 'Give me an exercise routine to reduce stroke risk.');
              break;
            case 'Explain my result':
              _send(preset: 'Explain my latest prediction result.');
              break;
          }
        },
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final active = (3 * _c.value).floor() % 3 + 1;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final on = i < active;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: on ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _Msg {
  final bool bot;
  final String text;

  const _Msg({required this.bot, required this.text});
}
