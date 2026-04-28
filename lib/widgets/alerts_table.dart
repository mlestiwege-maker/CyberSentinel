import 'package:flutter/material.dart';

import '../data/threat_feed_service.dart';

Color getSeverityColor(String severity) {
  switch (severity) {
    case "Critical":
      return const Color(0xFFD32F2F);
    case "High":
      return const Color(0xFFF57C00);
    case "Medium":
      return const Color(0xFFFBC02D);
    default:
      return const Color(0xFF2E7D32);
  }
}

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
    final base = getSeverityColor(severity);
    final bg = base.withValues(alpha: 0.14);
    final fg = (severity == "Critical" || severity == "High")
        ? base
        : Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: base.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: base,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            severity,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: scheme.onSurface,
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
              child: alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 34,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.75),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No alerts yet',
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You’re all clear for now. New detections will appear here.',
                            style: textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
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
                                    DataCell(_statusChip(context, alert.status)),
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