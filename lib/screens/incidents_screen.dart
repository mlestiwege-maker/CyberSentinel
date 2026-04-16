import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/kpi_strip.dart';

class IncidentsScreen extends StatelessWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      currentRoute: '/incidents',
      title: 'Incident Response',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          KpiStrip(
            items: [
              KpiItem(
                label: 'Open Incidents',
                value: '3',
                icon: Icons.pending_actions,
                color: scheme.tertiary,
              ),
              KpiItem(
                label: 'Contained',
                value: '12',
                icon: Icons.check_circle,
                color: scheme.primary,
              ),
              KpiItem(
                label: 'Avg Response',
                value: '6m 40s',
                icon: Icons.timer,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Incidents Screen',
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Track open incidents and triage actions in one workflow.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const _IncidentTile(
            title: 'INC-2026-031 • Ransomware suspicious activity',
            subtitle: 'Owner: SOC Tier 2 • Status: Investigating',
            level: 'Critical',
          ),
          const SizedBox(height: 10),
          const _IncidentTile(
            title: 'INC-2026-032 • DDoS burst on API gateway',
            subtitle: 'Owner: Network Team • Status: Contained',
            level: 'High',
          ),
          const SizedBox(height: 10),
          const _IncidentTile(
            title: 'INC-2026-033 • Phishing report from staff',
            subtitle: 'Owner: IT SecOps • Status: Resolved',
            level: 'Medium',
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Response Playbook',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  const Text('1. Isolate affected endpoint or subnet'),
                  const Text('2. Preserve forensic artifacts'),
                  const Text('3. Trigger stakeholder notifications'),
                  const Text('4. Apply containment and verify recovery'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({
    required this.title,
    required this.subtitle,
    required this.level,
  });

  final String title;
  final String subtitle;
  final String level;

  Color _levelColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (level) {
      case 'Critical':
        return scheme.error;
      case 'High':
        return scheme.tertiary;
      case 'Medium':
      default:
        return scheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _levelColor(context).withValues(alpha: 0.15),
          child: Icon(Icons.report_gmailerrorred, color: _levelColor(context)),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Chip(label: Text(level)),
      ),
    );
  }
}
