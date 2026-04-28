import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_api_client.dart';

class IncidentApiClient {
  static String baseUrl = BackendApiClient.defaultBaseUrl();
  
  static Future<Map<String, dynamic>> getIncidents({String? status}) async {
    final uri = Uri.parse('$baseUrl/api/v1/incidents' + (status != null ? '?status=$status' : ''));
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> getActiveIncidents() async {
    final uri = Uri.parse('$baseUrl/api/v1/incidents/active');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> getSlaStats() async {
    final uri = Uri.parse('$baseUrl/api/v1/incidents/sla');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> getIncident(String id) async {
    final uri = Uri.parse('$baseUrl/api/v1/incidents/$id');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> createIncident({
    required String title,
    required String description,
    required String severity,
    String? sourceIp,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/incidents');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'severity': severity,
        if (sourceIp != null) 'source_ip': sourceIp,
      }),
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> updateIncidentStatus(String id, String status, {String? notes}) async {
    final uri = Uri.parse('$baseUrl/api/v1/incidents/$id/status?status=$status' + (notes != null ? '&notes=$notes' : ''));
    final response = await http.post(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> assignIncident(String id, String analystId) async {
    final uri = Uri.parse('$baseUrl/api/v1/incidents/$id/assign?analyst_id=$analystId');
    final response = await http.post(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> getAnalysts() async {
    final uri = Uri.parse('$baseUrl/api/v1/incidents/analysts');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
