import 'dart:convert';
import 'package:http/http.dart' as http;

class InsuranceApi {
  final String baseUrl;
  final String apiKey;

  InsuranceApi({required this.baseUrl, required this.apiKey});

  Map<String, String> _headers({bool json = true}) => {
    'X-API-KEY': apiKey,
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json',
  };

  void _throwIfNotOk(http.Response res, String label) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception('$label ${res.statusCode}: ${res.body}');
  }

  /// POST /api/insurance  -> returns id (plain number or JSON)
  Future<int> createInsurance(Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl/api/insurance');
    final res = await http.post(
      uri,
      headers: _headers(json: true),
      body: jsonEncode(body),
    );

    _throwIfNotOk(res, 'createInsurance');

    final t = res.body.trim();

    final asInt = int.tryParse(t);
    if (asInt != null) return asInt;

    final decoded = jsonDecode(t);
    if (decoded is Map && decoded['id'] != null) {
      return int.parse(decoded['id'].toString());
    }

    throw Exception('Unexpected createInsurance response: ${res.body}');
  }

  /// GET /api/insurance/user/{userId}
  Future<List<dynamic>> listForUser(String userId) async {
    final uri = Uri.parse('$baseUrl/api/insurance/user/$userId');
    final res = await http.get(uri, headers: _headers(json: false));

    _throwIfNotOk(res, 'listForUser');
    return jsonDecode(res.body) as List<dynamic>;
  }

  /// GET /api/insurance/{id}
  Future<Map<String, dynamic>> getById(int id) async {
    final uri = Uri.parse('$baseUrl/api/insurance/$id');
    final res = await http.get(uri, headers: _headers(json: false));

    _throwIfNotOk(res, 'getById');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// GET /api/insurance/admin?status=...
  Future<List<dynamic>> listForAdmin({String? status}) async {
    final qp = <String, String>{};
    if (status != null && status.trim().isNotEmpty) {
      qp['status'] = status.trim();
    }

    final uri = Uri.parse(
      '$baseUrl/api/insurance/admin',
    ).replace(queryParameters: qp.isEmpty ? null : qp);

    final res = await http.get(uri, headers: _headers(json: false));

    _throwIfNotOk(res, 'listForAdmin');
    return jsonDecode(res.body) as List<dynamic>;
  }

  /// PATCH /api/insurance/{id}
  Future<void> updateStatus(int id, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl/api/insurance/$id');
    final res = await http.patch(
      uri,
      headers: _headers(json: true),
      body: jsonEncode(body),
    );

    _throwIfNotOk(res, 'updateStatus');
  }

  /// NEW: Derived notifications (no extra DB table)
  /// GET /api/insurance/notifications?userId=...
  Future<List<Map<String, dynamic>>> getNotificationsForUser(
    String userId,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/api/insurance/notifications',
    ).replace(queryParameters: {'userId': userId});

    final res = await http.get(uri, headers: _headers(json: false));

    _throwIfNotOk(res, 'getNotificationsForUser');

    final decoded = jsonDecode(res.body);
    if (decoded is! List) {
      throw Exception(
        'getNotificationsForUser: expected JSON list, got: ${decoded.runtimeType}',
      );
    }

    return decoded
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }
}
