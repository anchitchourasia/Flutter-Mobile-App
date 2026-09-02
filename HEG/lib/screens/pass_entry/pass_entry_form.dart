import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import 'pass_entry_models.dart';
import 'pass_entry_widgets.dart';
import '/core/api_config.dart';

class PassEntryForm extends StatefulWidget {
  final int? registryId;
  final bool isViewMode;
  final bool isApproverMode;

  const PassEntryForm({
    super.key,
    this.registryId,
    this.isViewMode = false,
    this.isApproverMode = false,
  });

  @override
  State<PassEntryForm> createState() => _PassEntryFormState();
}

class _PassEntryFormState extends State<PassEntryForm> {
  // ── Scroll controller for the form ──────────────────────────────
  final _scrollCtrl = ScrollController();

  // ── Vehicle ────────────────────────────────────────────────────
  final _vehicleNoCtrl = TextEditingController();
  String _vehicleType = '';
  final _brandModelCtrl = TextEditingController();
  final _passNoCtrl = TextEditingController();

  // ── Registry ID (local copy for update vs add) ──────────────────
  int? _registryId;

  // ── Employee ───────────────────────────────────────────────────
  final _ecNoCtrl = TextEditingController();
  String _empType = '';

  bool _fetchingEmployee = false;
  String? _empFetchError;

  String _empName = '';
  String _empDept = '';
  String _empDeptCode = '';
  String _empAadhar = '';
  String _empContractorCode = '';
  String _empContractorName = '';

  // ── Pass Details ────────────────────────────────────────────────
  String _gateNo = '';
  String _parkingToBeUsed = '';

  // ── Workflow ───────────────────────────────────────────────────
  String _status = 'DRAFT';
  int? _passNo;
  String? _remark;
  String _enterBy = 'SYSTEM';

  // ── Documents ───────────────────────────────────────────────────
  final List<PassDocumentModel> _documents = [
    PassDocumentModel(
      documentId: null,
      documentType: '',
      documentNo: '',
      expiryDate: '',
      fileKey: 'document_0',
      fileName: '',
      filePath: null,
    ),
  ];

  // ── UI State ───────────────────────────────────────────────────
  bool _isSaving = false;
  String? _saveSuccess;
  String? _saveError;

  // ── Approver workflow state ─────────────────────────────────────
  final TextEditingController _remarkCtrl = TextEditingController();
  bool _isWorkflowSubmitting = false;
  String? _workflowError;
  String? _workflowSuccess;

  bool get _isReadOnly =>
      widget.isViewMode || !_canEdit; // respect canEdit logic for creator

  // ── Constants ──────────────────────────────────────────────────
  static const _vehicleTypes = [
    'BIKE',
    'SCOOTER',
    'CAR',
    'TRUCK',
    'DUMPER',
    'JCB',
    'CRANE',
    'TRACTOR',
  ];
  static const _empTypes = ['HEG', 'TACC', 'CONTRACT', 'CRE-PRM'];
  static const _gates = ['GATE_01', 'GATE_02', 'GATE_03', 'GATE_04', 'GATE_05'];
  static const _parkings = ['P1', 'P2', 'P3', 'P4', 'P5'];
  static const _allowedDocTypes = ['RC', 'INSURANCE', 'LICENSE'];

  // ── API config ──────────────────────────────────────────────────
  String get _employeeReportUrl => ApiConfig.employeeReport;
  String get _passSaveUrl => ApiConfig.passSave;
  String get _passUpdateUrl => ApiConfig.passUpdate;
  String get _passListUrl => ApiConfig.passList;
  String get _passStatusUpdateUrl => ApiConfig.passStatusUpdate;
  String get _apiKey => ApiConfig.apiKey;
  String get _passHistoryUrl => ApiConfig.passHistory; // <- ADD THIS LINE

  // ── Pass History state ──────────────────────────────────────────
  bool _showHistory = false; // ADD
  bool _loadingHistory = false; // ADD
  String? _historyError; // ADD
  List<PassHistoryItem> _history = []; // ADD

  // ── Role-based guards (mirroring web canEdit/canApprove) ───────
  bool get _canEdit {
    if (widget.isViewMode || widget.isApproverMode) {
      return false;
    }
    final s = _status.trim().toUpperCase();
    return s == 'DRAFT' ||
        s == 'SAVED' ||
        s == 'MODIFY' ||
        s == 'NEEDS_MODIFICATION' ||
        s == 'NEEDSMODIFICATION';
  }

  bool get _canApprove {
    final s = _status.trim().toUpperCase();
    return widget.isApproverMode && (s == 'SUBMITTED' || s == 'CONFIRMED');
  }

  // ── Lifecycle ───────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadLoggedInUser();
    _registryId = widget.registryId;

    _passNoCtrl.addListener(() {
      setState(() {});
    });

