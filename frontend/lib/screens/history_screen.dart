import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/prediction_models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.apiClient,
    required this.appState,
  });

  final ApiClient apiClient;
  final AppState appState;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      unawaited(_loadHistory());
    }
  }

  Future<void> _loadHistory() async {
    widget.appState.setHistoryLoading(true);
    try {
      final records = await widget.apiClient.fetchPredictions(limit: 20);
      widget.appState.setHistory(records);
    } on TimeoutException {
      widget.appState.setHistoryError('History request timed out. Please retry.');
    } on ApiException catch (e) {
      widget.appState.setHistoryError(e.message);
    } catch (_) {
      widget.appState.setHistoryError('Unable to load history right now.');
    } finally {
      widget.appState.setHistoryLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final loading = widget.appState.historyLoading;
        final error = widget.appState.historyError;
        final records = widget.appState.history;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Prediction History',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: loading ? null : _loadHistory,
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(loading ? 'Loading...' : 'Refresh'),
                      ),
                    ],
                  ),
                  if (widget.appState.historyFetchedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Last updated: ${widget.appState.historyFetchedAt}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (records.isNotEmpty) ...[
                    _HistoryTrendChart(records: records),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: records.isEmpty && loading
                        ? const Center(child: CircularProgressIndicator())
                        : records.isEmpty
                            ? const Center(child: Text('No predictions stored yet.'))
                            : ListView.separated(
                                itemCount: records.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final record = records[index];
                                  return _HistoryTile(record: record);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final HistoryRecord record;

  @override
  Widget build(BuildContext context) {
    final pct = (record.riskProbability * 100).toStringAsFixed(1);
    final date = DateTime.tryParse(record.timestamp);
    final timestamp = date == null ? record.timestamp : date.toLocal().toString();

    return Card(
      child: ListTile(
        title: Text('${record.riskLabel} risk ($pct%)'),
        subtitle: Text(timestamp),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Prediction Snapshot'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Text(
                  const JsonEncoder.withIndent('  ').convert({
                    'id': record.id,
                    'timestamp': record.timestamp,
                    'risk_label': record.riskLabel,
                    'risk_probability': record.riskProbability,
                    'input_payload': record.inputPayload,
                    'output_payload': record.outputPayload,
                  }),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTrendChart extends StatelessWidget {
  const _HistoryTrendChart({required this.records});

  final List<HistoryRecord> records;

  @override
  Widget build(BuildContext context) {
    final sorted = [...records]
      ..sort((a, b) {
        final aTime = DateTime.tryParse(a.timestamp);
        final bTime = DateTime.tryParse(b.timestamp);
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return -1;
        if (bTime == null) return 1;
        return aTime.compareTo(bTime);
      });
    final spots = sorted
        .asMap()
        .entries
        .map(
          (entry) => FlSpot(
            entry.key.toDouble(),
            (entry.value.riskProbability * 100).clamp(0, 100),
          ),
        )
        .toList(growable: false);

    final color = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Risk Trend (Last ${sorted.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Risk probability over time (%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 20,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final idx = spot.x.round().clamp(0, sorted.length - 1);
                          final row = sorted[idx];
                          final time = DateTime.tryParse(row.timestamp)?.toLocal();
                          final dateText = time == null
                              ? 'Unknown'
                              : '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          return LineTooltipItem(
                            '$dateText\n${spot.y.toStringAsFixed(1)}%',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList(growable: false);
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 20,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: _bottomInterval(sorted.length),
                        getTitlesWidget: (value, meta) {
                          final idx = value.round();
                          if (idx < 0 || idx >= sorted.length) {
                            return const SizedBox.shrink();
                          }
                          final time = DateTime.tryParse(sorted[idx].timestamp)?.toLocal();
                          if (time == null) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${time.month}/${time.day}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) =>
                            FlDotCirclePainter(radius: 2.5, color: color),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.12),
                      ),
                      spots: spots,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _bottomInterval(int count) {
    if (count <= 3) return 1;
    if (count <= 8) return 2;
    if (count <= 14) return 3;
    return 4;
  }
}
