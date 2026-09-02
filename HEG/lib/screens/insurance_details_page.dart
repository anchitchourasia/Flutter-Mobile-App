import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../data/insurance_api.dart';
import '../data/session_store.dart';

class InsuranceDetailsPage extends StatefulWidget {
  final int insuranceId;
  const InsuranceDetailsPage({super.key, required this.insuranceId});

  @override
  State<InsuranceDetailsPage> createState() => _InsuranceDetailsPageState();
}

class _InsuranceDetailsPageState extends State<InsuranceDetailsPage> {
  Map<String, Object?>? _row;
  bool _loading = true;
  String? _error;

  String? get _userId => SessionStore.currentUserId;
  bool get _isAdmin => SessionStore.isAdmin == true;

  // Keep consistent with InsuranceUploadPage / backend.
  static final String _apiKey = dotenv.env['API_KEY'] ?? '';

  static final String _baseUrl = dotenv.env['BASE_URL'] ?? '';

  late final InsuranceApi _api = InsuranceApi(
    baseUrl: _baseUrl,
    apiKey: _apiKey,
  );

  bool get _hasPdf => (_row?['has_pdf'] == true);

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Map<String, Object?> _normalizeOne(Map<String, dynamic> m) {
    return <String, Object?>{
      'id': _asInt(m['id']),
      'user_id': m['userId'],
      'vehicle_type': m['vehicleType'],
      'vehicle_number': m['vehicleNumber'],
      'insurance_type': m['insuranceType'],
      'valid_from': m['validFrom'],
      'valid_to': m['validTo'],
      'company_name': m['companyName'],
      'status': m['status'],
      'admin_note': m['adminNote'],
      'reviewed_by': m['reviewedBy'],
      'reviewed_at': m['reviewedAt'],
      'created_at': m['createdAt'],
      'has_pdf': m['hasPdf'] == true,
    };
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _row = null;
        _error = 'No logged-in user found. Please login again.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final m = await _api.getById(widget.insuranceId);
      if (!mounted) return;
      setState(() {
        _row = _normalizeOne(m);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();

      setState(() {
        _loading = false;
        _row = null;
        _error = msg;
      });

      if (msg.contains('403')) {
        _snack('Invalid X-API-KEY. Check apiKey in Flutter matches backend.');
      } else if (msg.contains('404')) {
        _snack('Record not found for id=${widget.insuranceId}.');
      } else {
        _snack(msg);
      }
    }
  }

  Future<void> _uploadPdfToBackend({
    required int insuranceId,
    required String uploadedBy,
    required String pdfPath,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/insurance/$insuranceId/pdf');

    final req = http.MultipartRequest('POST', uri)
      ..headers['X-API-KEY'] = _apiKey
      ..fields['uploadedBy'] = uploadedBy
      ..files.add(await http.MultipartFile.fromPath('file', pdfPath));

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode != 200) {
      throw Exception('uploadPdf ${res.statusCode}: $body');
    }
  }

  Future<void> _attachPdf() async {
    if (_isAdmin) {
      _snack('Admin cannot attach PDF. Ask user to upload.');
      return;
    }

    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      _snack('Please login again.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    if (picked.path == null) return;

    if (!picked.name.toLowerCase().endsWith('.pdf')) {
      _snack('Please select a PDF file');
      return;
    }

    setState(() => _loading = true);

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final insuranceDir = Directory(p.join(docsDir.path, 'insurance_pdfs'));
      if (!await insuranceDir.exists()) {
        await insuranceDir.create(recursive: true);
      }

      final ext = p.extension(picked.path!);
      final newName = 'insurance_${widget.insuranceId}$ext';
      final newPath = p.join(insuranceDir.path, newName);

      await File(picked.path!).copy(newPath);

      await _uploadPdfToBackend(
        insuranceId: widget.insuranceId,
        uploadedBy: userId,
        pdfPath: newPath,
      );

      await _load();
      _snack('PDF uploaded to server');
    } catch (e) {
      _snack(e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadAndOpenPdf() async {
    final uri = Uri.parse('$_baseUrl/api/insurance/${widget.insuranceId}/pdf');

    setState(() => _loading = true);

    try {
      final res = await http.get(uri, headers: {'X-API-KEY': _apiKey});

      if (res.statusCode != 200) {
        throw Exception('downloadPdf ${res.statusCode}: ${res.body}');
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final insuranceDir = Directory(p.join(docsDir.path, 'insurance_pdfs'));
      if (!await insuranceDir.exists()) {
        await insuranceDir.create(recursive: true);
      }

      final filePath = p.join(
        insuranceDir.path,
        'insurance_${widget.insuranceId}.pdf',
      );
      final f = File(filePath);
      await f.writeAsBytes(res.bodyBytes, flush: true);

      final result = await OpenFilex.open(filePath);
      if (!mounted) return;
      if (result.message.isNotEmpty) {
        _snack('${result.type}: ${result.message}');
      }
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve() async {
    if (!_isAdmin) return;

    final adminId = _userId;
    if (adminId == null || adminId.isEmpty) return;

    final id = _row?['id'] as int?;
    if (id == null) {
      _snack('Invalid record');
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.updateStatus(id, {
        'status': 'APPROVED',
        'reviewedBy': adminId,
        'adminNote': null,
      });
      await _load();
      _snack('Approved');
    } catch (e) {
      _snack(e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendForModification() async {
    if (!_isAdmin) return;

    final adminId = _userId;
    if (adminId == null || adminId.isEmpty) return;

    final id = _row?['id'] as int?;
    if (id == null) {
      _snack('Invalid record');
      return;
    }

    String tempNote = '';
    final note = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send for modification'),
        content: StatefulBuilder(
          builder: (context, setState) => TextField(
            autofocus: true,
            onChanged: (v) => setState(() => tempNote = v),
            decoration: const InputDecoration(
              labelText: 'Message (optional)',
              hintText:
                  'E.g. Upload clear PDF, correct vehicle number, correct dates',
            ),
            minLines: 1,
            maxLines: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, tempNote.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (note == null) return;

    setState(() => _loading = true);
    try {
      await _api.updateStatus(id, {
        'status': 'MODIFY',
        'reviewedBy': adminId,
        'adminNote': note.isEmpty ? null : note,
      });
      await _load();
      _snack('Sent for modification');
    } catch (e) {
      _snack(e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _kv(String k, Object? v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v?.toString() ?? '-')),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = (_row?['status']?.toString() ?? 'PENDING').toUpperCase();
    final isPending = status == 'PENDING';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_row == null)
          ? Center(child: Text(_error ?? 'Record not found'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_isAdmin) _kv('User', _row!['user_id']),
                _kv('Vehicle type', _row!['vehicle_type']),
                _kv('Vehicle number', _row!['vehicle_number']),
                _kv('Insurance type', _row!['insurance_type']),
                _kv('Valid from', _row!['valid_from']),
                _kv('Valid to', _row!['valid_to']),
                _kv('Company', _row!['company_name']),
                _kv('Status', status),
                if ((_row!['admin_note'] ?? '').toString().trim().isNotEmpty)
                  _kv('Admin note', _row!['admin_note']),
                _kv('Has PDF', _hasPdf ? 'YES' : 'NO'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _hasPdf ? _downloadAndOpenPdf : null,
                    child: const Text('Open PDF'),
                  ),
                ),
                const SizedBox(height: 10),
                if (!_isAdmin)
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _attachPdf,
                      child: const Text('Upload/Replace PDF'),
                    ),
                  ),
                if (!_hasPdf) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'No PDF attached to this record.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 18),
                if (_isAdmin)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isPending ? _approve : null,
                          child: const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _sendForModification,
                          child: const Text('Send for modification'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
