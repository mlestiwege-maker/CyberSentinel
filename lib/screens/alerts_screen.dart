import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/kpi_strip.dart';
import '../widgets/alerts_table.dart';
import '../data/threat_feed_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSeverity = 'All';

  String _timeLabel(DateTime dateTime) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  List<ThreatAlert> _filteredRecords(List<ThreatAlert> records) {
    final query = _searchController.text.trim().toLowerCase();

    return records.where((alert) {
      final matchesSeverity =
          _selectedSeverity == 'All' || alert.severity == _selectedSeverity;
      final matchesSearch = query.isEmpty ||
          alert.attackType.toLowerCase().contains(query) ||
          alert.sourceIp.toLowerCase().contains(query) ||
          alert.status.toLowerCase().contains(query) ||
          alert.id.toLowerCase().contains(query);
      return matchesSeverity && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _severityColor(String severity, BuildContext context) {
    return getSeverityColor(severity);
  }

  @override
  Widget build(BuildContext context) {
    final feed = ThreatFeedService();

    return AnimatedBuilder(
      animation: feed,
      builder: (context, _) {
        final summary = feed.summary;
        final results = _filteredRecords(feed.latestAlerts);

        return AppScaffold(
          currentRoute: '/alerts',
          title: 'Alerts',
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              KpiStrip(
                items: [
                  KpiItem(
                    label: 'Critical Open',
                    value: '${summary.criticalOpen}',
                    icon: Icons.report,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  KpiItem(
                    label: 'High Severity',
                    value: '${summary.highSeverity}',
                    icon: Icons.priority_high,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  KpiItem(
                    label: 'Resolved Today',
                    value: '${summary.resolvedToday}',
                    icon: Icons.verified,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Threat Alerts Feed',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by ID, type, source IP, or status',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All', 'Critical', 'High', 'Medium', 'Low']
                    .map(
                      (severity) => ChoiceChip(
                        label: Text(severity),
                        selected: _selectedSeverity == severity,
                        onSelected: (_) {
                          setState(() {
                            _selectedSeverity = severity;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              if (results.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No alerts match your search/filter criteria.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              else
                ...results.map(
                  (alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _severityColor(alert.severity, context)
                              .withValues(alpha: 0.15),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: _severityColor(alert.severity, context),
                          ),
                        ),
                        title: Text('${alert.attackType} • ${alert.sourceIp}'),
                        subtitle: Text(
                          '${alert.id} • ${_timeLabel(alert.time)} • ${alert.status}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(alert.confidence * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlertDetailsScreen(alert: alert),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AlertDetailsScreen extends StatelessWidget {
  const AlertDetailsScreen({
    required this.alert,
    super.key,
  });

  final ThreatAlert alert;

  @override
  Widget build(BuildContext context) {
    final confidencePercent = (alert.confidence * 100).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.attackType,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text('Alert ID: ${alert.id}'),
                  Text('Time: ${alert.time}'),
                  Text('Source IP: ${alert.sourceIp}'),
                  Text('Severity: ${alert.severity}'),
                  Text('Status: ${alert.status}'),
                  Text('ML Confidence: $confidencePercent%'),
                  const SizedBox(height: 12),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(alert.description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}