import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cybersentinel_frontend/data/backend_api_client.dart';
import 'package:cybersentinel_frontend/data/threat_feed_service.dart';

class ThreatDrillPanel extends StatefulWidget {
  final ThreatFeedService feed;
  final bool isWide;

  ThreatDrillPanel({
    super.key,
    required this.feed,
    this.isWide = true,
  });

  @override
  State<ThreatDrillPanel> createState() => _ThreatDrillPanelState();
}

class _ThreatDrillPanelState extends State<ThreatDrillPanel> {
  bool _isLoading = false;
  String _currentSim = '';

  final scenarios = [
    {
      'name': 'Port Scan',
      'key': 'port_scan',
      'icon': Icons.search,
      'color': Colors.orange,
    },
    {
      'name': 'Brute Force',
      'key': 'brute_force',
      'icon': Icons.lock,
      'color': Colors.red,
    },
    {
      'name': 'Suspicious',
      'key': 'suspicious',
      'icon': Icons.warning,
      'color': Colors.amber,
    },
    {
      'name': 'DDoS',
      'key': 'ddos',
      'icon': Icons.network_check,
      'color': Colors.deepPurple,
    },
    {
      'name': 'Ransomware',
      'key': 'ransomware',
      'icon': Icons.shield,
      'color': Colors.red[900]!,
    },
    {
      'name': 'Malware',
      'key': 'malware_beaconing',
      'icon': Icons.bug_report,
      'color': Colors.indigo,
    },
    {
      'name': 'Demo',
      'key': 'demo',
      'icon': Icons.play_circle,
      'color': Colors.teal,
    },
  ];

  Future<void> _runSim(String key) async {
    if (_isLoading) return;
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _currentSim = key;
    });
    
    try {
      String url;
      if (key == 'demo') {
        url = '${BackendApiClient.defaultBaseUrl()}/api/v1/simulate';
      } else {
        url = '${BackendApiClient.defaultBaseUrl()}/api/v1/simulate/$key?intensity=high&duration=15';
      }
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          String msg;
          if (key == 'demo') {
            msg = data['message'] ?? 'Demo started';
          } else {
            final s = data['simulation'];
            msg = '${s['attack_type']} started';
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: key == 'demo' ? Colors.teal : Colors.deepPurple,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentSim = '';
        });
        (widget.feed as dynamic).refreshAll();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Run Threat Drill',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Simulate attacks to test detection',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: scenarios.map((s) {
                final isSel = _currentSim == s['key'];
                final color = s['color'] as Color;
                return FilterChip(
                  avatar: Icon(s['icon'] as IconData, size: 16, color: isSel ? Colors.white : color),
                  label: Text(
                    s['name'] as String,
                    style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                  ),
                  selected: isSel,
                  selectedColor: color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  onSelected: _isLoading
                      ? null
                      : (v) {
                          if (!mounted) return;
                          _runSim(s['key'] as String);
                        },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
