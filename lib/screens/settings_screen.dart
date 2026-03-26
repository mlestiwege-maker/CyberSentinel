import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/kpi_strip.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.isDarkMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _isDarkMode = widget.isDarkMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentRoute: '/settings',
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const KpiStrip(
            items: [
              KpiItem(
                label: 'Policy Profiles',
                value: '4',
                icon: Icons.policy,
              ),
              KpiItem(
                label: 'Notification Channels',
                value: '2',
                icon: Icons.notifications_active,
              ),
              KpiItem(
                label: 'Theme',
                value: 'Configurable',
                icon: Icons.tune,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Settings Screen',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  subtitle: const Text('Use a low-light theme for the dashboard'),
                  value: _isDarkMode,
                  onChanged: (value) {
                    setState(() {
                      _isDarkMode = value;
                    });
                    widget.onThemeModeChanged(value);
                  },
                ),
                const Divider(height: 0),
                const ListTile(
                  leading: Icon(Icons.notifications_active_outlined),
                  title: Text('Alert notifications'),
                  subtitle: Text('Push alerts and email preferences (coming soon)'),
                ),
                const Divider(height: 0),
                const ListTile(
                  leading: Icon(Icons.security_outlined),
                  title: Text('Security profile'),
                  subtitle: Text('Threat sensitivity and severity settings (coming soon)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}