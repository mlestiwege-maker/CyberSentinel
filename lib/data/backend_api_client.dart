import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendCircuitOpenException implements Exception {
  BackendCircuitOpenException(this.message);

  final String message;

  @override
  String toString() => 'BackendCircuitOpenException: $message';
}

class BackendApiClient {
  BackendApiClient({required String baseUrl}) : _baseUri = Uri.parse(baseUrl);

  final Uri _baseUri;
  final Random _random = Random();
  final Duration _requestTimeout = const Duration(seconds: 6);
  final int _maxRetries = 2;

  int _consecutiveFailures = 0;
  DateTime? _circuitOpenUntil;

  static String defaultBaseUrl() {
    const override = String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  Uri websocketUri() {
    final wsScheme = _baseUri.scheme == 'https' ? 'wss' : 'ws';
    return _baseUri.replace(
      scheme: wsScheme,
      path: '/api/v1/stream',
      queryParameters: null,
    );
  }

  int get consecutiveFailures => _consecutiveFailures;

  bool get isCircuitOpen {
    final until = _circuitOpenUntil;
    if (until == null) {
      return false;
    }
    return DateTime.now().isBefore(until);
  }

  Duration? get circuitOpenRemaining {
    final until = _circuitOpenUntil;
    if (until == null) {
      return null;
    }
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  Future<Map<String, dynamic>> fetchSummary() async {
    final uri = _baseUri.replace(path: '/api/v1/summary');
    final response = await _sendWithResilience(() => http.get(uri));
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchAlerts({int limit = 20}) async {
    final uri = _baseUri.replace(
      path: '/api/v1/alerts',
      queryParameters: {'limit': '$limit'},
    );
    final response = await _sendWithResilience(() => http.get(uri));
    _ensureSuccess(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<List<dynamic>> fetchRecentMetrics({int limit = 12}) async {
    final uri = _baseUri.replace(
      path: '/api/v1/metrics/recent',
      queryParameters: {'limit': '$limit'},
    );
    final response = await _sendWithResilience(() => http.get(uri));
    _ensureSuccess(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> sendNotificationTest({required String message}) async {
    final uri = _baseUri.replace(path: '/api/v1/notifications/test');
    final response = await _sendWithResilience(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'channel': 'both', 'message': message}),
      ),
    );
    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> triggerThreatDrill() async {
    final uri = _baseUri.replace(path: '/api/v1/ingest');
    final response = await _sendWithResilience(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
          {
            'source_ip': '10.240.18.42',
            'destination_ip': '172.16.4.10',
            'protocol': 'TCP',
            'destination_port': 445,
            'bytes_in': 285000,
            'bytes_out': 230000,
            'failed_logins': 7,
            'geo_anomaly': true,
            'user_agent_risk': 0.92,
          },
        ),
      ),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startPacketCapture() async {
    final uri = _baseUri.replace(path: '/api/v1/capture/start');
    final response = await _sendWithResilience(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'interface': null}),
      ),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> stopPacketCapture() async {
    final uri = _baseUri.replace(path: '/api/v1/capture/stop');
    final response = await _sendWithResilience(
      () => http.post(uri, headers: {'Content-Type': 'application/json'}),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchMlModelInfo() async {
    final uri = _baseUri.replace(path: '/api/v1/ml/model/info');
    final response = await _sendWithResilience(() => http.get(uri));
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> trainMlModel({int trainingEvents = 100}) async {
    final uri = _baseUri.replace(path: '/api/v1/ml/model/train');
    final response = await _sendWithResilience(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'training_events': trainingEvents}),
      ),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchMlSchedulerStatus() async {
    final uri = _baseUri.replace(path: '/api/v1/ml/scheduler/status');
    final response = await _sendWithResilience(() => http.get(uri));
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> configureMlScheduler({
    required bool enabled,
    required int intervalSeconds,
    required int trainingEvents,
  }) async {
    final uri = _baseUri.replace(path: '/api/v1/ml/scheduler/configure');
    final response = await _sendWithResilience(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
          {
            'enabled': enabled,
            'interval_seconds': intervalSeconds,
            'training_events': trainingEvents,
          },
        ),
      ),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchMlFeatureImportance() async {
    final uri = _baseUri.replace(path: '/api/v1/ml/feature-importance');
    final response = await _sendWithResilience(() => http.get(uri));
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> tuneMlThreshold({
    required double targetFalsePositiveRate,
  }) async {
    final uri = _baseUri.replace(path: '/api/v1/ml/threshold/tune');
    final response = await _sendWithResilience(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
          {'target_false_positive_rate': targetFalsePositiveRate},
        ),
      ),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchMlModelVersions() async {
    final uri = _baseUri.replace(path: '/api/v1/ml/model/versions');
    final response = await _sendWithResilience(() => http.get(uri));
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> switchMlModelVersion({
    required String versionId,
  }) async {
    final uri = _baseUri.replace(path: '/api/v1/ml/model/switch');
    final response = await _sendWithResilience(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'version_id': versionId}),
      ),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchResilienceStats() async {
    try {
      final uri = _baseUri.replace(path: '/api/v1/health/resilience');
      final response = await http
          .get(uri)
          .timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      // Silent failure
      return {};
    }
  }

  Future<http.Response> _sendWithResilience(
    Future<http.Response> Function() operation,
  ) async {
    if (isCircuitOpen) {
      throw BackendCircuitOpenException(
        'Circuit breaker open. Retry in ${circuitOpenRemaining?.inSeconds ?? 0}s.',
      );
    }

    Object? lastError;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await operation().timeout(_requestTimeout);

        if (!_shouldRetryStatus(response.statusCode)) {
          _onSuccess();
          return response;
        }

        lastError = Exception('Transient backend status: ${response.statusCode}');
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      }

      if (attempt < _maxRetries) {
        await Future.delayed(_retryDelay(attempt));
      }
    }

    _onFailure();
    throw lastError ?? Exception('Backend request failed after retries.');
  }

  Duration _retryDelay(int attempt) {
    final baseMs = 220 * (1 << attempt);
    final jitterMs = _random.nextInt(140);
    return Duration(milliseconds: baseMs + jitterMs);
  }

  bool _shouldRetryStatus(int statusCode) {
    return statusCode == 429 || statusCode >= 500;
  }

  void _onSuccess() {
    _consecutiveFailures = 0;
    _circuitOpenUntil = null;
  }

  void _onFailure() {
    _consecutiveFailures += 1;
    if (_consecutiveFailures >= 4) {
      _circuitOpenUntil = DateTime.now().add(const Duration(seconds: 20));
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw Exception('Backend request failed (${response.statusCode}): ${response.body}');
  }
}
