import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../data/threat_feed_service.dart';
import '../widgets/security_graph.dart';
import '../widgets/kpi_strip.dart';

class CommandCenterDashboardScreen extends StatelessWidget {
  const CommandCenterDashboardScreen({super.key});

  Future<void> _sendTwilioTrialSms(BuildContext context, ThreatFeedService feed) async {
    final ok = await feed.sendTestNotification(
      message: 'CyberSentinel Twilio trial notification from command center',
    );
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Twilio test dispatch requested. Check configured channels for delivery.'
              : 'Unable to send Twilio trial SMS. Verify admin role and channel configuration.',
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
        final scheme = Theme.of(context).colorScheme;

        return AppScaffold(
          currentRoute: '/',
          title: 'Command Center Dashboard',
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1400;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top KPI strip with threat summary
                    _buildKpiStrip(context, summary),

                    const SizedBox(height: 14),

                    // Main grid: Live Threat Feed (left), Metrics (right)
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Live Threat Feed
                          Expanded(
                            flex: 3,
                            child: _buildLiveThreatFeed(context, latestAlerts, scheme),
                          ),
                          const SizedBox(width: 16),

                          // Right: Incidents + Twilio
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildIncidentsOverviewPanel(context, summary, scheme),
                                const SizedBox(height: 14),
                                _buildTwilioIntegrationPanel(context, scheme, feed),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildLiveThreatFeed(context, latestAlerts, scheme),
                          const SizedBox(height: 14),
                          _buildIncidentsOverviewPanel(context, summary, scheme),
                          const SizedBox(height: 14),
                          _buildTwilioIntegrationPanel(context, scheme, feed),
                        ],
                      ),

                    const SizedBox(height: 14),

