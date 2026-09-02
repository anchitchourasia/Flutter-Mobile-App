import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/pass_registry_item.dart';
import '../core/api_config.dart';

class PassRegistryApi {
  // Use centralized URLs and API key
  static String get _passListV1 => ApiConfig.passListV1;
  static String get _apiKey => ApiConfig.apiKey;

  static Map<String, String> get _headers => {
    'x-api-key': _apiKey,
    // No need for Content-Type on GET
  };

  Future<List<PassRegistryItem>> fetchPassRegistry() async {
    final response = await http.get(Uri.parse(_passListV1), headers: _headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to load pass registry. HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid response format. Expected JSON array.');
    }

    return decoded
        .map((e) => PassRegistryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
