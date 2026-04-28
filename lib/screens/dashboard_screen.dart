import '../widgets/security_graph.dart';
import '../widgets/alerts_table.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/kpi_strip.dart';
import '../widgets/simulation/threat_drill_panel.dart';
import '../data/threat_feed_service.dart';
import '../data/incident_api_client.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _asString(Object? value, {String fallback = 'N/A'}) {
    if (value == null) {
      return fallback;
    }
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  double _asDouble(Object? value, {double fallback = 0.0}) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Widget _buildConnectionBanner(BuildContext context, ThreatFeedService feed) {
    final connected = feed.isBackendConnected;
    final label = feed.connectionLabel;
    final lastSync = feed.lastSyncAt;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final color = connected ? scheme.primary : scheme.tertiary;
    final subtitle = lastSync == null
        ? 'Waiting for backend sync'
        : 'Last sync: ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}:${lastSync.second.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              connected ? Icons.cloud_done : Icons.cloud_off,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Chip(
              avatar: CircleAvatar(backgroundColor: color, radius: 5),
              label: Text(connected ? 'Connected' : 'Degraded'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(BuildContext context) {
    final feed = ThreatFeedService();
    final summary = feed.summary;
    final networkStatus = summary.anomalies > 6 ? 'Elevated Risk' : 'Secure';
    final scheme = Theme.of(context).colorScheme;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        buildCard(
          context,
          'Threats Detected',
          '${summary.activeThreats} Active Threats',
          Icons.warning,
          scheme.error,
        ),
        buildCard(
          context,
          'Network Status',
          networkStatus,
          Icons.network_check,
          networkStatus == 'Secure' ? scheme.primary : scheme.tertiary,
        ),
        buildCard(
          context,
          'New Alerts',
          '${summary.newAlerts} Alerts',
          Icons.notifications,
          scheme.tertiary,
        ),
        buildCard(
          context,
          'System Health',
          summary.anomalies > 8 ? 'Requires Attention' : 'Running Normally',
          Icons.health_and_safety,
          scheme.primary,
        ),
      ],
    );
  }

  Widget _buildMlInsightsPanel(BuildContext context, ThreatFeedService feed) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final info = feed.mlModelInfo;
    final scheduler = feed.mlSchedulerStatus;
    final importance = feed.mlFeatureImportance;
    final versions = feed.mlVersions;

    final status = _asString(info?['status'], fallback: 'unavailable');
    final activeVersion = _asString(info?['active_version']);
    final samples = _asString(info?['training_samples'], fallback: '0');
    final threshold = _asDouble(info?['alert_threshold']);
    final schedulerEnabled = scheduler?['enabled'] == true;
    final schedulerState = _asString(scheduler?['last_status'], fallback: 'idle');
    final schedulerInterval = _asString(scheduler?['interval_seconds'], fallback: '-');

    final importancesMap = (importance?['importances'] as Map?)
            ?.map((key, value) => MapEntry(key.toString(), _asDouble(value))) ??
        const <String, double>{};

    final sortedImportance = importancesMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final versionItems = (versions?['versions'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_alt_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'ML Control Center',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final ok = await feed.refreshMlInsights();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'ML insights refreshed' : 'ML insights refresh failed'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    status.toLowerCase() == 'trained' ? Icons.verified : Icons.warning_amber,
                    size: 16,
                    color: status.toLowerCase() == 'trained' ? scheme.primary : scheme.tertiary,
                  ),
                  label: Text('Status: $status'),
                ),
                Chip(label: Text('Active: $activeVersion')),
                Chip(label: Text('Samples: $samples')),
                Chip(label: Text('Threshold: ${threshold.toStringAsFixed(3)}')),
                Chip(label: Text('Scheduler: ${schedulerEnabled ? 'ON' : 'OFF'} ($schedulerState)')),
                Chip(label: Text('Interval: ${schedulerInterval}s')),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: feed.isAdministrator
                      ? () async {
                          final ok = await feed.trainMlModel(trainingEvents: 100);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'ML retraining completed'
                                    : 'ML retraining failed (see audit logs)'),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.model_training_outlined, size: 18),
                  label: const Text('Retrain Model'),
                ),
                OutlinedButton.icon(
                  onPressed: feed.isAdministrator
                      ? () async {
                          final ok = await feed.configureMlScheduler(
                            enabled: !schedulerEnabled,
                            intervalSeconds: 300,
                            trainingEvents: 100,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Scheduler ${schedulerEnabled ? 'disabled' : 'enabled'}'
                                    : 'Scheduler update failed'),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: Icon(
                    schedulerEnabled ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    size: 18,
                  ),
                  label: Text(schedulerEnabled ? 'Disable Scheduler' : 'Enable Scheduler'),
                ),
                OutlinedButton.icon(
                  onPressed: feed.isAdministrator
                      ? () async {
                          final ok = await feed.tuneMlThreshold(targetFalsePositiveRate: 0.20);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Threshold tuning completed'
                                    : 'Threshold tuning failed'),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Tune Threshold'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Feature Importance (SHAP / fallback)',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (sortedImportance.isEmpty)
              Text('No feature importance available yet. Train the model first.', style: textTheme.bodySmall)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortedImportance.take(5).map((entry) {
                  return Chip(
                    label: Text('${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%'),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            Text(
              'A/B Model Versions',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (versionItems.isEmpty)
              Text('No model versions available yet.', style: textTheme.bodySmall)
            else
              Column(
                children: versionItems.take(4).map((version) {
                  final versionId = _asString(version['version_id']);
                  final isActive = version['is_active'] == true;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isActive ? scheme.primary : null,
                    ),
                    title: Text('$versionId (slot ${_asString(version['slot'])})'),
                    subtitle: Text(
                      'Samples ${_asString(version['training_samples'])} · '
                      'Anomaly ${(100 * _asDouble(version['anomaly_rate'])).toStringAsFixed(1)}%',
                    ),
                    trailing: isActive
                        ? const Text('Active')
                        : TextButton(
                            onPressed: feed.isAdministrator
                                ? () async {
                                    final ok = await feed.switchMlVersion(versionId);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok
                                              ? 'Switched active model to $versionId'
                                              : 'Version switch failed'),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            child: const Text('Activate'),
                          ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ThreatFeedService();

    return AnimatedBuilder(
      animation: feed,
      builder: (context, _) {
        final summary = feed.summary;
        final latestAlerts = feed.latestAlerts;

        return AppScaffold(
          currentRoute: '/',
          title: 'CyberSentinel Dashboard',
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                 final sectionGap = 16.0;

                return ListView(
                  children: [
                    _buildConnectionBanner(context, feed),
                    const SizedBox(height: 12),
                    KpiStrip(
                      items: [
                        KpiItem(
                          label: 'Active Threats',
                          value: '${summary.activeThreats}',
                          icon: Icons.warning,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        KpiItem(
                          label: 'Investigations',
                          value: '${summary.investigations}',
                          icon: Icons.manage_search,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        KpiItem(
                          label: 'Auto Resolved',
                          value: '${summary.autoResolved}',
                          icon: Icons.done_all,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMetrics(context),
                    const SizedBox(height: 16),
                    _buildMlInsightsPanel(context, feed),
                    const SizedBox(height: 16),
                    ThreatDrillPanel(feed: feed, isWide: isWide),

                    SizedBox(height: sectionGap),
                    _buildSlaStatsPanel(context, feed),
                    SizedBox(height: sectionGap),

                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 360,
                              child: SecurityGraph(
                                trendPoints: feed.dailyThreatTrend,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 360,
                              child: AlertsTable(alerts: latestAlerts),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            height: 320,
                            child: SecurityGraph(
                              trendPoints: feed.dailyThreatTrend,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 320,
                            child: AlertsTable(alerts: latestAlerts),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
  Widget _buildSlaStatsPanel(BuildContext context, ThreatFeedService feed) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: IncidentApiClient.getSlaStats(),
      builder: (context, snapshot) {
        final sla = snapshot.hasData ? snapshot.data!['sla'] ?? {} : {};
        final avgResolve = sla['avg_resolution_time'];
        final avgClose = sla['avg_time_to_close'];

        String formatDuration(int? sec) {
          if (sec == null) return 'N/A';
          if (sec < 60) return '\${sec}s';
          if (sec < 3600) return '\${sec ~/ 60}m \${sec % 60}s';
          return '\${sec ~/ 3600}h \${(sec % 3600) ~/ 60}m';
        }

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('SLA Statistics', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [
                      Text('\$total', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      Text('Total', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    ]),
                    Column(children: [
                      Text('\$resolved', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                      Text('Resolved', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    ]),
                    Column(children: [
                      Text('\$closed', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
                      Text('Closed', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    ]),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(children: [
                      Text(formatDuration(avgResolve), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Avg Resolve', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                    ]),
                    Container(width: 1, height: 24, color: theme.colorScheme.outlineVariant),
                    Column(children: [
                      Text(formatDuration(avgClose), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Avg Close', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}