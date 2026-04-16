import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/kpi_strip.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      currentRoute: '/reports',
      title: 'Reports & Analytics',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          KpiStrip(
            items: [
              KpiItem(
                label: 'MTTD',
                value: '2m 18s',
                icon: Icons.speed,
              ),
              KpiItem(
                label: 'Weekly Incidents',
                value: '47',
                icon: Icons.ssid_chart,
              ),
              KpiItem(
                label: 'Detection Accuracy',
                value: '94.6%',
                icon: Icons.gpp_good,
                color: scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Reports Screen',
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate SOC summaries and executive insights from threat events.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _ReportChip(icon: Icons.today, title: 'Daily Incident Report'),
                  _ReportChip(icon: Icons.calendar_month, title: 'Weekly Trends'),
                  _ReportChip(icon: Icons.shield, title: 'Risk Exposure Summary'),
                  _ReportChip(icon: Icons.download, title: 'Export PDF/CSV'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.assessment_outlined),
                  title: Text('Top Threat Type: Ransomware'),
                  subtitle: Text('31% of incidents over the last 7 days'),
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.speed_outlined),
                  title: Text('Mean Time To Detect (MTTD)'),
                  subtitle: Text('2m 18s • improved by 15% this week'),
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.done_all),
                  title: Text('Auto-Resolved Alerts'),
                  subtitle: Text('63 events resolved by policy actions'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportChip extends StatelessWidget {
  const _ReportChip({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(title),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }
}
