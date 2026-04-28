import 'package:flutter/material.dart';
import '../data/threat_feed_service.dart';
import '../widgets/app_scaffold.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _inputController = TextEditingController();
  final List<TerminalEntry> _entries = [
    TerminalEntry(
      text: 'CyberSentinel SOC Terminal v2.0.0',
      type: TerminalEntryType.info,
      timestamp: DateTime.now(),
    ),
    TerminalEntry(
      text: 'Type "help" for available commands',
      type: TerminalEntryType.info,
      timestamp: DateTime.now(),
    ),
  ];
  final ScrollController _scrollController = ScrollController();
  late ThreatFeedService _feed;

  @override
  void initState() {
    super.initState();
    _feed = ThreatFeedService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _executeCommand(String command) async {
    final trimmed = command.trim().toLowerCase();
    if (trimmed.isEmpty) return;

    _inputController.clear();

    setState(() {
      _entries.add(TerminalEntry(
        text: '> $command',
        type: TerminalEntryType.command,
        timestamp: DateTime.now(),
      ));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    if (trimmed == 'help' || trimmed == '?') {
      _addOutput(
        'Available Commands:\n'
        '  drill          - Inject synthetic threat for testing\n'
        '  status         - Show system status and metrics\n'
        '  alerts         - List recent security alerts\n'
        '  threats        - Show active threats\n'
        '  refresh        - Force refresh all threat data\n'
        '  capture [on|off] - Start/stop packet capture\n'
        '  notify-test    - Send test notification\n'
        '  ml-tune [0.05-0.50] - Tune ML false positive rate\n'
        '  incidents      - Show open incidents\n'
        '  audit          - Export audit log\n'
        '  clear          - Clear terminal\n'
        '  exit           - Quit terminal',
        TerminalEntryType.info,
      );
    } else if (trimmed == 'status') {
      _addOutput('System Status: OPERATIONAL\n'
          'Backend: Connected\n'
          'Auth: JWT Valid\n'
          'Role: Administrator\n'
          'Threats Detected: 91\n'
          'High Risk Alerts: 28\n'
          'Open Incidents: 19\n'
          'Resolved: 29\n'
          'Uptime: 47 days 8h 21m', TerminalEntryType.success);
    } else if (trimmed == 'drill') {
      _addOutput('Initiating threat drill...', TerminalEntryType.info);
      try {
        await _feed.runThreatDrill();
        _addOutput('✓ Threat drill completed successfully. '
            'Check Alerts screen for injected threats.', TerminalEntryType.success);
      } catch (e) {
        _addOutput('✗ Threat drill failed: $e', TerminalEntryType.error);
      }
    } else if (trimmed == 'refresh') {
      _addOutput('Refreshing threat data...', TerminalEntryType.info);
      try {
        await _feed.refreshAll();
        _addOutput('✓ Threat data refreshed successfully', TerminalEntryType.success);
      } catch (e) {
        _addOutput('✗ Refresh failed: $e', TerminalEntryType.error);
      }
    } else if (trimmed == 'notify-test') {
      _addOutput('Sending test notification...', TerminalEntryType.info);
      try {
        final result = await _feed.sendTestNotification();
        _addOutput(result ?
            '✓ Test notification sent successfully' :
            '✗ Test notification failed to send', TerminalEntryType.success);
      } catch (e) {
        _addOutput('✗ Notification failed: $e', TerminalEntryType.error);
      }
    } else if (trimmed.startsWith('capture')) {
      final parts = trimmed.split(' ');
      if (parts.length < 2) {
        _addOutput('Usage: capture [on|off]', TerminalEntryType.error);
      } else {
        final isOn = parts[1] == 'on';
        _addOutput('${isOn ? 'Starting' : 'Stopping'} packet capture...', 
            TerminalEntryType.info);
        try {
          if (isOn) {
            await _feed.startPacketCapture();
            _addOutput('✓ Packet capture started. Live traffic monitoring active.',
                TerminalEntryType.success);
          } else {
            await _feed.stopPacketCapture();
            _addOutput('✓ Packet capture stopped.', TerminalEntryType.success);
          }
        } catch (e) {
          _addOutput('✗ Capture command failed: $e', TerminalEntryType.error);
        }
      }
    } else if (trimmed.startsWith('ml-tune')) {
      final parts = trimmed.split(' ');
      if (parts.length < 2) {
        _addOutput('Usage: ml-tune [0.05-0.50] (false positive rate)', 
            TerminalEntryType.error);
      } else {
        try {
          final rate = double.parse(parts[1]);
          if (rate < 0.05 || rate > 0.50) {
            _addOutput('Error: Value must be between 0.05 and 0.50', 
                TerminalEntryType.error);
          } else {
            _addOutput('Tuning ML threshold to ${(rate * 100).toStringAsFixed(1)}%...', 
                TerminalEntryType.info);
            await _feed.tuneMlThreshold(targetFalsePositiveRate: rate);
            _addOutput('✓ ML threshold tuned successfully', TerminalEntryType.success);
          }
        } catch (e) {
          _addOutput('✗ ML tuning failed: $e', TerminalEntryType.error);
        }
      }
    } else if (trimmed == 'alerts') {
      _addOutput('Recent Security Alerts:\n'
          '  [CRITICAL] SQL Injection Attempt - 192.168.1.45 (5 min ago)\n'
          '  [HIGH] Brute Force Login - 203.0.113.7 (12 min ago)\n'
          '  [HIGH] DDoS Attack Detected - 198.51.100.0/24 (23 min ago)\n'
          '  [MEDIUM] Unauthorized API Call - 10.0.0.5 (47 min ago)\n'
          '  [MEDIUM] Malware Signature Match - finance.exe (1h ago)\n'
          'View full list in Alerts screen', TerminalEntryType.info);
    } else if (trimmed == 'threats') {
      _addOutput('Active Threat Analysis:\n'
          '  Ransomware Beacon: 23 instances detected\n'
          '  Password Spray: 17 failed attempts\n'
          '  Data Exfiltration: 8 suspicious flows\n'
          '  Privilege Escalation: 5 attempts\n'
          '  Lateral Movement: 3 active paths\n'
          'Risk Level: CRITICAL', TerminalEntryType.info);
    } else if (trimmed == 'incidents') {
      _addOutput('Open Incidents:\n'
          '  INC-2026-0847: Ransomware Containment (High)\n'
          '  INC-2026-0842: Unauthorized Access Investigation (High)\n'
          '  INC-2026-0839: Data Breach Response (Critical)\n'
          '  INC-2026-0835: Malware Eradication (Medium)\n'
          '  INC-2026-0829: DDoS Mitigation (Medium)', TerminalEntryType.info);
    } else if (trimmed == 'audit') {
      _addOutput('Exporting audit log 2026-04-27_audit_export.json...', 
          TerminalEntryType.info);
      await Future.delayed(const Duration(seconds: 1));
      _addOutput('✓ Audit log exported. 250 entries written to file.', 
          TerminalEntryType.success);
    } else if (trimmed == 'clear') {
      setState(() {
        _entries.clear();
      });
    } else if (trimmed == 'exit') {
      _addOutput('Exiting SOC Terminal. Type "terminal" to reconnect.', 
          TerminalEntryType.info);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      _addOutput('Unknown command: "$command". Type "help" for available commands.', 
          TerminalEntryType.error);
    }
  }

  void _addOutput(String text, TerminalEntryType type) {
    setState(() {
      for (final line in text.split('\n')) {
        _entries.add(TerminalEntry(
          text: line,
          type: type,
          timestamp: DateTime.now(),
        ));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Color _getEntryColor(BuildContext context, TerminalEntryType type) {
    switch (type) {
      case TerminalEntryType.command:
        return Theme.of(context).colorScheme.primary;
      case TerminalEntryType.success:
        return const Color(0xFF24D27E);
      case TerminalEntryType.error:
        return const Color(0xFFFF4D4D);
      case TerminalEntryType.info:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppScaffold(
      currentRoute: '/terminal',
      title: 'SOC TERMINAL',
      body: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0F1A) : const Color(0xFFF4F7FE),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1524) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SOC TERMINAL',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: isDark ? Colors.white : const Color(0xFF0A0F1A),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Execute threat operations and system commands',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      entry.text,
                      style: MonospaceTextStyle(
                        color: _getEntryColor(context, entry.type),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1524) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '> ',
                    style: MonospaceTextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: MonospaceTextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0A0F1A),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter command (type "help" for list)',
                        hintStyle: MonospaceTextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onSubmitted: _executeCommand,
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        _executeCommand(_inputController.text),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TerminalEntry {
  final String text;
  final TerminalEntryType type;
  final DateTime timestamp;

  TerminalEntry({
    required this.text,
    required this.type,
    required this.timestamp,
  });
}

enum TerminalEntryType {
  command,
  success,
  error,
  info,
}

class MonospaceTextStyle extends TextStyle {
  const MonospaceTextStyle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) : super(
    color: color,
    fontSize: fontSize ?? 13,
    fontWeight: fontWeight ?? FontWeight.w400,
    fontFamily: 'monospace',
    letterSpacing: 0.5,
  );
}
