import 'package:flutter/material.dart';

/// Confirmation dialog for high-impact admin operations
class OperationConfirmationDialog extends StatelessWidget {
  const OperationConfirmationDialog({
    required this.operation,
    required this.title,
    required this.description,
    required this.details,
    required this.onConfirm,
    super.key,
  });

  final String operation;
  final String title;
  final String description;
  final List<String> details;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warningColor = scheme.error;
    final warningContainer = scheme.errorContainer.withValues(alpha: 0.45);
    final infoColor = scheme.primary;
    final infoContainer = scheme.primaryContainer.withValues(alpha: 0.35);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: warningColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: warningContainer,
                border: Border.all(color: warningColor.withValues(alpha: 0.28)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operation Details',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                    for (final detail in details) 
                      Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 4, color: warningColor),
                          const SizedBox(width: 8),
                          Expanded(child: Text(detail, style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                      ),
                  ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: infoContainer,
                border: Border.all(color: infoColor.withValues(alpha: 0.24)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: infoColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action is logged in the audit trail for compliance.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () {
            Navigator.of(context).pop(true);
            onConfirm();
          },
          child: Text('Proceed with $operation'),
        ),
      ],
    );
  }
}

/// Show threat drill confirmation dialog
Future<bool> showThreatDrillConfirmation(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => OperationConfirmationDialog(
      operation: 'Threat Drill',
      title: 'Confirm Threat Drill',
      description:
          'Executing a threat drill will inject a simulated malicious traffic event into the system. This tests detection capabilities and triggers alert notifications.',
      details: [
        'Simulated DDoS attack from 10.240.18.42 to 172.16.4.10',
        'Protocol: TCP, Port: 445 (SMB)',
        'High anomaly score (0.92) will be generated',
        'Alert notifications will be sent to configured channels',
        'Action will be recorded in audit log',
      ],
      onConfirm: () {},
    ),
  );

  return result ?? false;
}

/// Show notification test confirmation dialog
Future<bool> showNotificationTestConfirmation(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => OperationConfirmationDialog(
      operation: 'Notification Test',
      title: 'Confirm Notification Channel Test',
      description:
          'Sending a test notification will immediately dispatch a test alert to all configured notification channels (Slack, Teams, Email). This validates channel connectivity.',
      details: [
        'Test message: "CyberSentinel Test Alert"',
        'Severity: Medium',
        'Will send to all configured channels',
        'Channels: Slack, Teams, Email (if configured)',
        'Test timestamp will be included in message',
      ],
      onConfirm: () {},
    ),
  );

  return result ?? false;
}
