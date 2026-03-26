import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/kpi_strip.dart';

class AlertRecord {
  const AlertRecord({
    required this.time,
    required this.attackType,
    required this.sourceIp,
    required this.severity,
    required this.status,
    required this.description,
  });

  final String time;
  final String attackType;
  final String sourceIp;
  final String severity;
  final String status;
  final String description;
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSeverity = 'All';

  static const _records = <AlertRecord>[
    AlertRecord(
      time: '10:15',
      attackType: 'DDoS',
      sourceIp: '192.168.1.10',
      severity: 'High',
      status: 'Blocked',
      description: 'Large inbound packet burst detected and auto-mitigated.',
    ),
    AlertRecord(
      time: '10:30',
      attackType: 'Ransomware',
      sourceIp: '192.168.1.22',
      severity: 'Critical',
      status: 'Investigating',
      description: 'Suspicious encryption behavior flagged on endpoint.',
    ),
    AlertRecord(
      time: '11:00',
      attackType: 'Phishing',
      sourceIp: '192.168.1.35',
      severity: 'Medium',
      status: 'Resolved',
      description: 'Credential-harvesting email link quarantined.',
    ),
    AlertRecord(
      time: '11:25',
      attackType: 'Port Scan',
      sourceIp: '192.168.1.44',
      severity: 'Low',
      status: 'Monitoring',
      description: 'Sequential destination port probing observed.',
    ),
  ];

  List<AlertRecord> get _filteredRecords {
    final query = _searchController.text.trim().toLowerCase();

    return _records.where((alert) {
      final matchesSeverity =
          _selectedSeverity == 'All' || alert.severity == _selectedSeverity;
      final matchesSearch = query.isEmpty ||
          alert.attackType.toLowerCase().contains(query) ||
          alert.sourceIp.toLowerCase().contains(query) ||
          alert.status.toLowerCase().contains(query);
      return matchesSeverity && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _severityColor(String severity, BuildContext context) {
    switch (severity) {
      case 'Critical':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return Colors.amber.shade700;
      case 'Low':
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredRecords;

    return AppScaffold(
      currentRoute: '/alerts',
      title: 'Alerts',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const KpiStrip(
            items: [
              KpiItem(
                label: 'Critical Open',
                value: '1',
                icon: Icons.report,
                color: Colors.red,
              ),
              KpiItem(
                label: 'High Severity',
                value: '4',
                icon: Icons.priority_high,
                color: Colors.orange,
              ),
              KpiItem(
                label: 'Resolved Today',
                value: '9',
                icon: Icons.verified,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Alerts Screen',
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
              hintText: 'Search by type, source IP, or status',
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
                    subtitle: Text('${alert.time} • ${alert.status}'),
                    trailing: const Icon(Icons.chevron_right),
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
  }
}

class AlertDetailsScreen extends StatelessWidget {
  const AlertDetailsScreen({
    required this.alert,
    super.key,
  });

  final AlertRecord alert;

  @override
  Widget build(BuildContext context) {
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
                  Text('Time: ${alert.time}'),
                  Text('Source IP: ${alert.sourceIp}'),
                  Text('Severity: ${alert.severity}'),
                  Text('Status: ${alert.status}'),
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