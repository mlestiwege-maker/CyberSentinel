import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/kpi_strip.dart';
import '../data/threat_feed_service.dart';
import '../dialogs/operation_confirmation_dialog.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  bool _drillRunning = false;
  bool _notifyRunning = false;
  bool _syncRunning = false;
  bool _captureRunning = false;
  String _captureStatus = "";

  String _timeLabel(DateTime dateTime) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    final ss = dateTime.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<void> _togglePacketCapture(ThreatFeedService feed) async {
    if (_captureRunning) {
      // Stop capture
      setState(() => _captureRunning = true);
      final result = await feed.stopPacketCapture();
      if (!mounted) return;
      setState(() {
        _captureRunning = false;
        _captureStatus = result ? "Capture stopped" : "Failed to stop capture";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_captureStatus),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // Start capture
      setState(() => _captureRunning = true);
      final result = await feed.startPacketCapture();
      if (!mounted) return;
      setState(() {
        _captureRunning = false;
        _captureStatus = result ? "Capture started - monitoring real network traffic" : "Failed to start capture";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_captureStatus),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _runDrill(ThreatFeedService feed) async {
    if (_drillRunning) {
      return;
    }
    final confirmed = await showThreatDrillConfirmation(context);
    if (!confirmed) {
      return;
    }
    setState(() => _drillRunning = true);
    final ok = await feed.runThreatDrill();
    if (!mounted) {
      return;
    }
    setState(() => _drillRunning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Threat drill injected successfully. Monitor alerts for escalation.'
            : 'Threat drill failed. Check backend connectivity/circuit state.'),
      ),
    );
  }

  Future<void> _sendNotification(ThreatFeedService feed) async {
    if (_notifyRunning) {
      return;
    }
    final confirmed = await showNotificationTestConfirmation(context);
    if (!confirmed) {
      return;
    }
    setState(() => _notifyRunning = true);
    final ok = await feed.sendTestNotification(
      message: 'CyberSentinel administrator notification channel test',
    );
    if (!mounted) {
      return;
    }
    setState(() => _notifyRunning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Notification test dispatched to configured channels.'
            : 'Notification test failed. Verify backend health and settings.'),
      ),
    );
  }

  Future<void> _forceSync(ThreatFeedService feed) async {
    if (_syncRunning) {
      return;
    }
    setState(() => _syncRunning = true);
    await feed.requestImmediateSync();
    if (!mounted) {
      return;
    }
    setState(() => _syncRunning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Immediate sync completed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ThreatFeedService();

    return AnimatedBuilder(
      animation: feed,
      builder: (context, _) {
        final summary = feed.summary;
        final metrics = feed.recentMetrics;
        final auditEvents = feed.latestAuditEvents;
        final scheme = Theme.of(context).colorScheme;

        return AppScaffold(
          currentRoute: '/monitoring',
          title: 'Network Monitoring',
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              KpiStrip(
                items: [
                  KpiItem(
                    label: 'Monitored Hosts',
                    value: '${summary.monitoredHosts}',
                    icon: Icons.devices,
                  ),
                  KpiItem(
                    label: 'Packets / sec',
                    value: '${summary.packetRate}',
                    icon: Icons.timeline,
                  ),
                  KpiItem(
                    label: 'Anomalies',
                    value: '${summary.anomalies}',
                    icon: Icons.insights,
                    color: scheme.tertiary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Packet Inspection Feed',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Real-time anomaly scoring from simulated banking network traffic.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrator Operations Console',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: Icon(
                              feed.isBackendConnected ? Icons.cloud_done : Icons.cloud_off,
                              size: 18,
                              color: feed.isBackendConnected ? scheme.primary : scheme.tertiary,
                            ),
                            label: Text(feed.connectionLabel),
                          ),
                          Chip(
                            avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                            label: Text('Failures: ${feed.backendConsecutiveFailures}'),
                          ),
                          Chip(
                            avatar: Icon(
                              feed.backendCircuitOpen ? Icons.pause_circle : Icons.play_circle,
                              size: 18,
                            ),
                            label: Text(
                              feed.backendCircuitOpen
                                  ? 'Circuit Open (${feed.backendCircuitOpenRemaining?.inSeconds ?? 0}s)'
                                  : 'Circuit Closed',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _drillRunning || !feed.isAdministrator
                                ? null
                                : () => _runDrill(feed),
                            icon: _drillRunning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.science_outlined),
                            label: const Text('Run Threat Drill'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _notifyRunning || !feed.isAdministrator
                              ? null
                              : () => _sendNotification(feed),
                            icon: _notifyRunning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.notifications_active_outlined),
                            label: const Text('Test Notification Channels'),
                          ),
                          FilledButton.icon(
                            onPressed: _captureRunning || !feed.isAdministrator
                                ? null
                                : () => _togglePacketCapture(feed),
                            icon: _captureRunning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(_captureStatus.contains("started") 
                                    ? Icons.stop_circle_outlined
                                    : Icons.fiber_smart_record),
                            label: Text(_captureStatus.contains("started") 
                                ? 'Stop Capture'
                                : 'Capture Real Traffic'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _syncRunning ? null : () => _forceSync(feed),
                            icon: _syncRunning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync),
                            label: const Text('Force Sync'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        feed.isAdministrator
                            ? 'Role: ${feed.currentRoleLabel} (full operational privileges)'
                            : 'Role: ${feed.currentRoleLabel} (read-focused mode, admin controls disabled)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('Packets/sec')),
                      DataColumn(label: Text('Anomaly Score')),
                      DataColumn(label: Text('Suspicious Flows')),
                    ],
                    rows: metrics
                        .take(10)
                        .map(
                          (metric) => DataRow(
                            cells: [
                              DataCell(Text(_timeLabel(metric.time))),
                              DataCell(Text('${metric.packetsPerSecond}')),
                              DataCell(Text(metric.anomalyScore.toStringAsFixed(2))),
                              DataCell(Text('${metric.suspiciousConnections}')),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Operations Audit Timeline',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          Text(
                            '${auditEvents.length} events',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (auditEvents.isEmpty)
                        const Text('No audit events yet.')
                      else
                        ...auditEvents.take(8).map(
                              (event) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: event.outcome == 'Success'
                                            ? scheme.primary
                                            : event.outcome == 'Failed'
                                                ? scheme.error
                                                : scheme.tertiary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${event.action} • ${event.outcome}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(fontWeight: FontWeight.w700),
                                          ),
                                          Text(
                                            event.details,
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _timeLabel(event.time),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
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