                    // Attack Map and Threat Detection Statistics
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildAttackMapPanel(context, scheme),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildSystemResourcesPanel(context, scheme),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildAttackMapPanel(context, scheme),
                          const SizedBox(height: 14),
                          _buildSystemResourcesPanel(context, scheme),
                        ],
                      ),

                    const SizedBox(height: 14),

                    // Bottom row: Threat Detection Stats + Top Attack Types
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 280,
                              child: SecurityGraph(trendPoints: feed.dailyThreatTrend),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildTopAttackTypesPanel(context, latestAlerts, scheme),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            height: 320,
                            child: SecurityGraph(trendPoints: feed.dailyThreatTrend),
                          ),
                          const SizedBox(height: 14),
                          _buildTopAttackTypesPanel(context, latestAlerts, scheme),
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

  Widget _buildKpiStrip(BuildContext context, ThreatSummary summary) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CyberSentinel Dashboard',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'REALTIME THREAT INTELLIGENCE',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white54,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        KpiStrip(
          items: [
            KpiItem(
              label: 'Threats Detected',
              value: '${summary.activeThreats}',
              icon: Icons.warning_rounded,
              color: scheme.error,
            ),
            KpiItem(
              label: 'High Risk Alerts',
              value: '${summary.highSeverity}',
              icon: Icons.priority_high_rounded,
              color: scheme.tertiary,
            ),
            KpiItem(
              label: 'Incidents',
              value: '${summary.investigations}',
              icon: Icons.warning_rounded,
              color: Colors.red[700],
            ),
            KpiItem(
              label: 'Resolved',
              value: '${summary.autoResolved}',
              icon: Icons.check_circle_rounded,
              color: Colors.green[600],
            ),
            KpiItem(
              label: 'Users Online',
              value: '5',
              icon: Icons.people_alt_rounded,
              color: Colors.purple[400],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveThreatFeed(BuildContext context, List<ThreatAlert> alerts, ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4D4D),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LIVE THREAT FEED',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Security Alerts',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white54,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/alerts'),
                  child: Text(
                    'View all',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                child: Column(
                  children: alerts.take(8).map((alert) {
                    final severityColor = _getSeverityColor(alert.severity);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 32,
                            decoration: BoxDecoration(
                              color: severityColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        alert.attackType,
                                        style:
                                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                      ),
                                    ),
                                    Text(
                                      '${(alert.confidence * 100).toStringAsFixed(0)}%',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Colors.white60,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${alert.sourceIp} • ${alert.status}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white54,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentsOverviewPanel(BuildContext context, ThreatSummary summary, ColorScheme scheme) {
    final totalIncidents = summary.investigations;
    final resolved = summary.autoResolved;
    final open = 8;
    final inProgress = 3;
    final closed = 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INCIDENTS OVERVIEW',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$totalIncidents',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white54,
                          ),
                    ),
                  ],
                ),
                _IncidentStatColumn(label: 'Open', value: open, color: Colors.red),
                _IncidentStatColumn(label: 'In Progress', value: inProgress, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DonutStatCircle(
                    value: 50,
                    color: Colors.green,
                    label: 'Resolved\n$resolved',
                  ),
                ),
                Expanded(
                  child: _DonutStatCircle(
                    value: 31,
                    color: scheme.primary,
                    label: 'Closed\n$closed',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwilioIntegrationPanel(
    BuildContext context,
    ColorScheme scheme,
    ThreatFeedService feed,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TWILIO SMS INTEGRATION',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Center(
                child: Icon(
                  Icons.sms_rounded,
                  color: scheme.tertiary,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Account SID',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              'ACa01b3c4d5e6f7g8h9i0j',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Auth Token',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              '44c0f7c8d9e0f1g2h3i4j',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Twilio Number',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              '+19734648388',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              'Trial Account. You can send messages to verified phone numbers only.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/settings');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Open Settings → Notification channels to configure SMS/Twilio routing.'),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Open SMS Settings'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _sendTwilioTrialSms(context, feed),
                icon: const Icon(Icons.sms),
                label: const Text('Send Free SMS (TRIAL)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttackMapPanel(BuildContext context, ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.orange[400],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ATTACK MAP (LIVE)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.public_rounded,
                    size: 120,
                    color: scheme.primary.withValues(alpha: 0.4),
                  ),
                  Center(
                    child: Text(
                      'Global Threat Map\n(Simulated)',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white38,
                          ),
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

  Widget _buildSystemResourcesPanel(BuildContext context, ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SYSTEM RESOURCES',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 14),
            _ResourceBar(label: 'CPU', value: 42, color: Colors.blue),
            const SizedBox(height: 12),
            _ResourceBar(label: 'RAM', value: 68, color: Colors.orange),
            const SizedBox(height: 12),
            _ResourceBar(label: 'DISK', value: 55, color: Colors.green),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      '1.2 MB/s',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Network In',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                Column(
                  children: [
                    Text(
                      '890 kB/s',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Network Out',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAttackTypesPanel(
      BuildContext context, List<ThreatAlert> alerts, ColorScheme scheme) {
    final attackCounts = <String, int>{};
    for (final alert in alerts) {
      attackCounts[alert.attackType] = (attackCounts[alert.attackType] ?? 0) + 1;
    }

    final sorted = attackCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOP ATTACK TYPES',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 14),
            ...sorted.take(5).map((entry) {
              final percent = ((entry.value / alerts.length) * 100).toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                              ),
                        ),
                        Text(
                          '${entry.value} ($percent%)',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (entry.value / alerts.length).clamp(0, 1),
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation(
                          Colors.primaries[(entry.key.hashCode % Colors.primaries.length)],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Critical':
        return const Color(0xFFFF4D4D);
      case 'High':
        return const Color(0xFFFFA500);
      case 'Medium':
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFF24D27E);
    }
  }
}

class _IncidentStatColumn extends StatelessWidget {
  const _IncidentStatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white54,
              ),
        ),
      ],
    );
  }
}

class _DonutStatCircle extends StatelessWidget {
  const _DonutStatCircle({
    required this.value,
    required this.color,
    required this.label,
  });

  final int value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Text(
                '$value%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white54,
              ),
        ),
      ],
    );
  }
}

class _ResourceBar extends StatelessWidget {
  const _ResourceBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              '$value%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
