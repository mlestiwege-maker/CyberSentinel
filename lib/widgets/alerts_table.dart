import 'package:flutter/material.dart';

import '../data/threat_feed_service.dart';

class AlertsTable extends StatelessWidget {
  const AlertsTable({
    required this.alerts,
    super.key,
  });

  final List<ThreatAlert> alerts;

  String _timeLabel(DateTime dateTime) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _severityChip(BuildContext context, String severity) {
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;

    switch (severity) {
      case 'Critical':
        bg = scheme.errorContainer.withValues(alpha: 0.6);
        fg = scheme.onErrorContainer;
        break;
      case 'High':
        bg = scheme.tertiaryContainer.withValues(alpha: 0.65);
        fg = scheme.onTertiaryContainer;
        break;
      case 'Medium':
      default:
        bg = scheme.secondaryContainer.withValues(alpha: 0.6);
        fg = scheme.onSecondaryContainer;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        severity,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Security Alerts',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    ),
                    columns: const [
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('Attack Type')),
                      DataColumn(label: Text('Source IP')),
                      DataColumn(label: Text('Severity')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: alerts
                        .take(8)
                        .map(
                          (alert) => DataRow(
                            cells: [
                              DataCell(Text(_timeLabel(alert.time))),
                              DataCell(Text(alert.attackType)),
                              DataCell(Text(alert.sourceIp)),
                              DataCell(_severityChip(context, alert.severity)),
                              DataCell(Text(alert.status)),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}