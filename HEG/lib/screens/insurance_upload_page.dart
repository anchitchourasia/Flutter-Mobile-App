import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/session_store.dart';
import '../data/insurance_api.dart';
import 'insurance_details_page.dart';

class InsuranceUploadPage extends StatefulWidget {
  const InsuranceUploadPage({super.key});

  @override
  State<InsuranceUploadPage> createState() => _InsuranceUploadPageState();
}

class _InsuranceUploadPageState extends State<InsuranceUploadPage> {
  static const Color _bg1 = Color(0xFF0B1E3A);
  static const Color _bg2 = Color(0xFF0EA5A4);

  final _formKey = GlobalKey<FormState>();

  final _vehicleNumberCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _validFromCtrl = TextEditingController();
  final _validToCtrl = TextEditingController();

  String _vehicleType = 'Two Wheeler';
  String _insuranceType = 'Comprehensive';

  List<Map<String, Object?>> _rows = [];

  String? _pickedPdfPath;
  String? _pickedPdfName;

  String _adminStatusFilter = 'ALL'; // ALL / PENDING / APPROVED / MODIFY
  bool _loading = false;

  String? get _userId => SessionStore.currentUserId;
  bool get _isAdmin => SessionStore.isAdmin == true;

  bool _checkedArgs = false;
  int? _autoOpenDetailsId;

