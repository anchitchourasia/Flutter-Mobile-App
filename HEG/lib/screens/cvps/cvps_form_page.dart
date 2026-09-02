import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/cvps_api.dart';
import '../../widgets/heg_app_bar.dart';
import 'driver_details_sheet.dart';

/// Local model for a vehicle document row (view only).
/// Mirrors DocEntry in vehicle-permission-form.ts, but simplified.
class _DocEntry {
  final String docType;
  final String docNo;
  final String validUpto;
  final String? existingFile;

  _DocEntry({
    required this.docType,
    required this.docNo,
    required this.validUpto,
    required this.existingFile,
  });
}

/// Local model for a driver/person row (view only).
/// Mirrors the DriverPerson data that matters in view mode.
class _DriverPerson {
  final String role;
  final String empNo;
  final String name;
  final String eyeTestDate;
  final String? eyeTestFileName;

  // New: used only by the read-only View More sheet.
  final String mobileNo;
  final String aadhaarNo;
  final String licenseNo;
  final String licenseType;
  final String licenseFrom;
  final String licenseTo;
  final String aadhaarFileName;
  final String photoFileName;
  final String licenseFileName;

  _DriverPerson({
    required this.role,
    required this.empNo,
    required this.name,
    required this.eyeTestDate,
    required this.eyeTestFileName,
    this.mobileNo = '',
    this.aadhaarNo = '',
    this.licenseNo = '',
    this.licenseType = '',
    this.licenseFrom = '',
    this.licenseTo = '',
    this.aadhaarFileName = '',
    this.photoFileName = '',
    this.licenseFileName = '',
  });

  _DriverPerson copyWith({
    String? role,
    String? empNo,
    String? name,
    String? eyeTestDate,
    String? eyeTestFileName,
    String? mobileNo,
    String? aadhaarNo,
    String? licenseNo,
    String? licenseType,
    String? licenseFrom,
    String? licenseTo,
    String? aadhaarFileName,
    String? photoFileName,
    String? licenseFileName,
  }) {
    return _DriverPerson(
      role: role ?? this.role,
      empNo: empNo ?? this.empNo,
      name: name ?? this.name,
      eyeTestDate: eyeTestDate ?? this.eyeTestDate,
      eyeTestFileName: eyeTestFileName ?? this.eyeTestFileName,
      mobileNo: mobileNo ?? this.mobileNo,
      aadhaarNo: aadhaarNo ?? this.aadhaarNo,
      licenseNo: licenseNo ?? this.licenseNo,
      licenseType: licenseType ?? this.licenseType,
      licenseFrom: licenseFrom ?? this.licenseFrom,
      licenseTo: licenseTo ?? this.licenseTo,
      aadhaarFileName: aadhaarFileName ?? this.aadhaarFileName,
      photoFileName: photoFileName ?? this.photoFileName,
      licenseFileName: licenseFileName ?? this.licenseFileName,
    );
  }
}

/// Local model for workflow remark history (view only).
/// Mirrors WorkflowRemarkEntry in TS.
class _WorkflowRemarkEntry {
  final String stage;
  final String action;
  final String remark;
  final String byName;
  final String byEmpCode;
  final String createdAt;

  _WorkflowRemarkEntry({
    required this.stage,
    required this.action,
    required this.remark,
    required this.byName,
    required this.byEmpCode,
    required this.createdAt,
  });
}

/// Mobile CVPS request form screen (View mode).
///
/// Implements same APIs as Angular:
/// - cvps.getRequestById(requestNo)
/// - cvps.fetchContractorDetails(contractorCode)
/// - cvps.getRequestHistory(requestNo)
/// - cvps.downloadDocument(filename)
class CvpsFormPage extends StatefulWidget {
  const CvpsFormPage({super.key});

  @override
  State<CvpsFormPage> createState() => _CvpsFormPageState();
}

class _CvpsFormPageState extends State<CvpsFormPage> {
  final CvpsApi api = CvpsApi();

  bool loading = true;
  bool hasError = false;
  String errorMessage = '';

  int? requestNo;

  // Header fields
  String status = 'Draft';
  final String companyName = 'HEG Limited, Mandideep';
  final String formNo = 'W-OHS-SECURITY-12';

  // General section
  String contractorIdRaw = ''; // raw contractorId from request
  String contractorCode = '';
  String contractorName = '';
  String department = '';
  String departmentCode = '';
  String natureOfJob = '';
  String reqDate = ''; // request / created date
  String permissionDateTo = '';
  String createdBy = '';
  String createdDate = '';

