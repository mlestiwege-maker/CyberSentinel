import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/kpi_strip.dart';
import '../data/threat_feed_service.dart';
import '../data/audit_export_service.dart';
import '../data/notification_config_service.dart';

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
  final NotificationConfigService _notificationService =
      NotificationConfigService();
  NotificationChannelStatus? _channelStatus;
  bool _loadingChannelStatus = true;
  final Map<String, TextEditingController> _webhookControllers = {
    'slack': TextEditingController(),
    'teams': TextEditingController(),
    'email': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadChannelStatus();
  }

  void _loadChannelStatus() async {
    try {
      final status = await _notificationService.getChannelStatus();
      if (mounted) {
        setState(() {
          _channelStatus = status;
          _loadingChannelStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingChannelStatus = false;
        });
      }
    }
  }

  Future<void> _configureChannel(String channel) async {
    const snackBar = SnackBar(
      content: Text('Configuring channel...'),
      duration: Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    final webhookUrl = _webhookControllers[channel]?.text ?? '';

    if (webhookUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Webhook URL cannot be empty')),
      );
      return;
    }

    final success = await _notificationService.configureChannel(
      channel: channel,
      webhookUrl: webhookUrl,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$channel channel configured successfully'),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadChannelStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to configure channel'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _tuneMlSensitivity(ThreatFeedService feed) async {
    final controller = TextEditingController(text: '0.20');
    final configuredValue = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tune ML Sensitivity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Target false-positive rate (0.05 - 0.50)'),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'False-positive rate',
                  hintText: 'e.g. 0.20',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed == null || parsed < 0.05 || parsed > 0.50) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a value between 0.05 and 0.50.')),
                  );
                  return;
                }
                Navigator.pop(context, parsed);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (configuredValue == null) {
      return;
    }

    final ok = await feed.tuneMlThreshold(targetFalsePositiveRate: configuredValue);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'ML threshold tuned successfully (target FPR: ${configuredValue.toStringAsFixed(2)}).'
              : 'Failed to tune ML threshold. Check backend availability and role permissions.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _webhookControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<Widget> _buildChannelConfigSections() {
    final channels = ['slack', 'teams', 'email'];
    final List<Widget> sections = [];
    final scheme = Theme.of(context).colorScheme;

    for (final channel in channels) {
      final isConfigured =
          _channelStatus?.channels[channel] == 'configured';
      final isEmail = channel == 'email';
      final fieldLabel = isEmail ? 'Recipient Email' : 'Webhook URL';
      final hintText = isEmail
          ? 'security-team@example.com'
          : 'https://hooks.slack.com/services/...';
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            leading: Icon(
              channel == 'slack'
                  ? Icons.chat_bubble_outline
                  : channel == 'teams'
                      ? Icons.group_outlined
                      : Icons.mail_outline,
            ),
            title: Text(
              channel.replaceFirst(channel[0], channel[0].toUpperCase()),
            ),
            subtitle: Text(
              isConfigured ? 'Configured' : 'Not configured',
              style: TextStyle(
                color: isConfigured ? scheme.primary : scheme.tertiary,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _webhookControllers[channel],
                      decoration: InputDecoration(
                        labelText: fieldLabel,
                        hintText: hintText,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _configureChannel(channel),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Configuration'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return sections;
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
    final feed = ThreatFeedService();

    return AnimatedBuilder(
      animation: feed,
      builder: (context, _) {
        final selectedRole = feed.currentUserRole;

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
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('Frontend operating role'),
                      subtitle: const Text(
                        'Administrator enables advanced operations. Analyst is read-focused.',
                      ),
                      trailing: SegmentedButton<UserRole>(
                        segments: const [
                          ButtonSegment<UserRole>(
                            value: UserRole.analyst,
                            label: Text('Analyst'),
                          ),
                          ButtonSegment<UserRole>(
                            value: UserRole.administrator,
                            label: Text('Admin'),
                          ),
                        ],
                        selected: {selectedRole},
                        onSelectionChanged: (selection) {
                          final role = selection.first;
                          feed.setUserRole(role);
                        },
                      ),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: const Text('Audit log maintenance'),
                      subtitle: Text('Current entries: ${feed.allAuditEvents.length}'),
                      trailing: OutlinedButton(
                        onPressed: feed.allAuditEvents.isEmpty
                            ? null
                            : () {
                                feed.clearAuditLog();
                              },
                        child: const Text('Clear'),
                      ),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Audit export'),
                      subtitle: const Text('Export audit timeline as CSV or JSON'),
                      trailing: SizedBox(
                        width: 120,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          children: [
                            Tooltip(
                              message: 'Export as CSV',
                              child: IconButton(
                                icon: const Icon(Icons.table_chart_outlined, size: 20),
                                onPressed: feed.allAuditEvents.isEmpty
                                    ? null
                                    : () async {
                                        final path = await AuditExportService
                                            .saveCsvToFile(feed.allAuditEvents);
                                        if (context.mounted) {
                                          if (path != null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Exported to\n$path'),
                                                duration: const Duration(seconds: 3),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Export unavailable on this platform'),
                                                duration: Duration(seconds: 3),
                                              ),
                                            );
                                          }
                                        }
                                      },
                              ),
                            ),
                            Tooltip(
                              message: 'Export as JSON',
                              child: IconButton(
                                icon: const Icon(Icons.data_object_outlined, size: 20),
                                onPressed: feed.allAuditEvents.isEmpty
                                    ? null
                                    : () async {
                                        final path = await AuditExportService
                                            .saveJsonToFile(feed.allAuditEvents);
                                        if (context.mounted) {
                                          if (path != null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Exported to\n$path'),
                                                duration: const Duration(seconds: 3),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Export unavailable on this platform'),
                                                duration: Duration(seconds: 3),
                                              ),
                                            );
                                          }
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Notification channels'),
                      subtitle: const Text('Configure webhooks for Slack, Teams, or Email'),
                      trailing: _loadingChannelStatus
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    // Notification channel config sections
                    if (_channelStatus != null)
                      ..._buildChannelConfigSections(),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.security_outlined),
                      title: const Text('Security profile'),
                      subtitle: const Text('Tune ML threat sensitivity and decision threshold.'),
                      trailing: FilledButton.tonalIcon(
                        onPressed: () => _tuneMlSensitivity(feed),
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('Tune ML'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}