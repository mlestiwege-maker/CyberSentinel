import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'threat_feed_service.dart';

class AuditExportService {
  /// Export audit events to CSV format
  static String exportToCsv(List<AuditEvent> events) {
    final buffer = StringBuffer();
    
    // CSV header
    buffer.writeln('Timestamp,Action,Outcome,Details');
    
    // CSV rows (sorted by time, newest first)
    final sorted = List<AuditEvent>.from(events)..sort((a, b) => b.time.compareTo(a.time));
    for (final event in sorted) {
      final timestamp = event.time.toIso8601String();
      final action = _escapeCsvField(event.action);
      final outcome = _escapeCsvField(event.outcome);
      final details = _escapeCsvField(event.details);
      
      buffer.writeln('$timestamp,$action,$outcome,$details');
    }
    
    return buffer.toString();
  }
  
  /// Export audit events to JSON format
  static String exportToJson(List<AuditEvent> events) {
    // Sort by time, newest first
    final sorted = List<AuditEvent>.from(events)..sort((a, b) => b.time.compareTo(a.time));
    
    final jsonList = sorted.map((event) => {
      'timestamp': event.time.toIso8601String(),
      'action': event.action,
      'outcome': event.outcome,
      'details': event.details,
    }).toList();
    
    return JsonEncoder.withIndent('  ').convert({
      'audit_export': {
        'exported_at': DateTime.now().toIso8601String(),
        'total_events': jsonList.length,
        'events': jsonList,
      }
    });
  }
  
  /// Escape CSV field values (handle quotes and commas)
  static String _escapeCsvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
  
  /// Save CSV to file (desktop/mobile)
  static Future<String?> saveCsvToFile(List<AuditEvent> events) async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filename = 'cybersentinel-audit-$timestamp.csv';
      
      final documentsDir = await _getDocumentsDirectory();
      if (documentsDir == null) return null;
      
      final filepath = '${documentsDir.path}/$filename';
      final file = File(filepath);
      
      final csv = exportToCsv(events);
      await file.writeAsString(csv);
      
      return filepath;
    } catch (e) {
      debugPrint('Error saving CSV: $e');
      return null;
    }
  }
  
  /// Save JSON to file (desktop/mobile)
  static Future<String?> saveJsonToFile(List<AuditEvent> events) async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filename = 'cybersentinel-audit-$timestamp.json';
      
      final documentsDir = await _getDocumentsDirectory();
      if (documentsDir == null) return null;
      
      final filepath = '${documentsDir.path}/$filename';
      final file = File(filepath);
      
      final json = exportToJson(events);
      await file.writeAsString(json);
      
      return filepath;
    } catch (e) {
      debugPrint('Error saving JSON: $e');
      return null;
    }
  }
  
  /// Get documents directory (platform-aware)
  static Future<Directory?> _getDocumentsDirectory() async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop: use home directory Documents
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null) {
          return Directory('$home/Downloads');
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: use app documents directory
        // In real app, would use path_provider package
        // For now, return null to disable file export on mobile
        return null;
      }
    } catch (e) {
      debugPrint('Error getting documents directory: $e');
    }
    return null;
  }
  
  /// Copy audit export to clipboard (web-friendly fallback)
  static Future<void> copyToClipboard(String content) async {
    // In a real app, would use flutter_web_clipboard or similar
    // For now, this is a stub for future web support
    debugPrint('Copy to clipboard called with ${content.length} bytes');
  }
}
