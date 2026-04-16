import 'package:http/http.dart' as http;
import 'dart:convert';

import 'backend_api_client.dart';

class NotificationChannelConfig {
  final String channel; // slack, teams, email
  final String webhookUrl;

  NotificationChannelConfig({
    required this.channel,
    required this.webhookUrl,
  });
}

class NotificationChannelStatus {
  final Map<String, String> channels; // {"slack": "configured", ...}

  NotificationChannelStatus({required this.channels});

  factory NotificationChannelStatus.fromJson(Map<String, dynamic> json) {
    return NotificationChannelStatus(
      channels: Map<String, String>.from(json['channels'] ?? {}),
    );
  }
}

class NotificationConfigService {
  static final NotificationConfigService _instance =
      NotificationConfigService._();

  factory NotificationConfigService() => _instance;

  NotificationConfigService._();

  final String _baseUrl = BackendApiClient.defaultBaseUrl();

  Future<NotificationChannelStatus> getChannelStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/v1/notifications/channels'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return NotificationChannelStatus.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      // Silent failure - likely backend is down
    }

    // Return default: all unconfigured
    return NotificationChannelStatus(
      channels: {
        'slack': 'not_configured',
        'teams': 'not_configured',
        'email': 'not_configured',
      },
    );
  }

  Future<bool> configureChannel({
    required String channel,
    required String webhookUrl,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/notifications/channels/configure'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'channel': channel,
              'webhook_url': webhookUrl,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['status'] == 'configured';
      }
    } catch (e) {
      // Silent failure
    }

    return false;
  }

  Future<bool> sendTestNotification({
    required String title,
    required String message,
    String severity = 'medium',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/notifications/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': title,
              'message': message,
              'severity': severity,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['accepted'] == true;
      }
    } catch (e) {
      // Silent failure
    }

    return false;
  }
}
