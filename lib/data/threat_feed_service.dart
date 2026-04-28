import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'backend_api_client.dart';

enum UserRole { analyst, administrator }

class AuditEvent {
  const AuditEvent({
    required this.time,
    required this.action,
    required this.outcome,
    required this.details,
  });

  final DateTime time;
  final String action;
  final String outcome;
  final String details;
}

class ThreatAlert {
  const ThreatAlert({
    required this.id,
    required this.time,
    required this.attackType,
    required this.sourceIp,
    required this.severity,
    required this.status,
    required this.description,
    required this.confidence,
  });

  final String id;
  final DateTime time;
  final String attackType;
  final String sourceIp;
  final String severity;
  final String status;
  final String description;
  final double confidence;

  factory ThreatAlert.fromJson(Map<String, dynamic> json) {
    return ThreatAlert(
      id: (json['id'] ?? '').toString(),
      time: DateTime.tryParse((json['time'] ?? '').toString()) ?? DateTime.now(),
      attackType: (json['attack_type'] ?? json['attackType'] ?? 'Unknown').toString(),
      sourceIp: (json['source_ip'] ?? json['sourceIp'] ?? 'N/A').toString(),
      severity: (json['severity'] ?? 'Low').toString(),
      status: (json['status'] ?? 'Monitoring').toString(),
      description: (json['description'] ?? '').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NetworkMetric {
  const NetworkMetric({
    required this.time,
    required this.packetsPerSecond,
    required this.anomalyScore,
    required this.suspiciousConnections,
  });

  final DateTime time;
  final int packetsPerSecond;
  final double anomalyScore;
  final int suspiciousConnections;

  factory NetworkMetric.fromJson(Map<String, dynamic> json) {
    return NetworkMetric(
      time: DateTime.tryParse((json['time'] ?? '').toString()) ?? DateTime.now(),
      packetsPerSecond:
          (json['packets_per_second'] as num?)?.toInt() ??
          (json['packetsPerSecond'] as num?)?.toInt() ??
          0,
      anomalyScore:
          (json['anomaly_score'] as num?)?.toDouble() ??
          (json['anomalyScore'] as num?)?.toDouble() ??
          0.0,
      suspiciousConnections:
          (json['suspicious_connections'] as num?)?.toInt() ??
          (json['suspiciousConnections'] as num?)?.toInt() ??
          0,
    );
  }
}

class ThreatSummary {
  const ThreatSummary({
    required this.activeThreats,
    required this.newAlerts,
    required this.resolvedToday,
    required this.criticalOpen,
    required this.highSeverity,
    required this.investigations,
    required this.autoResolved,
    required this.anomalies,
    required this.packetRate,
    required this.monitoredHosts,
  });

  final int activeThreats;
  final int newAlerts;
  final int resolvedToday;
  final int criticalOpen;
  final int highSeverity;
  final int investigations;
  final int autoResolved;
  final int anomalies;
  final int packetRate;
  final int monitoredHosts;

  factory ThreatSummary.fromJson(Map<String, dynamic> json) {
    return ThreatSummary(
      activeThreats:
          (json['active_threats'] as num?)?.toInt() ??
          (json['activeThreats'] as num?)?.toInt() ??
          0,
      newAlerts:
          (json['new_alerts'] as num?)?.toInt() ?? (json['newAlerts'] as num?)?.toInt() ?? 0,
      resolvedToday:
          (json['resolved_today'] as num?)?.toInt() ??
          (json['resolvedToday'] as num?)?.toInt() ??
          0,
      criticalOpen:
          (json['critical_open'] as num?)?.toInt() ??
          (json['criticalOpen'] as num?)?.toInt() ??
          0,
      highSeverity:
          (json['high_severity'] as num?)?.toInt() ??
          (json['highSeverity'] as num?)?.toInt() ??
          0,
      investigations: (json['investigations'] as num?)?.toInt() ?? 0,
      autoResolved:
          (json['auto_resolved'] as num?)?.toInt() ??
          (json['autoResolved'] as num?)?.toInt() ??
          0,
      anomalies: (json['anomalies'] as num?)?.toInt() ?? 0,
      packetRate:
          (json['packet_rate'] as num?)?.toInt() ?? (json['packetRate'] as num?)?.toInt() ?? 0,
      monitoredHosts:
          (json['monitored_hosts'] as num?)?.toInt() ??
          (json['monitoredHosts'] as num?)?.toInt() ??
          0,
    );
  }
}

class ThreatFeedService extends ChangeNotifier {
  ThreatFeedService._()
      : _apiClient = BackendApiClient(baseUrl: BackendApiClient.defaultBaseUrl());

  static final ThreatFeedService _instance = ThreatFeedService._();

  factory ThreatFeedService() => _instance;

  final Random _random = Random();
  final BackendApiClient _apiClient;
  final List<ThreatAlert> _alerts = [];
  final List<NetworkMetric> _metrics = [];
  final List<int> _dailyThreatTrend = [3, 4, 3, 6, 5, 4, 7];
  final List<AuditEvent> _auditEvents = [];

  Timer? _timer;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  bool _started = false;
  bool _refreshInFlight = false;
  bool _backendHealthy = false;
  int _pollTick = 0;
  DateTime? _lastSyncAt;
  ThreatSummary? _cachedSummary;
  Map<String, dynamic>? _mlModelInfo;
  Map<String, dynamic>? _mlSchedulerStatus;
  Map<String, dynamic>? _mlFeatureImportance;
  Map<String, dynamic>? _mlVersions;
  DateTime? _mlLastUpdatedAt;
  int _sequence = 0;
  UserRole _currentUserRole = UserRole.administrator;

  static const List<String> _attackTypes = [
    'DDoS',
    'Ransomware',
    'Phishing',
    'Port Scan',
    'SQL Injection',
    'Brute Force',
    'Malware Beaconing',
  ];

  static const List<String> _severityLevels = ['Critical', 'High', 'Medium', 'Low'];

  static const List<String> _statuses = [
    'Investigating',
    'Blocked',
    'Monitoring',
    'Contained',
    'Resolved',
  ];

  void initialize() {
    if (_started) {
      return;
    }
    _started = true;

    _logAudit(
      action: 'Session Start',
      outcome: 'Success',
      details: 'Threat feed service initialized.',
    );

    _seedInitialData();
    if (!_isFlutterTestEnvironment()) {
      unawaited(_refreshFromBackend(notify: true));
      unawaited(refreshMlInsights());
      _connectWebSocket();

      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        _pollTick += 1;

        if (_backendHealthy) {
          if (_pollTick % 5 == 0) {
            unawaited(_refreshFromBackend(notify: true));
          }
          if (_wsSubscription == null) {
            _connectWebSocket();
          }
          return;
        }

        _generateMetric();
        if (_random.nextDouble() > 0.35) {
          _generateAlert();
        }
        _updateTrend();
        _cachedSummary = _computeSummary();
        notifyListeners();

        unawaited(_refreshFromBackend(notify: false));
        if (_wsSubscription == null) {
          _connectWebSocket();
        }
      });
    }
  }

  void shutdown() {
    _timer?.cancel();
    _timer = null;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
    _backendHealthy = false;
    _started = false;
  }

  @visibleForTesting
  void reset() {
    shutdown();
    _alerts.clear();
    _metrics.clear();
    _dailyThreatTrend
      ..clear()
      ..addAll([3, 4, 3, 6, 5, 4, 7]);
    _backendHealthy = false;
    _refreshInFlight = false;
    _pollTick = 0;
    _lastSyncAt = null;
    _cachedSummary = null;
    _sequence = 0;
    _auditEvents.clear();
    _seedInitialData();
  }

  @override
  void dispose() {
    shutdown();
    super.dispose();
  }

  List<ThreatAlert> get latestAlerts {
    final sorted = [..._alerts]..sort((a, b) => b.time.compareTo(a.time));
    return List.unmodifiable(sorted);
  }

  List<NetworkMetric> get recentMetrics {
    final sorted = [..._metrics]..sort((a, b) => b.time.compareTo(a.time));
    return List.unmodifiable(sorted.take(12).toList());
  }

  List<int> get dailyThreatTrend => List.unmodifiable(_dailyThreatTrend);

  ThreatSummary get summary {
    final cached = _cachedSummary;
    if (cached != null) {
      return cached;
    }

    return _computeSummary();
  }

  Map<String, dynamic>? get mlModelInfo => _mlModelInfo;

  Map<String, dynamic>? get mlSchedulerStatus => _mlSchedulerStatus;

  Map<String, dynamic>? get mlFeatureImportance => _mlFeatureImportance;

  Map<String, dynamic>? get mlVersions => _mlVersions;

  DateTime? get mlLastUpdatedAt => _mlLastUpdatedAt;

  bool get isBackendConnected => _backendHealthy;

  bool get isRefreshing => _refreshInFlight;

  String get connectionLabel => _backendHealthy ? 'Live Backend' : 'Fallback Simulation';

  DateTime? get lastSyncAt => _lastSyncAt;

  int get backendConsecutiveFailures => _apiClient.consecutiveFailures;

  bool get backendCircuitOpen => _apiClient.isCircuitOpen;

  Duration? get backendCircuitOpenRemaining => _apiClient.circuitOpenRemaining;

  UserRole get currentUserRole => _currentUserRole;

  bool get isAdministrator => _currentUserRole == UserRole.administrator;

  String get currentRoleLabel => isAdministrator ? 'Administrator' : 'Analyst';

  List<AuditEvent> get latestAuditEvents => List.unmodifiable(_auditEvents.reversed.take(25));

  /// Get all audit events (for export)
  List<AuditEvent> get allAuditEvents => List.unmodifiable(_auditEvents);

  Future<void> refreshAll() async {
    await _refreshFromBackend(notify: true);
    await refreshMlInsights();
    notifyListeners();
  }

  Future<bool> runThreatDrill() async {
    if (!isAdministrator) {
      _logAudit(
        action: 'Threat Drill',
        outcome: 'Denied',
        details: 'Only administrators can execute threat drills.',
      );
      notifyListeners();
      return false;
    }

    try {
      await _apiClient.triggerThreatDrill();
      await _refreshFromBackend(notify: true);
      _logAudit(
        action: 'Threat Drill',
        outcome: 'Success',
        details: 'Synthetic high-risk event sent to backend ingest endpoint.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _logAudit(
        action: 'Threat Drill',
        outcome: 'Failed',
        details: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendTestNotification({String message = 'CyberSentinel test alert'}) async {
    if (!isAdministrator) {
      _logAudit(
        action: 'Notification Test',
        outcome: 'Denied',
        details: 'Only administrators can test notification channels.',
      );
      notifyListeners();
      return false;
    }

    try {
      await _apiClient.sendNotificationTest(message: message);
      _logAudit(
        action: 'Notification Test',
        outcome: 'Success',
        details: 'Notification test sent to configured email/push channels.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _logAudit(
        action: 'Notification Test',
        outcome: 'Failed',
        details: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<void> requestImmediateSync() async {
    try {
      await _refreshFromBackend(notify: true);
      _logAudit(
        action: 'Manual Sync',
        outcome: _backendHealthy ? 'Success' : 'Fallback',
        details: _backendHealthy
            ? 'Manual sync completed with backend.'
            : 'Backend unavailable, system remains in fallback mode.',
      );
    } catch (e) {
      _logAudit(
        action: 'Manual Sync',
        outcome: 'Failed',
        details: e.toString(),
      );
    }
    notifyListeners();
  }

  Future<bool> startPacketCapture() async {
    if (!isAdministrator) {
      _logAudit(
        action: 'Packet Capture Start',
        outcome: 'Denied',
        details: 'Only administrators can start packet capture.',
      );
      notifyListeners();
      return false;
    }

    try {
      await _apiClient.startPacketCapture();
      _logAudit(
        action: 'Packet Capture Start',
        outcome: 'Success',
        details: 'Real-time network packet capture initiated. Monitoring live network traffic.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _logAudit(
        action: 'Packet Capture Start',
        outcome: 'Failed',
        details: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> stopPacketCapture() async {
    if (!isAdministrator) {
      _logAudit(
        action: 'Packet Capture Stop',
        outcome: 'Denied',
        details: 'Only administrators can stop packet capture.',
      );
      notifyListeners();
      return false;
    }

    try {
      await _apiClient.stopPacketCapture();
      _logAudit(
        action: 'Packet Capture Stop',
        outcome: 'Success',
        details: 'Real-time packet capture stopped.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _logAudit(
        action: 'Packet Capture Stop',
        outcome: 'Failed',
        details: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> refreshMlInsights() async {
    try {
      final responses = await Future.wait([
        _apiClient.fetchMlModelInfo(),
        _apiClient.fetchMlSchedulerStatus(),
        _apiClient.fetchMlFeatureImportance(),
        _apiClient.fetchMlModelVersions(),
      ]);

      _mlModelInfo = responses[0];
      _mlSchedulerStatus = responses[1];
      _mlFeatureImportance = responses[2];
      _mlVersions = responses[3];
      _mlLastUpdatedAt = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _logAudit(
        action: 'ML Insights Refresh',
        outcome: 'Failed',
        details: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> trainMlModel({int trainingEvents = 100}) async {
    if (!isAdministrator) {
      _logAudit(
        action: 'ML Model Train',
        outcome: 'Denied',
        details: 'Only administrators can train ML model.',
      );
      notifyListeners();
      return false;
    }

    try {
      final response = await _apiClient.trainMlModel(trainingEvents: trainingEvents);
      await refreshMlInsights();
      _logAudit(
        action: 'ML Model Train',
        outcome: (response['success'] == true) ? 'Success' : 'Failed',
        details: (response['message'] ?? 'Training request completed').toString(),
      );
      notifyListeners();
      return response['success'] == true;
    } catch (e) {
      _logAudit(
        action: 'ML Model Train',
        outcome: 'Failed',
        details: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> configureMlScheduler({
    required bool enabled,
    int intervalSeconds = 300,
    int trainingEvents = 100,
  }) async {
    if (!isAdministrator) {
      _logAudit(
        action: 'ML Scheduler Configure',
        outcome: 'Denied',
        details: 'Only administrators can configure retraining scheduler.',
      );
      notifyListeners();
      return false;
    }

    try {
      _mlSchedulerStatus = await _apiClient.configureMlScheduler(
        enabled: enabled,
        intervalSeconds: intervalSeconds,
        trainingEvents: trainingEvents,
      );
      _mlLastUpdatedAt = DateTime.now();
      _logAudit(
        action: 'ML Scheduler Configure',
        outcome: 'Success',
        details: 'Scheduler ${enabled ? 'enabled' : 'disabled'} with ${intervalSeconds}s interval.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _logAudit(
        action: 'ML Scheduler Configure',
        outcome: 'Failed',
        details: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> tuneMlThreshold({double targetFalsePositiveRate = 0.20}) async {
    if (!isAdministrator) {
      _logAudit(
        action: 'ML Threshold Tune',
        outcome: 'Denied',
        details: 'Only administrators can tune ML threshold.',
      );
      notifyListeners();
      return false;
    }

    try {
      final response = await _apiClient.tuneMlThreshold(
        targetFalsePositiveRate: targetFalsePositiveRate,
      );
      await refreshMlInsights();
      _logAudit(
        action: 'ML Threshold Tune',
        outcome: 'Success',
        details: (response['message'] ?? 'Threshold tuned').toString(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _logAudit(
        action: 'ML Threshold Tune',
        outcome: 'Failed',
        details: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> switchMlVersion(String versionId) async {
    if (!isAdministrator) {
      _logAudit(
        action: 'ML Model Switch',
        outcome: 'Denied',
        details: 'Only administrators can switch model versions.',
      );
      notifyListeners();
      return false;
    }

    try {
      _mlVersions = await _apiClient.switchMlModelVersion(versionId: versionId);
      await refreshMlInsights();
      _logAudit(
        action: 'ML Model Switch',
        outcome: 'Success',
        details: 'Switched active model to version $versionId.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _logAudit(
        action: 'ML Model Switch',
        outcome: 'Failed',
        details: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  void setUserRole(UserRole role) {
    if (_currentUserRole == role) {
      return;
    }

    _currentUserRole = role;
    _logAudit(
      action: 'Role Change',
      outcome: 'Success',
      details: 'Frontend role switched to ${currentRoleLabel.toLowerCase()}.',
    );
    notifyListeners();
  }

  void clearAuditLog() {
    _auditEvents.clear();
    _logAudit(
      action: 'Audit Log',
      outcome: 'Cleared',
      details: 'Audit timeline was cleared by user action.',
    );
    notifyListeners();
  }

  ThreatSummary _computeSummary() {
    final latest = _metrics.isNotEmpty ? _metrics.last : null;

    int countWhere(bool Function(ThreatAlert a) predicate) {
      return _alerts.where(predicate).length;
    }

    return ThreatSummary(
      activeThreats: countWhere((a) => a.status != 'Resolved'),
      newAlerts: _alerts.where((a) => _isSameDay(a.time, DateTime.now())).length,
      resolvedToday: _alerts
          .where((a) => a.status == 'Resolved' && _isSameDay(a.time, DateTime.now()))
          .length,
      criticalOpen: countWhere((a) => a.severity == 'Critical' && a.status != 'Resolved'),
      highSeverity: countWhere((a) => a.severity == 'High'),
      investigations: countWhere((a) => a.status == 'Investigating'),
      autoResolved: countWhere((a) => a.status == 'Resolved'),
      anomalies: countWhere((a) => a.status == 'Investigating' || a.status == 'Monitoring'),
      packetRate: latest?.packetsPerSecond ?? 0,
      monitoredHosts: 120 + _random.nextInt(16),
    );
  }

  Future<void> _refreshFromBackend({required bool notify}) async {
    if (_refreshInFlight) {
      return;
    }

    _refreshInFlight = true;
    try {
      final responses = await Future.wait([
        _apiClient.fetchSummary(),
        _apiClient.fetchAlerts(limit: 40),
        _apiClient.fetchRecentMetrics(limit: 30),
      ]);

      final summaryJson = responses[0] as Map<String, dynamic>;
      final alertsJson = responses[1] as List<dynamic>;
      final metricsJson = responses[2] as List<dynamic>;

      _alerts
        ..clear()
        ..addAll(
          alertsJson.whereType<Map<String, dynamic>>().map(ThreatAlert.fromJson).toList(),
        );
      _metrics
        ..clear()
        ..addAll(
          metricsJson.whereType<Map<String, dynamic>>().map(NetworkMetric.fromJson).toList(),
        );

      final backendSummary = ThreatSummary.fromJson(summaryJson);
      _cachedSummary = backendSummary;
      _lastSyncAt = DateTime.now();
      _applySummaryDerivedMetrics(backendSummary);
      _rebuildTrendFromMetrics();
      _backendHealthy = true;

      if (notify) {
        notifyListeners();
      }
    } on BackendCircuitOpenException catch (e) {
      _backendHealthy = false;
      _logAudit(
        action: 'Backend Sync',
        outcome: 'Deferred',
        details: e.message,
      );
    } catch (_) {
      _backendHealthy = false;
    } finally {
      _refreshInFlight = false;
    }
  }

  void _connectWebSocket() {
    try {
      final uri = _apiClient.websocketUri();
      _wsChannel = WebSocketChannel.connect(uri);
      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          final decoded = _decodeWsPayload(message);
          if (decoded == null) {
            return;
          }

          final type = (decoded['type'] ?? '').toString();
          if (type == 'snapshot') {
            final summaryRaw = decoded['summary'];
            if (summaryRaw is Map<String, dynamic>) {
              final backendSummary = ThreatSummary.fromJson(summaryRaw);
              _cachedSummary = backendSummary;
              _lastSyncAt = DateTime.now();
              _applySummaryDerivedMetrics(backendSummary);
            }

            final alertItems = decoded['alerts'];
            if (alertItems is List) {
              _alerts
                ..clear()
                ..addAll(
                  alertItems.whereType<Map<String, dynamic>>().map(ThreatAlert.fromJson).toList(),
                );
            }

            final metricItems = decoded['metrics'];
            if (metricItems is List) {
              _metrics
                ..clear()
                ..addAll(
                  metricItems
                      .whereType<Map<String, dynamic>>()
                      .map(NetworkMetric.fromJson)
                      .toList(),
                );
            }

            _rebuildTrendFromMetrics();
            _backendHealthy = true;
            notifyListeners();
            return;
          }

          if (type == 'ingest') {
            final summaryRaw = decoded['summary'];
            if (summaryRaw is Map<String, dynamic>) {
              _cachedSummary = ThreatSummary.fromJson(summaryRaw);
              _lastSyncAt = DateTime.now();
              _backendHealthy = true;
              notifyListeners();
              return;
            }
          }

          if (_pollTick % 2 == 0) {
            unawaited(_refreshFromBackend(notify: true));
          }
        },
        onError: (_) {
          _backendHealthy = false;
          _logAudit(
            action: 'WebSocket Stream',
            outcome: 'Error',
            details: 'Live stream error encountered, awaiting reconnect.',
          );
          _wsSubscription = null;
          _wsChannel = null;
        },
        onDone: () {
          _backendHealthy = false;
          _logAudit(
            action: 'WebSocket Stream',
            outcome: 'Disconnected',
            details: 'Live stream closed, reconnect scheduled.',
          );
          _wsSubscription = null;
          _wsChannel = null;
        },
      );
    } catch (_) {
      _backendHealthy = false;
      _logAudit(
        action: 'WebSocket Stream',
        outcome: 'Failed',
        details: 'Unable to establish websocket connection.',
      );
      _wsSubscription = null;
      _wsChannel = null;
    }
  }

  Map<String, dynamic>? _decodeWsPayload(dynamic message) {
    if (message is Map<String, dynamic>) {
      return message;
    }

    if (message is String) {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }

    return null;
  }

  void _applySummaryDerivedMetrics(ThreatSummary backendSummary) {
    if (_metrics.isEmpty) {
      _metrics.add(
        NetworkMetric(
          time: DateTime.now(),
          packetsPerSecond: backendSummary.packetRate,
          anomalyScore: (backendSummary.anomalies / 10).clamp(0.0, 1.0),
          suspiciousConnections: backendSummary.anomalies,
        ),
      );
    }
  }

  void _rebuildTrendFromMetrics() {
    final sorted = [..._metrics]..sort((a, b) => a.time.compareTo(b.time));
    final trend = sorted.take(7).map((m) => ((m.anomalyScore * 10).round()).clamp(1, 10)).toList();

    if (trend.isEmpty) {
      return;
    }

    while (trend.length < 7) {
      trend.insert(0, trend.first);
    }

    _dailyThreatTrend
      ..clear()
      ..addAll(trend.take(7));
  }

  void _seedInitialData() {
    final now = DateTime.now();
    for (var i = 0; i < 10; i++) {
      _metrics.add(
        NetworkMetric(
          time: now.subtract(Duration(minutes: 10 - i)),
          packetsPerSecond: 11000 + _random.nextInt(6000),
          anomalyScore: 0.2 + _random.nextDouble() * 0.7,
          suspiciousConnections: 2 + _random.nextInt(16),
        ),
      );
    }

    for (var i = 0; i < 8; i++) {
      _alerts.add(_buildAlert(now.subtract(Duration(minutes: i * 7))));
    }

    _cachedSummary = _computeSummary();
  }

  void _generateMetric() {
    _metrics.add(
      NetworkMetric(
        time: DateTime.now(),
        packetsPerSecond: 10000 + _random.nextInt(8500),
        anomalyScore: 0.12 + _random.nextDouble() * 0.86,
        suspiciousConnections: 1 + _random.nextInt(26),
      ),
    );

    if (_metrics.length > 100) {
      _metrics.removeRange(0, _metrics.length - 100);
    }
  }

  void _generateAlert() {
    _alerts.add(_buildAlert(DateTime.now()));
    if (_alerts.length > 120) {
      _alerts.removeRange(0, _alerts.length - 120);
    }
  }

  ThreatAlert _buildAlert(DateTime timestamp) {
    _sequence += 1;
    final attack = _attackTypes[_random.nextInt(_attackTypes.length)];
    final severity = _severityLevels[_random.nextInt(_severityLevels.length)];
    final status = _statuses[_random.nextInt(_statuses.length)];

    return ThreatAlert(
      id: 'ALT-${timestamp.year}-${_sequence.toString().padLeft(4, '0')}',
      time: timestamp,
      attackType: attack,
      sourceIp:
          '10.${20 + _random.nextInt(60)}.${_random.nextInt(255)}.${1 + _random.nextInt(253)}',
      severity: severity,
      status: status,
      description:
          '$attack pattern detected by ML anomaly model. Confidence elevated due to unusual traffic baseline shift.',
      confidence: 0.55 + _random.nextDouble() * 0.44,
    );
  }

  void _updateTrend() {
    final last = _dailyThreatTrend.last;
    final delta = _random.nextInt(3) - 1;
    final next = (last + delta).clamp(1, 10);

    _dailyThreatTrend.removeAt(0);
    _dailyThreatTrend.add(next);
  }

  void _logAudit({
    required String action,
    required String outcome,
    required String details,
  }) {
    _auditEvents.add(
      AuditEvent(
        time: DateTime.now(),
        action: action,
        outcome: outcome,
        details: details,
      ),
    );

    if (_auditEvents.length > 250) {
      _auditEvents.removeRange(0, _auditEvents.length - 250);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isFlutterTestEnvironment() {
    return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  }
}
