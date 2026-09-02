import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';

class GateLogApi {
  GateLogApi._();

  static Future<Map<String, dynamic>> saveAction({
    required int permissionNo,
    required String action,
    required String enterBy,
  }) async {
    final response = await http
        .post(
          Uri.parse(ApiConfig.dummyCvpsGateLogs),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': ApiConfig.dummyGateLogApiKey,
          },
          body: jsonEncode({
            'permissionNo': permissionNo,
            'action': action.trim().toUpperCase(),
            'enterBy': enterBy.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final responseBody = response.body.trim();

    if (response.statusCode == 200 || response.statusCode == 201) {
      return responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody) as Map<String, dynamic>;
    }

    throw Exception(
      'Gate action failed: HTTP ${response.statusCode}: $responseBody',
    );
  }

  static Future<String?> getLatestAction(int permissionNo) async {
    final url = '${ApiConfig.dummyCvpsGateLogs}/$permissionNo/latest';

    final response = await http
        .get(
          Uri.parse(url),
          headers: {'x-api-key': ApiConfig.dummyGateLogApiKey},
        )
        .timeout(const Duration(seconds: 15));

    final responseBody = response.body.trim();

    if (response.statusCode != 200) {
      throw Exception(
        'Could not load gate state. '
        'HTTP ${response.statusCode}: $responseBody',
      );
    }

    if (responseBody.isEmpty) {
      return null;
    }

    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final action = (data['lastAction'] ?? '').toString().trim().toUpperCase();

    if (action == 'IN' || action == 'OUT') {
      return action;
    }

    return null;
  }
}
