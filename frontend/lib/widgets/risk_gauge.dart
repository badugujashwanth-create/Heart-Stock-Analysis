import 'package:flutter/material.dart';

class RiskGauge extends StatelessWidget {
  final double probability;
  final String label;

  const RiskGauge({super.key, required this.probability, required this.label});

  Color _labelColor(BuildContext context) {
    if (probability >= 0.8) return Colors.red.shade800;
    if (probability >= 0.6) return Colors.deepOrange.shade700;
    if (probability >= 0.4) return Colors.orange.shade700;
    if (probability >= 0.2) return Colors.amber.shade800;
    return Colors.green.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (probability * 100).clamp(0, 100).toDouble();
    final color = _labelColor(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Risk Gauge', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: probability.clamp(0, 1),
              minHeight: 12,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${pct.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.headlineSmall),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