    if (widget.registryId != null) {
      _loadPass(widget.registryId!);
    }
  }

  @override
  void dispose() {
    _vehicleNoCtrl.dispose();
    _brandModelCtrl.dispose();
    _passNoCtrl.dispose();
    _ecNoCtrl.dispose();
    _remarkCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _loadLoggedInUser() {
    _enterBy = 'SYSTEM';
  }

  // ════════════════════════════════════════════════════════════════
  // EMPLOYEE LOOKUP
  // ════════════════════════════════════════════════════════════════
  Future _loadEmployee() async {
    setState(() {
      _empFetchError = null;
      _fetchingEmployee = true;
    });

    final empNo = _ecNoCtrl.text.trim().toUpperCase();
    if (empNo.isEmpty) {
      setState(() => _fetchingEmployee = false);
      return;
    }

    try {
      final res = await http
          .get(
            Uri.parse('$_employeeReportUrl/$empNo'),
            headers: {'x-api-key': _apiKey},
          )
          .timeout(const Duration(milliseconds: 12000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map;

        final apiType = (data['empType'] ?? '').toString().trim().toUpperCase();
        if (apiType != _empType.trim().toUpperCase()) {
          setState(() {
            _empFetchError =
                'Employee Type mismatch. Selected: $_empType, Found: $apiType';
            _fetchingEmployee = false;
          });
          _clearEmployeeData();
          return;
        }

        setState(() {
          _empName = (data['name'] ?? '').toString();
          _empDept = (data['deptName'] ?? '').toString().toUpperCase();
          _empDeptCode = (data['deptCode'] ?? '').toString();
          _empAadhar = (data['aadhaarNo'] ?? data['aadharNo'] ?? '').toString();
          _empContractorCode = (data['contractorCode'] ?? '').toString();
          _empContractorName = (data['contractorName'] ?? '').toString();
          _fetchingEmployee = false;
        });
      } else {
        setState(() {
          _empFetchError =
              'Could not fetch employee details (${res.statusCode})';
          _fetchingEmployee = false;
        });
        _clearEmployeeData();
      }
    } catch (e) {
      setState(() {
        _empFetchError = 'Could not fetch employee details (Network Error)';
        _fetchingEmployee = false;
      });
      _clearEmployeeData();
    }
  }

  void _clearEmployeeData() {
    setState(() {
      _empName = '';
      _empDept = '';
      _empDeptCode = '';
      _empAadhar = '';
      _empContractorCode = '';
      _empContractorName = '';
    });
  }

  // ════════════════════════════════════════════════════════════════
  // PASS LOAD
  // ════════════════════════════════════════════════════════════════
  Future _loadPass(int id) async {
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final res = await http
          .get(Uri.parse('$_passListUrl/$id'), headers: {'x-api-key': _apiKey})
          .timeout(const Duration(milliseconds: 12000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map;

        setState(() {
          _vehicleNoCtrl.text = (data['vehicleNo'] ?? '').toString();
          _vehicleType = (data['vehicleType'] ?? '').toString();
          _brandModelCtrl.text = (data['brandModel'] ?? '').toString();
          _passNoCtrl.text = (data['passNo'] ?? '')
              .toString(); // Set pass number to controller
          _ecNoCtrl.text = (data['employeeNo'] ?? '').toString();
          _empType = (data['empType'] ?? '').toString();
          _gateNo = (data['gateNo'] ?? '').toString();
          _parkingToBeUsed = (data['parkingToBeUsed'] ?? '').toString();
          _status = (data['reqStatus'] ?? 'DRAFT').toString();
          _passNo = data['passNo'] as int?;
          // ---------------------------------------------------------
          // NEW FIX: Bulletproof parser with Web-UI Fallbacks
          // ---------------------------------------------------------
          String parsedEnterBy = '';
          data.forEach((key, value) {
            if (value != null) {
              final normalizedKey = key.toString().toLowerCase().replaceAll(
                '_',
                '',
              );

              if (normalizedKey == 'enterby' ||
                  normalizedKey == 'enteredby' ||
                  normalizedKey == 'createdby' ||
                  normalizedKey == 'creator') {
                final valStr = value.toString().trim();
                if (valStr.toLowerCase() != 'null' && valStr.isNotEmpty) {
                  parsedEnterBy = valStr;
                }
              }
            }
          });

          // If the backend genuinely returns empty/null for this record,
          // fallback to the Employee's Code or 'SYSTEM' to prevent the '-' issue.
          if (parsedEnterBy.isEmpty) {
            final fallback = data['employeeNo'] ?? 'SYSTEM';
            parsedEnterBy = fallback.toString().trim();
          }

          _enterBy = parsedEnterBy;
          // ---------------------------------------------------------
          // ---------------------------------------------------------
          // ---------------------------------------------------------

          final docsJson = data['documents'] as List?;
          if (docsJson != null && docsJson.isNotEmpty) {
            _documents.clear();
            _documents.addAll(
              docsJson.map(
                (d) => PassDocumentModel(
                  documentId: d['documentId'] as int?,
                  documentType: (d['documentType'] ?? '').toString(),
                  documentNo: (d['documentNo'] ?? '').toString(),
                  expiryDate: (d['expiryDate'] ?? '').toString(),
                  fileKey: (d['fileKey'] ?? '').toString(),
                  fileName: (d['fileName'] ?? '').toString(),
                  filePath: null,
                ),
              ),
            );
          }

          _isSaving = false;
          _saveSuccess = 'Pass details loaded successfully.';
        });

        if (_ecNoCtrl.text.isNotEmpty) {
          _loadEmployee();
        }
      } else {
        setState(() {
          _saveError = 'Unable to load pass details.';
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _saveError = 'Unable to load pass details.';
        _isSaving = false;
      });
    }
  }

  // ════════════════════════════════════════════════════════════════
  // PASS HISTORY
  // ════════════════════════════════════════════════════════════════

  void _toggleHistory() {
    setState(() {
      _showHistory = !_showHistory;
    });
    if (_showHistory && _registryId != null && _history.isEmpty) {
      _loadHistory(_registryId!);
    }
  }

  Future<void> _loadHistory(int passId) async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      final res = await http
          .get(
            Uri.parse('$_passHistoryUrl/$passId'),
            headers: {'x-api-key': _apiKey},
          )
          .timeout(const Duration(milliseconds: 12000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        final historyList = data
            .map((e) => PassHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _history = historyList;
          _loadingHistory = false;
        });
      } else {
        setState(() {
          _historyError = 'Unable to load pass history.';
          _loadingHistory = false;
        });
      }
    } catch (_) {
      setState(() {
        _historyError = 'Unable to load pass history.';
        _loadingHistory = false;
      });
    }
  }

  // ════════════════════════════════════════════════════════════════
  // VALIDATION
  // ════════════════════════════════════════════════════════════════
  bool _validateVehicle() {
    if (_vehicleNoCtrl.text.trim().isEmpty) {
      _saveError = 'Vehicle Number is required.';
      return false;
    }
    if (_vehicleType.trim().isEmpty) {
      _saveError = 'Vehicle Type is required.';
      return false;
    }
    if (_brandModelCtrl.text.trim().isEmpty) {
      _saveError = 'Brand / Model is required.';
      return false;
    }
    return true;
  }

  bool _validateEmployee() {
    if (_empType.trim().isEmpty) {
      _saveError = 'Please select Employee Type.';
      return false;
    }
    if (_ecNoCtrl.text.trim().isEmpty) {
      _saveError = 'Employee Code is required.';
      return false;
    }
    if (_empName.trim().isEmpty) {
      _saveError = 'Please verify Employee Code.';
      return false;
    }
    return true;
  }

  bool _validateGateAndParking() {
    if (_gateNo.trim().isEmpty) {
      _saveError = 'Gate No is required.';
      return false;
    }
    if (_parkingToBeUsed.trim().isEmpty) {
      _saveError = 'Parking To Be Used is required.';
      return false;
    }
    return true;
  }

  bool _validateDocuments({bool isSubmit = false}) {
    if (_documents.isEmpty) {
      _saveError = 'Please add at least one document.';
      return false;
    }

    // Enforce ALL 3 documents ONLY on Submit (Save Draft remains unaffected)
    if (isSubmit && _documents.length < _allowedDocTypes.length) {
      _saveError =
          'All 3 documents (${_allowedDocTypes.join(", ")}) are required for submission.';
      return false;
    }

    for (var i = 0; i < _documents.length; i++) {
      final doc = _documents[i];
      if (doc.documentType.trim().isEmpty) {
        _saveError = 'Please select Document Type for Document #${i + 1}.';
        return false;
      }
      if (doc.documentNo.trim().isEmpty) {
        _saveError = 'Please enter Document Number for Document #${i + 1}.';
        return false;
      }
      if (doc.expiryDate.trim().isEmpty) {
        _saveError = 'Please select Expiry Date for Document #${i + 1}.';
        return false;
      }
      final hasFile =
          (doc.filePath != null && doc.filePath!.isNotEmpty) ||
          doc.fileName.trim().isNotEmpty;
      if (!hasFile) {
        _saveError = 'Please upload a file for Document #${i + 1}.';
        return false;
      }
    }
    return true;
  }

  bool _validateForm({bool isSubmit = false}) {
    _saveError = null;
    if (!_validateVehicle()) return false;
    if (!_validateEmployee()) return false;
    if (!_validateGateAndParking()) return false;
    if (!_validateDocuments(isSubmit: isSubmit)) return false;
    return true;
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD REQUEST
  // ════════════════════════════════════════════════════════════════
  PassRequestModel _buildRequest({String? statusOverride}) {
    return PassRequestModel(
      id: _registryId,
      passNo: _passNoCtrl.text.trim().isNotEmpty
          ? int.tryParse(_passNoCtrl.text.trim())
          : null,
      vehicleNo: _vehicleNoCtrl.text.trim(),
      vehicleType: _vehicleType.trim(),
      brandModel: _brandModelCtrl.text.trim(),
      employeeNo: _ecNoCtrl.text.trim(),
      empType: _empType.trim(),
      contractorCode: _empContractorCode.trim().isEmpty
          ? null
          : _empContractorCode.trim(),
      gateNo: _gateNo.trim(),
      parkingToBeUsed: _parkingToBeUsed.trim(),
      status: statusOverride ?? _status,
      remark: _remark,
      enterBy: _enterBy,
      documents: _documents,
    );
  }

  // ════════════════════════════════════════════════════════════════
  // SAVE / SUBMIT
  // ════════════════════════════════════════════════════════════════
  Future _savePass({bool submit = false}) async {
    if (!_validateForm(isSubmit: submit)) {
      setState(() {});
      return;
    }

    String statusToUse = _status;
    if (submit) {
      statusToUse = 'SUBMITTED';
      if (_status.toUpperCase() == 'MODIFY' ||
          _status.toUpperCase() == 'NEEDS_MODIFICATION' ||
          _status.toUpperCase() == 'NEEDSMODIFICATION') {
        statusToUse = 'DRAFT';
      }
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
      _saveSuccess = null;
    });

    final request = _buildRequest(statusOverride: statusToUse);
    final jsonPart = jsonEncode(request.toJson());

    Future<http.Response> sendMultipart() async {
      if (_registryId != null) {
        final formData = http.MultipartRequest(
          'PUT',
          Uri.parse('$_passUpdateUrl/$_registryId'),
        );
        formData.headers['x-api-key'] = _apiKey;

        formData.files.add(
          http.MultipartFile.fromString(
            'request',
            jsonPart,
            filename: 'request.json',
            contentType: MediaType('application', 'json'),
          ),
        );

        for (var i = 0; i < _documents.length; i++) {
          final doc = _documents[i];
          if (doc.filePath != null && doc.filePath!.isNotEmpty) {
            final file = File(doc.filePath!);
            if (await file.exists()) {
              formData.files.add(
                await http.MultipartFile.fromPath(
                  doc.fileKey.isNotEmpty ? doc.fileKey : 'document_$i',
                  file.path,
                ),
              );
            }
          }
        }

        final streamed = await formData.send();
        return http.Response.fromStream(streamed);
      }

      final formData = http.MultipartRequest('POST', Uri.parse(_passSaveUrl));
      formData.headers['x-api-key'] = _apiKey;

      formData.files.add(
        http.MultipartFile.fromString(
          'request',
          jsonPart,
          filename: 'request.json',
          contentType: MediaType('application', 'json'),
        ),
      );

      for (var i = 0; i < _documents.length; i++) {
        final doc = _documents[i];
        if (doc.filePath != null && doc.filePath!.isNotEmpty) {
          final file = File(doc.filePath!);
          if (await file.exists()) {
            formData.files.add(
              await http.MultipartFile.fromPath(
                doc.fileKey.isNotEmpty ? doc.fileKey : 'document_$i',
                file.path,
              ),
            );
          }
        }
      }

      final streamed = await formData.send();
      return http.Response.fromStream(streamed);
    }

    try {
      final response = await sendMultipart();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map;
        setState(() {
          _registryId ??= data['id'] as int?;
          _passNo = data['passNo'] as int?;
          if (_passNo != null) {
            _passNoCtrl.text = _passNo.toString();
          }
          _status = (data['reqStatus'] ?? (submit ? 'SUBMITTED' : 'DRAFT'))
              .toString();
          _saveSuccess = submit
              ? 'Pass submitted successfully.'
              : (_registryId != null
                    ? 'Vehicle pass updated successfully.'
                    : 'Vehicle pass saved successfully.');
          _isSaving = false;
        });
        _scrollToBottom();
      } else if (response.statusCode == 409) {
        setState(() {
          _saveError =
              'Duplicate pass not allowed (Pass No + Employee Type must be unique).';
          _isSaving = false;
        });
        _scrollToBottom();
      } else {
        setState(() {
          _saveError =
              'Unable to save vehicle pass. HTTP ${response.statusCode}';
          _isSaving = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _saveError = 'Unable to save vehicle pass.';
        _isSaving = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ════════════════════════════════════════════════════════════════
  // WORKFLOW STATUS UPDATE (APPROVER)
  // ════════════════════════════════════════════════════════════════
  Future<void> _updatePassStatus({required String newStatus}) async {
    if (_registryId == null) {
      setState(() => _workflowError = 'No pass loaded.');
      return;
    }

    if (_remarkCtrl.text.trim().isEmpty) {
      setState(() => _workflowError = 'Remark is required.');
      return;
    }

    setState(() {
      _isWorkflowSubmitting = true;
      _workflowError = null;
      _workflowSuccess = null;
    });

    final payload = {
      'status': newStatus,
      'remark': _remarkCtrl.text.trim(),
      'enterBy': _enterBy.isNotEmpty ? _enterBy : 'SYSTEM',
    };

    try {
      final res = await http
          .put(
            Uri.parse('$_passStatusUpdateUrl/$_registryId'),
            headers: {'x-api-key': _apiKey, 'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(milliseconds: 12000));

      if (res.statusCode == 200) {
        setState(() {
          _status = newStatus;
          _workflowSuccess = '$newStatus completed successfully.';
          _isWorkflowSubmitting = false;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(() {
          _workflowError = 'Status update failed: HTTP ${res.statusCode}';
          _isWorkflowSubmitting = false;
        });
      }
    } catch (_) {
      setState(() {
        _workflowError = 'Status update failed: Network error';
        _isWorkflowSubmitting = false;
      });
    }
  }

  Future<void> _approvePass() => _updatePassStatus(newStatus: 'ACTIVE');
  Future<void> _rejectPass() => _updatePassStatus(newStatus: 'REJECT');
  Future<void> _sendForModify() =>
      _updatePassStatus(newStatus: 'NEEDS_MODIFICATION');

  // ════════════════════════════════════════════════════════════════
  // DOCUMENT HELPERS
  // ════════════════════════════════════════════════════════════════
  List<String> _availableDocTypes(int index) {
    final selectedTypes = _documents
        .asMap()
        .entries
        .where((e) => e.key != index && e.value.documentType.isNotEmpty)
        .map((e) => e.value.documentType)
        .toList();

    return _allowedDocTypes
        .where(
          (t) =>
              !selectedTypes.contains(t) || _documents[index].documentType == t,
        )
        .toList();
  }

  void _addDocument() {
    if (_isReadOnly) return;
    final lastDoc = _documents.last;
    if (lastDoc.documentType.isEmpty ||
        lastDoc.documentNo.isEmpty ||
        lastDoc.expiryDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete the current document before adding a new one.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _documents.add(
        PassDocumentModel(
          documentId: null,
          documentType: '',
          documentNo: '',
          expiryDate: '',
          fileKey: 'document_${_documents.length}',
          fileName: '',
          filePath: null,
        ),
      );
    });
  }

  void _removeDocument(int index) {
    if (_isReadOnly || _documents.length == 1) return;
    setState(() {
      _documents.removeAt(index);
    });
  }

  Future _pickFileForDoc(int index) async {
    if (_isReadOnly) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.size > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File size must be less than 5 MB.')),
      );
      return;
    }

    setState(() {
      _documents[index] = PassDocumentModel(
        documentId: _documents[index].documentId,
        documentType: _documents[index].documentType,
        documentNo: _documents[index].documentNo,
        expiryDate: _documents[index].expiryDate,
        fileKey: _documents[index].fileKey,
        fileName: file.name,
        filePath: file.path,
      );
    });
  }

  // ════════════════════════════════════════════════════════════════
  // CLEAR FORM
  // ════════════════════════════════════════════════════════════════
  void _clearForm() {
    setState(() {
      _vehicleNoCtrl.clear();
      _vehicleType = '';
      _brandModelCtrl.clear();
      _passNoCtrl.clear();
      _ecNoCtrl.clear();
      _empType = '';
      _clearEmployeeData();
      _empFetchError = null;
      _gateNo = '';
      _parkingToBeUsed = '';
      _status = 'DRAFT';
      _passNo = null;
      _remark = null;
      _documents.clear();
      _documents.add(
        PassDocumentModel(
          documentId: null,
          documentType: '',
          documentNo: '',
          expiryDate: '',
          fileKey: 'document_0',
          fileName: '',
          filePath: null,
        ),
      );
      _saveSuccess = null;
      _saveError = null;
    });
  }

  // ════════════════════════════════════════════════════════════════
  // UI BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _buildVehicleSection(),
        _buildEmployeeSection(),
        _buildPassDetailsSection(),
        _buildStatusSection(),
        _buildDocumentsSection(),
        _buildRemarkSection(),
        _buildActionButtons(),
        if (_registryId != null) ...[
          const SizedBox(height: 12),
          _buildHistorySection(),
        ],
        if (_isReadOnly && !widget.isApproverMode) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PassActionButton(
              label: 'Back',
              icon: Icons.arrow_back,
              backgroundColor: const Color(0xFFF1F5F9),
              foregroundColor: const Color(0xFF475569),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
        if (_workflowSuccess != null) ...[
          const SizedBox(height: 8),
          _buildAlert(success: true, message: _workflowSuccess!),
        ],
        if (_workflowError != null) ...[
          const SizedBox(height: 8),
          _buildAlert(success: false, message: _workflowError!),
        ],
        if (_saveSuccess != null) ...[
          const SizedBox(height: 8),
          _buildAlert(success: true, message: _saveSuccess!),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: 8),
          _buildAlert(success: false, message: _saveError!),
        ],
      ],
    );
  }

  // ── VEHICLE ─────────────────────────────────────────────────────
  Widget _buildVehicleSection() {
    return PassSection(
      icon: Icons.directions_car,
      title: 'Vehicle Details',
      children: [
        PassField(
          label: 'Vehicle Number',
          hintText: 'MP09AB1234',
          controller: _vehicleNoCtrl,
          readOnly: _isReadOnly,
          onSubmitted: (_) {},
          textTransform: TextTransform.uppercase,
          width: double.infinity,
        ),
        const SizedBox(height: 10),
        PassDropdown(
          label: 'Vehicle Type',
          value: _vehicleType.isEmpty ? null : _vehicleType,
          // NEW: Dynamically add backend value if missing
          items:
              _vehicleType.isNotEmpty && !_vehicleTypes.contains(_vehicleType)
              ? [..._vehicleTypes, _vehicleType]
              : _vehicleTypes,
          hint: '-- Select Vehicle Type --',
          onChanged: _isReadOnly
              ? null
              : (v) => setState(() => _vehicleType = v ?? ''),
          width: double.infinity,
        ),
        const SizedBox(height: 10),
        PassField(
          label: 'Brand / Model',
          hintText: 'Honda City / Tata Truck',
          controller: _brandModelCtrl,
          readOnly: _isReadOnly,
          onSubmitted: (_) {},
          textTransform: TextTransform.uppercase,
          width: double.infinity,
        ),
        const SizedBox(height: 10),
        PassField(
          label: 'Pass No',
          hintText: 'Enter Pass No',
          controller: _passNoCtrl,
          readOnly: _isReadOnly,
          onSubmitted: (_) {},
          textTransform: TextTransform.none,
          width: double.infinity,
        ),
      ],
    );
  }

  // ── EMPLOYEE ────────────────────────────────────────────────────
  Widget _buildEmployeeSection() {
    return PassSection(
      icon: Icons.badge,
      title: 'Employee / Contractor Details',
      children: [
        PassDropdown(
          label: 'Employee Type',
          value: _empType.isEmpty ? null : _empType,
          // NEW: Dynamically add backend value if missing
          items: _empType.isNotEmpty && !_empTypes.contains(_empType)
              ? [..._empTypes, _empType]
              : _empTypes,
          hint: '-- Select Employee Type --',
          onChanged: _isReadOnly
              ? null
              : (v) {
                  setState(() {
                    _empType = v ?? '';
                    _clearEmployeeData();
                    _ecNoCtrl.clear();
                    _empFetchError = null;
                  });
                },
          width: double.infinity,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: PassField(
                label: 'EC No',
                hintText: 'Enter Employee Code',
                controller: _ecNoCtrl,
                readOnly: _isReadOnly,
                onSubmitted: (_) => _loadEmployee(),
                hintTextExtra: _empType.isEmpty
                    ? 'Select Employee Type First'
                    : 'Press Search or Enter',
                width: double.infinity,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _isReadOnly || _empType.isEmpty
                          ? null
                          : _loadEmployee,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _fetchingEmployee
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.search, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildEmployeeSummaryCard(),
        if (_empFetchError != null) ...[
          const SizedBox(height: 8),
          _buildMessageBanner(message: _empFetchError!, isError: true),
        ],
        if (_empName.isNotEmpty &&
            !_fetchingEmployee &&
            _empFetchError == null) ...[
          const SizedBox(height: 8),
          _buildMessageBanner(
            message: 'Employee Found: $_empName $_empDept',
            isError: false,
          ),
        ],
      ],
    );
  }

  Widget _buildEmployeeSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('Employee', _empName.isEmpty ? '—' : _empName),
          const SizedBox(height: 8),
          _summaryRow('Department', _empDept.isEmpty ? '—' : _empDept),
          const SizedBox(height: 8),
          _summaryRow(
            'Contractor',
            _empContractorName.isEmpty ? '—' : _empContractorName,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF627D98),
            ),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(fontSize: 11, color: Color(0xFF627D98)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF102A43),
            ),
          ),
        ),
      ],
    );
  }

  // ── PASS DETAILS ────────────────────────────────────────────────
  Widget _buildPassDetailsSection() {
    return PassSection(
      icon: Icons.card_membership,
      title: 'Pass Details',
      children: [
        PassDropdown(
          label: 'Gate No',
          value: _gateNo.isEmpty ? null : _gateNo,
          // NEW: Prevent crash for custom Gate names
          items: _gateNo.isNotEmpty && !_gates.contains(_gateNo)
              ? [..._gates, _gateNo]
              : _gates,
          hint: '-- Select Gate --',
          onChanged: _isReadOnly
              ? null
              : (v) => setState(() => _gateNo = v ?? ''),
          width: double.infinity,
        ),
        const SizedBox(height: 10),
        PassDropdown(
          label: 'Parking Area',
          value: _parkingToBeUsed.isEmpty ? null : _parkingToBeUsed,
          // NEW: Prevent crash for custom parking like "BhujariyaParking"
          items:
              _parkingToBeUsed.isNotEmpty &&
                  !_parkings.contains(_parkingToBeUsed)
              ? [..._parkings, _parkingToBeUsed]
              : _parkings,
          hint: '-- Select Parking Area --',
          onChanged: _isReadOnly
              ? null
              : (v) => setState(() => _parkingToBeUsed = v ?? ''),
          width: double.infinity,
        ),
      ],
    );
  }

  // ── STATUS ────────────────────────────────────────────────
  Widget _buildStatusSection() {
    return PassSection(
      icon: Icons.schema,
      title: 'Workflow Status',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF93C5FD)),
          ),
          child: Column(
            children: [
              _statusRow('Current Status', _status),
              const SizedBox(height: 6),
              _statusRow('Entered By', _enterBy.isEmpty ? '-' : _enterBy),
              const SizedBox(height: 6),
              _statusRow(
                'Pass No',
                _passNoCtrl.text.trim().isEmpty ? '-' : _passNoCtrl.text.trim(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E3A6E),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2040),
            ),
          ),
        ),
      ],
    );
  }

  // ── DOCUMENTS ───────────────────────────────────────────────────
  Widget _buildDocumentsSection() {
    return PassSection(
      icon: Icons.file_present,
      title: 'Required Documents',
      badge: '${_documents.length} Added',
      children: [
        ...List.generate(_documents.length, (i) => _buildDocCard(i)),
        const SizedBox(height: 6),
        _buildAddDocButton(),
        const SizedBox(height: 10),
        _buildDocInfo(),
      ],
    );
  }

  Widget _buildDocCard(int index) {
    final doc = _documents[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Document #${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F2040),
                ),
              ),
              if (!_isReadOnly && _documents.length > 1)
                InkWell(
                  onTap: () => _removeDocument(index),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Color(0xFFEF4444),
                        ),
                        SizedBox(width: 2),
                        Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 16, thickness: 1, color: Color(0xFFE2E8F0)),

          // Field Group 1: Doc Type & Expiry
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Doc Type',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A6E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    PassDropdownSmall(
                      value: doc.documentType.isEmpty ? null : doc.documentType,
                      items: _availableDocTypes(index),
                      hint: 'Select Type',
                      onChanged: _isReadOnly
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() {
                                _documents[index] = PassDocumentModel(
                                  documentId: doc.documentId,
                                  documentType: v,
                                  documentNo: doc.documentNo,
                                  expiryDate: doc.expiryDate,
                                  fileKey: doc.fileKey,
                                  fileName: doc.fileName,
                                  filePath: doc.filePath,
                                );
                              });
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expiry Date',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A6E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    PassDateFieldSmall(
                      value: doc.expiryDate.isEmpty ? null : doc.expiryDate,
                      enabled: !_isReadOnly,
                      onDateSelected: (d) => setState(() {
                        _documents[index].expiryDate = d;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Field Group 2: Doc Number & File Upload
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Doc Number',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A6E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    PassFieldSmall(
                      hintText: 'Enter Doc No',
                      initialValue: doc.documentNo,
                      readOnly: _isReadOnly,
                      onChanged: (v) => setState(() {
                        _documents[index].documentNo = v;
                      }),
                      textTransform: TextTransform.uppercase,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attachment',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A6E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildDocFileCell(index),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocFileCell(int index) {
    final doc = _documents[index];
    final hasFile =
        (doc.filePath != null && doc.filePath!.isNotEmpty) ||
        doc.fileName.isNotEmpty;

    if (hasFile) {
      // Return Container directly (No GestureDetector wrapper)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          border: Border.all(color: const Color(0xFF86EFAC)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 13, color: Color(0xFF15803D)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                doc.fileName.isEmpty ? 'Uploaded' : doc.fileName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF15803D),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Upload button remains clickable when no file is present
    return GestureDetector(
      onTap: _isReadOnly ? null : () => _pickFileForDoc(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFDBEAFF),
          border: Border.all(color: const Color(0xFF93C5FD)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload, size: 13, color: Color(0xFF1D4ED8)),
            SizedBox(width: 4),
            Text(
              'Upload',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddDocButton() {
    final canAdd = !_isReadOnly && _documents.length < _allowedDocTypes.length;
    return GestureDetector(
      onTap: canAdd ? _addDocument : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: canAdd ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          border: Border.all(
            color: canAdd ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle,
              size: 16,
              color: canAdd ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              'Add Document',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: canAdd
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocInfo() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        border: Border.all(color: const Color(0xFFDDE4EF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.info, size: 14, color: Color(0xFF94A3B8)),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Allowed: RC, INSURANCE, LICENSE (max 3)',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── REMARK SECTION (Approver) ───────────────────────────────────
  Widget _buildRemarkSection() {
    if (!widget.isApproverMode) {
      return const SizedBox.shrink();
    }
    return PassSection(
      icon: Icons.chat_bubble_outline,
      title: 'Approver Remark',
      children: [
        PassField(
          label: 'Remark',
          hintText: 'Enter remark',
          controller: _remarkCtrl,
          readOnly: _isWorkflowSubmitting,
          maxLines: 4,
          width: double.infinity,
        ),
        const SizedBox(height: 4),
        const Text(
          'Remark required for workflow action',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF627D98),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── ACTION BUTTONS ──────────────────────────────────────────────
  Widget _buildActionButtons() {
    final canEdit = _canEdit;
    final canApprove = _canApprove;

    return Column(
      children: [
        // Entry user buttons
        if (canEdit) ...[
          Row(
            children: [
              Expanded(
                child: PassActionButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  icon: _isSaving ? Icons.hourglass_bottom : Icons.save,
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  onPressed: _isSaving ? null : () => _savePass(submit: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PassActionButton(
                  label: 'Submit',
                  icon: Icons.send,
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  onPressed: _isSaving ? null : () => _savePass(submit: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: PassActionButton(
              label: 'Clear Form',
              icon: Icons.refresh,
              backgroundColor: const Color(0xFFF1F5F9),
              foregroundColor: const Color(0xFF475569),
              onPressed: _clearForm,
            ),
          ),
        ],

        // Approver actions
        if (canApprove) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PassActionButton(
                  label: _isWorkflowSubmitting
                      ? 'Processing...'
                      : 'Send Modification',
                  icon: Icons.edit,
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  onPressed: _isWorkflowSubmitting ? null : _sendForModify,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PassActionButton(
                  label: _isWorkflowSubmitting ? 'Processing...' : 'Reject',
                  icon: Icons.close,
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  onPressed: _isWorkflowSubmitting ? null : _rejectPass,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: PassActionButton(
              label: _isWorkflowSubmitting
                  ? 'Processing...'
                  : 'Approve & Activate',
              icon: Icons.check_circle,
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              onPressed: _isWorkflowSubmitting ? null : _approvePass,
            ),
          ),
        ],
      ],
    );
  }

  // ── HISTORY SECTION ─────────────────────────────────────────────
  Widget _buildHistorySection() {
    if (_registryId == null) return const SizedBox.shrink();

    return PassSection(
      icon: Icons.history,
      title: 'Pass History',
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _toggleHistory,
            icon: const Icon(Icons.history),
            label: Text(_showHistory ? 'Hide History' : 'Show History'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF1D4ED8),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (_showHistory) ...[
          const SizedBox(height: 12),
          if (_loadingHistory)
            _buildHistoryLoading()
          else if (_historyError != null)
            _buildHistoryError()
          else if (_history.isEmpty)
            _buildHistoryEmpty()
          else
            _buildHistoryList(),
        ],
      ],
    );
  }

  Widget _buildHistoryLoading() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9E2EC)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            'Loading history...',
            style: TextStyle(
              color: Color(0xFF102A43),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFF7F1D1D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _historyError ?? 'Unable to load pass history.',
              style: const TextStyle(
                color: Color(0xFF7F1D1D),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmpty() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9E2EC)),
      ),
      child: const Center(
        child: Text(
          'No history available',
          style: TextStyle(
            color: Color(0xFF627D98),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(children: _history.map(_buildHistoryRow).toList());
  }

  Widget _buildHistoryRow(PassHistoryItem h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9E2EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  h.action.isEmpty ? '-' : h.action,
                  style: const TextStyle(
                    color: Color(0xFF102A43),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatHistoryDateTime(h.dateOfEntry),
                style: const TextStyle(
                  color: Color(0xFF627D98),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'By ${h.empCode.isEmpty ? 'SYSTEM' : h.empCode}',
            style: const TextStyle(
              color: Color(0xFF627D98),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (h.remark.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              h.remark,
              style: const TextStyle(
                color: Color(0xFF102A43),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatHistoryDateTime(String isoDate) {
    if (isoDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoDate);
      final d =
          '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
      return d;
    } catch (_) {
      return isoDate;
    }
  }

  // ── MESSAGE BANNERS ─────────────────────────────────────────────
  Widget _buildMessageBanner({required String message, required bool isError}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        border: Border.all(
          color: isError ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error : Icons.check_circle,
            size: 16,
            color: isError ? const Color(0xFF7F1D1D) : const Color(0xFF14532D),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isError
                    ? const Color(0xFF7F1D1D)
                    : const Color(0xFF14532D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlert({required bool success, required String message}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        border: Border.all(
          color: success ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            size: 20,
            color: success ? const Color(0xFF14532D) : const Color(0xFF7F1D1D),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: success
                    ? const Color(0xFF14532D)
                    : const Color(0xFF7F1D1D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
