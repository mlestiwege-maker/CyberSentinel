import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/kpi_strip.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentRoute: '/monitoring',
      title: 'Network Monitoring',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          KpiStrip(
            items: [
              KpiItem(
                label: 'Monitored Hosts',
                value: '128',
                icon: Icons.devices,
              ),
              KpiItem(
                label: 'Packets / sec',
                value: '14.2k',
                icon: Icons.timeline,
              ),
              KpiItem(
                label: 'Anomalies',
                value: '7',
                icon: Icons.insights,
                color: Colors.orange,
              ),
            ],
          ),
          SizedBox(height: 14),
          Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Monitoring Screen',
                style: TextStyle(fontSize: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}