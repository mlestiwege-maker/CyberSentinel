import '../widgets/security_graph.dart';
import '../widgets/alerts_table.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/kpi_strip.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Widget buildCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final textTheme = Theme.of(context).textTheme;

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
                      color: Colors.black87,
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
          '5 Active Threats',
          Icons.warning,
          Colors.red,
        ),
        buildCard(
          context,
          'Network Status',
          'Secure',
          Icons.network_check,
          Colors.green,
        ),
        buildCard(
          context,
          'New Alerts',
          '2 Alerts',
          Icons.notifications,
          Colors.orange,
        ),
        buildCard(
          context,
          'System Health',
          'Running Normally',
          Icons.health_and_safety,
          Colors.blue,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const KpiStrip(
                  items: [
                    KpiItem(
                      label: 'Active Threats',
                      value: '5',
                      icon: Icons.warning,
                      color: Colors.red,
                    ),
                    KpiItem(
                      label: 'Investigations',
                      value: '3',
                      icon: Icons.manage_search,
                      color: Colors.orange,
                    ),
                    KpiItem(
                      label: 'Auto Resolved',
                      value: '63',
                      icon: Icons.done_all,
                      color: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMetrics(context),
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Expanded(
                        child: SizedBox(
                          height: 360,
                          child: SecurityGraph(),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 360,
                          child: AlertsTable(),
                        ),
                      ),
                    ],
                  )
                else
                  const Column(
                    children: [
                      SizedBox(
                        height: 320,
                        child: SecurityGraph(),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        height: 320,
                        child: AlertsTable(),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}