  // IMPORTANT:
  // - Emulator: 10.0.2.2
  // - Real phone: use your backend machine LAN IP (e.g. 192.168.9.33)
  // 10.0.2.2 works only on Android emulator. [web:9015]
  static const String _apiKey = 'HEG_12345_SECRET';

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080'; // emulator default
    return 'http://localhost:8080';
  }

  late final InsuranceApi _api = InsuranceApi(
    baseUrl: _baseUrl,
    apiKey: _apiKey,
  );

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_checkedArgs) return;
    _checkedArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['openDetailsId'] is int) {
      _autoOpenDetailsId = args['openDetailsId'] as int;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openDetailsIfNeeded();
      });
    }
  }

  Future<void> _openDetailsIfNeeded() async {
    final id = _autoOpenDetailsId;
    if (id == null) return;
    _autoOpenDetailsId = null;

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InsuranceDetailsPage(insuranceId: id)),
    );
    await _refresh();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _withLoading(Future<void> Function() fn) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await fn();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  // Normalize backend JSON list to map list for UI
  List<Map<String, Object?>> _normalizeList(List<dynamic> raw) {
    return raw.map((e) {
      final m = (e as Map).cast<String, dynamic>();
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
        'has_pdf': m['hasPdf'],
      };
    }).toList();
  }

  Future<void> _refresh() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      setState(() => _rows = []);
      _snack('No logged-in user found. Please login again.');
      return;
    }

    await _withLoading(() async {
      if (_isAdmin) {
        final status = (_adminStatusFilter == 'ALL')
            ? null
            : _adminStatusFilter;
        final list = await _api.listForAdmin(status: status);
        if (!mounted) return;
        setState(() => _rows = _normalizeList(list));
        return;
      }

      final list = await _api.listForUser(userId);
      if (!mounted) return;
      setState(() => _rows = _normalizeList(list));
    });
  }

  void _resetForm() {
    FocusScope.of(context).unfocus();
    _formKey.currentState?.reset();

    _vehicleNumberCtrl.clear();
    _companyCtrl.clear();
    _validFromCtrl.clear();
    _validToCtrl.clear();

    _vehicleType = 'Two Wheeler';
    _insuranceType = 'Comprehensive';

    _pickedPdfPath = null;
    _pickedPdfName = null;

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    controller.text =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.path == null) return;

    if (!file.name.toLowerCase().endsWith('.pdf')) {
      _snack('Please select a PDF file');
      return;
    }

    setState(() {
      _pickedPdfPath = file.path!;
      _pickedPdfName = file.name;
    });
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

  Future<void> _save() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      _snack('Please login again.');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _withLoading(() async {
      final body = <String, dynamic>{
        'userId': userId,
        'vehicleType': _vehicleType,
        'vehicleNumber': _vehicleNumberCtrl.text.trim(),
        'insuranceType': _insuranceType,
        'validFrom': _validFromCtrl.text.trim(),
        'validTo': _validToCtrl.text.trim(),
        'companyName': _companyCtrl.text.trim(),
      };

      final id = await _api.createInsurance(body);

      if (_pickedPdfPath != null) {
        final docsDir = await getApplicationDocumentsDirectory();
        final insuranceDir = Directory(p.join(docsDir.path, 'insurance_pdfs'));
        if (!await insuranceDir.exists()) {
          await insuranceDir.create(recursive: true);
        }

        final ext = p.extension(_pickedPdfPath!);
        final safeVehicle = _vehicleNumberCtrl.text.trim().replaceAll(
          RegExp(r'[^a-zA-Z0-9_-]'),
          '_',
        );
        final newFileName = 'insurance_${safeVehicle}_$id$ext';
        final newPath = p.join(insuranceDir.path, newFileName);
        await File(_pickedPdfPath!).copy(newPath);

        await _uploadPdfToBackend(
          insuranceId: id,
          uploadedBy: userId,
          pdfPath: newPath,
        );
      }

      _resetForm();
      await _refresh();
      _snack('Saved to server');
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'MODIFY':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _statusChip(String status) {
    final s = status.toUpperCase();
    final c = _statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        s,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Future<void> _adminApprove(Map<String, Object?> r) async {
    final adminId = _userId;
    if (adminId == null || adminId.isEmpty) return;

    final id = r['id'] as int?;
    if (id == null) {
      _snack('Invalid record');
      return;
    }

    await _withLoading(() async {
      await _api.updateStatus(id, {
        'status': 'APPROVED',
        'reviewedBy': adminId,
        'adminNote': null,
      });
      await _refresh();
      _snack('Approved');
    });
  }

  Future<void> _adminSendForModification(Map<String, Object?> r) async {
    final adminId = _userId;
    if (adminId == null || adminId.isEmpty) return;

    final id = r['id'] as int?;
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
                  'E.g. Upload clearer PDF / correct dates / correct vehicle number',
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

    await _withLoading(() async {
      await _api.updateStatus(id, {
        'status': 'MODIFY',
        'reviewedBy': adminId,
        'adminNote': note.isEmpty ? null : note,
      });
      await _refresh();
      _snack('Sent for modification');
    });
  }

  Widget _adminCard(Map<String, Object?> r) {
    final id = r['id'] as int?;
    final userId = r['user_id']?.toString() ?? '-';
    final status = (r['status']?.toString() ?? 'PENDING').toUpperCase();
    final adminNote = (r['admin_note']?.toString() ?? '').trim();

    final isPending = status == 'PENDING';

    return Card(
      surfaceTintColor: Colors.transparent,
      child: InkWell(
        onTap: (id == null)
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InsuranceDetailsPage(insuranceId: id),
                  ),
                );
                await _refresh();
              },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${r['vehicle_number']} • ${r['vehicle_type']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _statusChip(status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'User: $userId\n'
                '${r['insurance_type']} | ${r['company_name']}\n'
                '${r['valid_from']} to ${r['valid_to']}'
                '${adminNote.isEmpty ? '' : '\nNote: $adminNote'}',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isPending ? () => _adminApprove(r) : null,
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _adminSendForModification(r),
                      child: const Text('Send for modification'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whiteSurface({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
    );
  }

  Widget _buildAdminBody() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _adminStatusFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All')),
                DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                DropdownMenuItem(value: 'MODIFY', child: Text('Modify')),
              ],
              onChanged: (v) async {
                setState(() => _adminStatusFilter = v ?? 'ALL');
                await _refresh();
              },
              decoration: const InputDecoration(labelText: 'Filter by status'),
            ),
            const SizedBox(height: 16),
            if (_rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Center(child: Text('No records')),
              )
            else
              ..._rows.map(_adminCard),
          ],
        ),
        if (_loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildUserBody() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _vehicleType,
                    items: const [
                      DropdownMenuItem(
                        value: 'Two Wheeler',
                        child: Text('Two Wheeler'),
                      ),
                      DropdownMenuItem(
                        value: 'Four Wheeler',
                        child: Text('Four Wheeler'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _vehicleType = v ?? 'Two Wheeler'),
                    decoration: const InputDecoration(
                      labelText: 'Vehicle type',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _vehicleNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle number',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _insuranceType,
                    items: const [
                      DropdownMenuItem(
                        value: 'Comprehensive',
                        child: Text('Comprehensive'),
                      ),
                      DropdownMenuItem(
                        value: 'Third Party',
                        child: Text('Third Party'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _insuranceType = v ?? 'Comprehensive'),
                    decoration: const InputDecoration(
                      labelText: 'Insurance type',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _validFromCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Valid from',
                      suffixIcon: Icon(Icons.date_range),
                    ),
                    onTap: () => _pickDate(_validFromCtrl),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _validToCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Valid to',
                      suffixIcon: Icon(Icons.date_range),
                    ),
                    onTap: () => _pickDate(_validToCtrl),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _companyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Insurance company',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Pick PDF'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _pickedPdfName == null
                          ? 'No PDF selected'
                          : 'Selected: $_pickedPdfName',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Saved records',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ..._rows.map((r) {
              final id = r['id'] as int?;
              final status = (r['status']?.toString() ?? 'PENDING')
                  .toUpperCase();
              return Card(
                surfaceTintColor: Colors.transparent,
                child: ListTile(
                  title: Text('${r['vehicle_number']} • ${r['vehicle_type']}'),
                  subtitle: Text(
                    '${r['insurance_type']} | ${r['company_name']}\n'
                    '${r['valid_from']} to ${r['valid_to']}\n'
                    'Status: $status',
                  ),
                  onTap: (id == null)
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  InsuranceDetailsPage(insuranceId: id),
                            ),
                          );
                          await _refresh();
                        },
                ),
              );
            }),
            if (_rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Center(child: Text('No records')),
              ),
          ],
        ),
        if (_loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _vehicleNumberCtrl.dispose();
    _companyCtrl.dispose();
    _validFromCtrl.dispose();
    _validToCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _isAdmin ? _buildAdminBody() : _buildUserBody();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isAdmin ? 'Insurance Upload (Admin)' : 'Insurance Upload'),
        backgroundColor: const Color.fromARGB(255, 237, 239, 240),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              if (!_isAdmin) _resetForm();
              await _refresh();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bg1, _bg2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _whiteSurface(child: content),
          ),
        ),
      ),
    );
  }
}
