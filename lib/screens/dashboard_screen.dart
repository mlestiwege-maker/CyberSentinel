import '../widgets/security_graph.dart';
import '../widgets/alerts_table.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/kpi_strip.dart';
import '../data/threat_feed_service.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
}