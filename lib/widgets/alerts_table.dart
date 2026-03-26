import 'package:flutter/material.dart';

class AlertsTable extends StatelessWidget {
  const AlertsTable({super.key});

  Widget _severityChip(String severity) {
    Color bg;
    Color fg;

    switch (severity) {
      case 'Critical':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      case 'High':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        break;
      case 'Medium':
      default:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
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
                    rows: [
                      DataRow(
                        cells: [
                          const DataCell(Text('10:15')),
                          const DataCell(Text('DDoS')),
                          const DataCell(Text('192.168.1.10')),
                          DataCell(_severityChip('High')),
                          const DataCell(Text('Blocked')),
                        ],
                      ),
                      DataRow(
                        cells: [
                          const DataCell(Text('10:30')),
                          const DataCell(Text('Ransomware')),
                          const DataCell(Text('192.168.1.22')),
                          DataCell(_severityChip('Critical')),
                          const DataCell(Text('Investigating')),
                        ],
                      ),
                      DataRow(
                        cells: [
                          const DataCell(Text('11:00')),
                          const DataCell(Text('Phishing')),
                          const DataCell(Text('192.168.1.35')),
                          DataCell(_severityChip('Medium')),
                          const DataCell(Text('Resolved')),
                        ],
                      ),
                    ],
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