  // Vehicle section
  String vehicleNumber = '';
  String vehicleType = '';

  // Documents section
  List<_DocEntry> docs = [];

  // Drivers section
  List<_DriverPerson> drivers = [];

  // Workflow section
  List<_WorkflowRemarkEntry> remarksHistory = [];
  bool showWorkflowHistory = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Read the requestNo from named-route arguments once.
    final args = ModalRoute.of(context)?.settings.arguments;
    if (requestNo == null) {
      if (args is int && args > 0) {
        requestNo = args;
        _loadRequest(args);
      } else {
        setState(() {
          loading = false;
          hasError = true;
          errorMessage = 'Invalid request number.';
        });
      }
    }
  }

  void _openDriverDetails(_DriverPerson driver) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DriverDetailsSheet(
          api: api,
          driver: DriverDetailsData(
            empNo: driver.empNo,
            name: driver.name,
            mobileNo: driver.mobileNo,
            aadhaarNo: driver.aadhaarNo,
            licenseNo: driver.licenseNo,
            licenseFrom: driver.licenseFrom,
            licenseTo: driver.licenseTo,
            aadhaarFileName: driver.aadhaarFileName,
            photoFileName: driver.photoFileName,
            licenseFileName: driver.licenseFileName,
          ),
        );
      },
    );
  }

  Future<void> _saveAndOpenFile(
    Uint8List bytes,
    String fileName,
    String label,
  ) async {
    final name = fileName.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No $label file available.')));
      return;
    }

    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${documentsDir.path}/downloads');

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final file = File('${downloadsDir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;

      final result = await OpenFilex.open(
        file.path,
        type: api.guessMimeType(name),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.type == ResultType.done
                ? 'Downloaded and opened: $name'
                : 'Saved to: ${file.path}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save $label: $e')));
    }
  }

  /// Downloads an Eye Test file for a driver.
  Future<void> _downloadEyeTest(_DriverPerson driver) async {
    final fileName = driver.eyeTestFileName?.trim() ?? '';

    if (fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eye test file available.')),
      );
      return;
    }

    try {
      final bytes = await api.downloadDocumentBytes(fileName);

      if (!mounted) return;

      await _saveAndOpenFile(bytes, fileName, 'eye test');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download $fileName: $e')),
      );
    }
  }

  /// Downloads a vehicle document and shows a message.
  /// Mirrors clicking a link in web UI.
  Future<void> _downloadDoc(_DocEntry document) async {
    final fileName = document.existingFile?.trim() ?? '';

    if (fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file available to download.')),
      );
      return;
    }

    try {
      final bytes = await api.downloadDocumentBytes(fileName);

      if (!mounted) return;

      await _saveAndOpenFile(bytes, fileName, document.docType);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download $fileName: $e')),
      );
    }
  }

  /// Main loader: mirrors Angular ngOnInit + loadRequest + resolveContractorName + loadRemarkHistory.
  Future<void> _loadRequest(int no) async {
    setState(() {
      loading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      // 1) Main DTO: cvps.getRequestById(requestNo)
      final result = await api.fetchRequestById(no);
      _fillFromDto(result);

      await _resolveDepartmentName();
      await _resolveMissingDriverNames();

      // 2) Contractor BP details: cvps.fetchContractorDetails(contractorCode)
      if (contractorIdRaw.isNotEmpty) {
        try {
          final bp = await api.fetchContractorDetails(contractorIdRaw);
          if (bp != null) {
            final bpCode = _safeString(bp['contractorCode']);
            final bpName = _safeString(bp['contractorName']);
            contractorCode = bpCode.isNotEmpty ? bpCode : contractorCode;
            contractorName = bpName;
          }
        } catch (_) {
          // Ignore BP failures in view mode.
        }
      }

      // 3) Workflow history: cvps.getRequestHistory(requestNo)
      try {
        final history = await api.fetchRequestHistory(no);
        remarksHistory = history.map((raw) {
          final m = raw;
          return _WorkflowRemarkEntry(
            stage: _safeString(m['stage']),
            action: _safeString(m['actionTaken']),
            remark: _safeString(m['remarks']),
            byName: _safeString(m['empNo']),
            byEmpCode: _safeString(m['empNo']),
            createdAt: _formatDateTime(m['actionDate']),
          );
        }).toList();

        // Sort by createdAt ascending (same as TS).
        remarksHistory.sort((a, b) {
          final ta =
              DateTime.tryParse(a.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final tb =
              DateTime.tryParse(b.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return ta.compareTo(tb);
        });
      } catch (_) {
        remarksHistory = [];
      }

      setState(() {
        loading = false;
      });
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = e.toString();
        loading = false;
      });
    }
  }

  /// Extracts all important fields from the CreateRequestDTO.
  /// Mirrors core of fillForm(dto) in vehicle-permission-form.ts.
  void _fillFromDto(Map<String, dynamic> data) {
    final req = data['request'] as Map<String, dynamic>? ?? {};
    final vehicleDocs = data['vehicleDocuments'] as List<dynamic>? ?? const [];
    final employees = data['employees'] as List<dynamic>? ?? const [];

    // Status (raw backend status).
    final rawStatus = (req['reqStatus'] ?? '').toString().trim();
    status = rawStatus.isEmpty ? 'Draft' : rawStatus;

    // General section
    contractorIdRaw = _safeString(req['contractorId']).toUpperCase();
    contractorCode = contractorIdRaw; // before BP lookup
    contractorName = ''; // will be filled via BP API
    departmentCode = _safeString(
      req['deptCode'] ?? req['departmentCode'] ?? req['department'],
    );

    department = departmentCode;
    natureOfJob = _safeString(req['natureOfJob']);
    reqDate = _formatDate(req['createdDate']);
    permissionDateTo = _formatDate(req['permissionTo']);
    createdBy = _safeString(req['createdBy']);
    createdDate = _formatDate(req['createdDate']);

    // Vehicle section
    vehicleNumber = _safeString(req['vehicleNo']).toUpperCase();
    vehicleType = _safeString(req['vehicleType']);

    // Documents section – use same filename logic as TS getExistingFileName.
    docs = vehicleDocs.map((raw) {
      final m = raw as Map<String, dynamic>? ?? {};
      final docType = _safeString(m['documentType']).trim();
      final docNo = _safeString(m['documentNo']).trim();
      final validTill = _formatDate(m['validTill']);
      final fileName = _extractExistingFileName(m);
      return _DocEntry(
        docType: docType,
        docNo: docNo,
        validUpto: validTill,
        existingFile: fileName.isEmpty ? null : fileName,
      );
    }).toList();

    // Drivers section – simplified Eye Test mapping.
    drivers = employees.map((rawEmp) {
      final emp = rawEmp as Map<String, dynamic>? ?? {};
      final docsList = emp['documents'] as List<dynamic>? ?? const [];

      // Find Eye Test document.
      Map<String, dynamic>? eyeDoc;
      for (final d in docsList) {
        final dm = d as Map<String, dynamic>? ?? {};
        final t = _safeString(
          dm['documentType'],
        ).toUpperCase().replaceAll(' ', '');
        if (t == 'EYETEST' || t == 'EYE_TEST' || t == 'EYETESTDOC') {
          eyeDoc = dm;
          break;
        }
      }

      final eyeFileRaw =
          emp['eyeTestFile'] ??
          emp['eyeTestFileName'] ??
          emp['eyeTestDocument'] ??
          eyeDoc?['filename'] ??
          eyeDoc?['fileName'] ??
          eyeDoc?['documentName'] ??
          eyeDoc?['documentPath'];
      final eyeDateRaw =
          emp['eyeTestDate'] ?? emp['eyetestdate'] ?? eyeDoc?['validTill'];

      final eyeFileName = eyeFileRaw == null
          ? null
          : _stripPath(eyeFileRaw.toString());

      Map<String, dynamic>? aadhaarDoc;
      Map<String, dynamic>? licenseDoc;
      Map<String, dynamic>? photoDoc;

      for (final d in docsList) {
        final dm = d as Map<String, dynamic>? ?? {};
        final docType = _safeString(
          dm['documentType'],
        ).toUpperCase().replaceAll(' ', '_');

        if (['AADHAAR', 'AADHAR', 'ADHAR', 'AADHAAR_CARD'].contains(docType)) {
          aadhaarDoc = dm;
        }

        if (['DL', 'LICENSE', 'DRIVING_LICENSE'].contains(docType)) {
          licenseDoc = dm;
        }

        if (['PHOTO', 'DRIVER_PHOTO', 'PHOTOGRAPH'].contains(docType)) {
          photoDoc = dm;
        }
      }

      return _DriverPerson(
        role: _safeString(
          emp['empType'] ??
              emp['empJob'] ??
              emp['role'] ??
              emp['jobType'] ??
              'Driver',
        ),
        empNo: _safeString(
          emp['empNo'] ?? emp['employeeNo'] ?? emp['employeeCode'],
        ),
        name: _safeString(
          emp['empName'] ??
              emp['EMP_NAME'] ??
              emp['EMPNAME'] ??
              emp['name'] ??
              emp['NAME'] ??
              emp['employeeName'] ??
              emp['EMPLOYEENAME'],
        ),
        eyeTestDate: _formatDate(eyeDateRaw),
        eyeTestFileName: eyeFileName,

        mobileNo: _safeString(
          emp['mobileNo'] ?? emp['mobile'] ?? emp['phoneNo'] ?? emp['phone'],
        ),
        aadhaarNo: _safeString(
          emp['aadhaarNo'] ?? emp['aadharNo'] ?? aadhaarDoc?['documentNo'],
        ),
        licenseNo: _safeString(
          emp['licenseNo'] ?? emp['licenseNumber'] ?? licenseDoc?['documentNo'],
        ),
        licenseType: _safeString(emp['licenseType'] ?? emp['dlType']),
        licenseFrom: _formatDate(
          emp['licenseFrom'] ??
              emp['licenseValidFrom'] ??
              licenseDoc?['validFrom'],
        ),
        licenseTo: _formatDate(
          emp['licenseTo'] ?? emp['licenseValidTo'] ?? licenseDoc?['validTill'],
        ),
        aadhaarFileName: _extractExistingFileName(aadhaarDoc ?? {}),
        photoFileName: _extractExistingFileName(photoDoc ?? {}),
        licenseFileName: _extractExistingFileName(licenseDoc ?? {}),
      );
    }).toList();
  }

  /// Same behavior as TS getExistingFileName: use filename/fileName/documentName/documentPath and strip path.
  String _extractExistingFileName(Map<String, dynamic> m) {
    final raw =
        m['filename'] ??
        m['fileName'] ??
        m['documentName'] ??
        m['documentPath'];

    if (raw == null) return '';
    return _stripPath(raw.toString());
  }

  Future<void> _resolveDepartmentName() async {
    if (departmentCode.trim().isEmpty) return;

    try {
      final departments = await api.fetchDepartments();

      final match = departments.firstWhere(
        (item) => _safeString(item['deptCode']).trim() == departmentCode.trim(),
        orElse: () => <String, dynamic>{},
      );

      final departmentName = _safeString(
        match['deptName'] ?? match['departmentName'] ?? match['name'],
      );

      if (mounted && departmentName.isNotEmpty) {
        setState(() {
          department = departmentName;
        });
      }
    } catch (_) {
      // Retain departmentCode if the lookup endpoint fails.
    }
  }

  Future<void> _resolveMissingDriverNames() async {
    for (var index = 0; index < drivers.length; index++) {
      final driver = drivers[index];

      if (driver.empNo.trim().isEmpty || driver.name.trim().isNotEmpty) {
        continue;
      }

      final employeeName = await api.fetchEmployeeName(driver.empNo);

      if (!mounted || employeeName == null || employeeName.trim().isEmpty) {
        continue;
      }

      setState(() {
        drivers[index] = driver.copyWith(name: employeeName.trim());
      });
    }
  }

  /// Strip any path segments, return only last part.
  String _stripPath(String s) {
    final parts = s.split('/');
    return parts.isNotEmpty ? parts.last : s;
  }

  String _safeString(dynamic value) {
    return value == null ? '' : value.toString().trim();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final s = value.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '';
    final s = value.toString();
    return s.replaceFirst('T', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final no = requestNo ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: HegAppBar(title: 'CVPS Request $no'),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : hasError
          ? _buildErrorView()
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 12),
                    _buildGeneralSection(),
                    const SizedBox(height: 12),
                    _buildVehicleSection(),
                    const SizedBox(height: 12),
                    _buildDocumentsSection(),
                    const SizedBox(height: 12),
                    _buildDriversSection(),
                    const SizedBox(height: 12),
                    _buildWorkflowSection(),
                    const SizedBox(height: 16),
                    _buildFooterActions(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Header card: icon + title + company + status + form number.
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF1D4ED8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contractor Vehicle Permission Form',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF102A43),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'HEG Limited, Mandideep',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(status, const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
              _pill(formNo, const Color(0xFFF1F5F9), const Color(0xFF334155)),
            ],
          ),
        ],
      ),
    );
  }

  /// Generic section wrapper with title + children.
  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// General Information section – matches Angular labels.
  Widget _buildGeneralSection() {
    return _buildSection(
      title: 'General Information',
      children: [
        _valueField('Contractor Code', contractorCode),
        _valueField('Contractor Name', contractorName),
        _valueField('Department', department),
        _valueField('Nature of Job', natureOfJob),
        _valueField('Permission Date From', reqDate),
        _valueField('Permission Date To', permissionDateTo),
        _valueField('Created By', createdBy),
        _valueField('Created Date', createdDate),
      ],
    );
  }

  /// Vehicle Information section.
  Widget _buildVehicleSection() {
    return _buildSection(
      title: 'Vehicle Information',
      children: [
        _valueField('Vehicle Number', vehicleNumber),
        _valueField('Vehicle Type', vehicleType),
      ],
    );
  }

  /// Required Documents section – mobile-friendly replacement for HTML table.
  Widget _buildDocumentsSection() {
    return _buildSection(
      title: 'Required Documents',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${docs.length} document(s)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const Text(
              'View only',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (docs.isEmpty)
          const Text(
            'No documents available.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          )
        else
          Column(children: docs.map(_buildDocCard).toList()),
      ],
    );
  }

  /// Single document card: Doc Type, Doc No, Valid Upto, File.
  Widget _buildDocCard(_DocEntry d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                d.docType.isEmpty ? '—' : d.docType,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                d.validUpto.isEmpty ? '' : 'Valid upto: ${d.validUpto}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            d.docNo.isEmpty ? 'Doc No: —' : 'Doc No: ${d.docNo}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (d.existingFile != null && d.existingFile!.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'File: ${d.existingFile}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2563EB),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _downloadDoc(d),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download', style: TextStyle(fontSize: 11)),
                ),
              ],
            )
          else
            const Text(
              'File: Not uploaded',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
        ],
      ),
    );
  }

  /// Driver Information section – list of "Person i" cards.
  Widget _buildDriversSection() {
    return _buildSection(
      title: 'Driver Information',
      children: [
        if (drivers.isEmpty)
          const Text(
            'No driver/crew details available.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          )
        else
          Column(
            children: [
              for (var i = 0; i < drivers.length; i++)
                _buildDriverCard(drivers[i], i),
            ],
          ),
      ],
    );
  }

  /// Single driver card: Person i, role, emp code, name, eye test.
  Widget _buildDriverCard(_DriverPerson p, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Person ${index + 1}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF374151),
              ),
            ),
          ),
          _valueField('Role', p.role),
          _valueField('Employee Code', p.empNo),
          _valueField('Name', p.name),
          _valueField('Eye Test Date', p.eyeTestDate),

          // Existing Eye Test File section.
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eye Test File',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                if (p.eyeTestFileName != null && p.eyeTestFileName!.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          p.eyeTestFileName!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _downloadEyeTest(p),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text(
                          'Download',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'No file uploaded',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // New: matches web Driver Information -> View More behavior.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openDriverDetails(p),
              icon: const Icon(Icons.visibility_outlined, size: 17),
              label: const Text(
                'View More',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Workflow Remarks section – history only (view mode).
  Widget _buildWorkflowSection() {
    return _buildSection(
      title: 'Workflow Remarks',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${remarksHistory.length} remark(s)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  showWorkflowHistory = !showWorkflowHistory;
                });
              },
              icon: const Icon(Icons.history, size: 16),
              label: Text(
                showWorkflowHistory ? 'Hide History' : 'History',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!showWorkflowHistory)
          const Text(
            'Tap History to view approval remarks.',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          )
        else if (remarksHistory.isEmpty)
          const Text(
            'No workflow remarks available yet.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          )
        else
          Column(children: remarksHistory.map(_buildWorkflowCard).toList()),
      ],
    );
  }

  /// Single workflow remark card (stage + action + remark).
  Widget _buildWorkflowCard(_WorkflowRemarkEntry r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${r.stage} - ${r.action}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                r.createdAt,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${r.byName} (${r.byEmpCode})',
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 6),
          Text(
            r.remark.isEmpty ? '—' : r.remark,
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
          ),
        ],
      ),
    );
  }

  /// Generic read-only label + value chip.
  Widget _valueField(String label, String value) {
    final display = value.trim().isEmpty ? '-' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              display,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withOpacity(0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }

  /// Footer: Close button only (View mode).
  Widget _buildFooterActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0B1E3A),
              side: const BorderSide(color: Color(0xFFC8D3E1)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Close',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD9E2EC)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFDC2626),
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'Failed to load CVPS request',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF102A43),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: const TextStyle(
                  color: Color(0xFF627D98),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: requestNo == null
                    ? null
                    : () => _loadRequest(requestNo!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B1E3A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
