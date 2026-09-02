import 'package:flutter/material.dart';

import '../data/insurance_api.dart';
import '../data/session_store.dart';
import 'insurance_details_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  String? get _userId => SessionStore.currentUserId;

  // IMPORTANT: keep same as other pages
  static final String _apiKey = dotenv.env['API_KEY'] ?? '';

  // Use same BASE_URL logic as you used in details page (dart-define based)
  // ✅ REPLACE WITH
  static final String _baseUrl = dotenv.env['BASE_URL'] ?? '';

  late final InsuranceApi _api = InsuranceApi(
    baseUrl: _baseUrl,
    apiKey: _apiKey,
  );

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  bool _isNotEmpty(String? s) => (s != null && s.trim().isNotEmpty);

  /// Convert InsuranceResponse JSON into a "notification" row for UI.
  Map<String, dynamic> _toNotif(Map<String, dynamic> m) {
    final id = _asInt(m['id']);
    final status = (m['status'] ?? 'PENDING').toString().toUpperCase();
    final reviewedAt = (m['reviewedAt'] ?? '').toString();
    final adminNote = (m['adminNote'] ?? '').toString();

    String title;
    String body;

    if (status == 'APPROVED') {
      title = 'Insurance Approved';
      body = 'Your insurance request was approved.';
    } else if (status == 'MODIFY') {
      title = 'Modification Requested';
      body = _isNotEmpty(adminNote)
          ? adminNote
          : 'Admin requested changes in your insurance upload.';
    } else {
      title = 'Insurance Update';
      body = _isNotEmpty(adminNote) ? adminNote : 'Status updated: $status';
    }

    return {
      'insurance_id': id,
      'title': title,
      'body': body,
      'created_at': reviewedAt,
      'status': status,
    };
  }

  Future<void> _refresh() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _rows = [];
        _loading = false;
        _error = 'Please login again.';
      });
      _snack('Please login again.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // This should call: GET /api/insurance/notifications?userId=...
      final list = await _api.getNotificationsForUser(userId);

      final rows = list
          .map(_toNotif)
          .where((r) => r['insurance_id'] != null)
          .toList();

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      _snack(e.toString());
    }
  }

  Future<void> _handleTap(Map<String, dynamic> r) async {
    final insuranceId = _asInt(r['insurance_id']);
    if (insuranceId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InsuranceDetailsPage(insuranceId: insuranceId),
      ),
    );

    // Optional: refresh after coming back
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final onAppBar =
        Theme.of(context).appBarTheme.foregroundColor ??
        Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            color: onAppBar,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_rows.isEmpty)
          ? RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 240),
                  Center(child: Text(_error ?? 'No notifications yet')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final r = _rows[index];
                  final title = (r['title'] ?? '').toString();
                  final body = (r['body'] ?? '').toString();
                  final createdAt = (r['created_at'] ?? '').toString();
                  final status = (r['status'] ?? '').toString().toUpperCase();

                  IconData icon;
                  Color iconColor;

                  if (status == 'APPROVED') {
                    icon = Icons.check_circle;
                    iconColor = Colors.green;
                  } else if (status == 'MODIFY') {
                    icon = Icons.edit;
                    iconColor = Colors.orange;
                  } else {
                    icon = Icons.info;
                    iconColor = Colors.blueGrey;
                  }

                  return Card(
                    child: ListTile(
                      leading: Icon(icon, color: iconColor),
                      title: Text(title.isEmpty ? '(No title)' : title),
                      subtitle: Text(
                        body.isEmpty ? createdAt : '$body\n$createdAt',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _handleTap(r),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
