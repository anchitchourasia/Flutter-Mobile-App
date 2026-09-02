import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import '../core/api_config.dart';
import '../models/cvps_document.dart';
import '../models/cvps_driver.dart';
import '../models/cvps_history_entry.dart';
import '../models/cvps_request_item.dart';

class CvpsApi {
  final http.Client client;

  CvpsApi({http.Client? client}) : client = client ?? http.Client();

  Map<String, String> get _jsonHeaders => {
    'x-api-key': ApiConfig.apiKey,
    'Accept': 'application/json',
  };

  /// GET /api/requests
  Future<List<CvpsRequestItem>> fetchAllRequests() async {
    final response = await client
        .get(Uri.parse(ApiConfig.cvpsGetAllRequests), headers: _jsonHeaders)
        .timeout(const Duration(milliseconds: 12000));

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load CVPS requests (HTTP ${response.statusCode})',
      );
    }

    final body = jsonDecode(response.body);

    if (body is! List) {
      return [];
    }

    final items = body
        .whereType<Map<String, dynamic>>()
        .map(CvpsRequestItem.fromCreateRequestDto)
        .toList();

    items.sort((a, b) => b.requestNo.compareTo(a.requestNo));
    return items;
  }

  /// GET /api/requests/{requestNo}
  Future<Map<String, dynamic>> fetchRequestById(int requestNo) async {
    final response = await client
        .get(
          Uri.parse('${ApiConfig.cvpsGetRequestById}/$requestNo'),
          headers: _jsonHeaders,
        )
        .timeout(const Duration(milliseconds: 12000));

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load request $requestNo (HTTP ${response.statusCode})',
      );
    }

    final body = jsonDecode(response.body);

    if (body is Map<String, dynamic>) {
      return body;
    }

    throw Exception('Unexpected CVPS DTO format');
  }

  /// GET /api/manpower/documents/{empNo}
  Future<Map<String, dynamic>?> fetchManpowerDocuments(String empNo) async {
    final code = empNo.trim();

    if (code.isEmpty) {
      return null;
    }

    final response = await client
        .get(
          Uri.parse(ApiConfig.cvpsGetManpowerDocuments(code)),
          headers: _jsonHeaders,
        )
        .timeout(const Duration(milliseconds: 12000));

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load driver details (HTTP ${response.statusCode})',
      );
    }

    final body = jsonDecode(response.body);

    if (body is! Map<String, dynamic>) {
      return null;
    }

    final data = body['data'];
    return data is Map<String, dynamic> ? data : body;
  }

  /// GET /api/dept
  Future<List<Map<String, dynamic>>> fetchDepartments() async {
    final response = await client
        .get(Uri.parse(ApiConfig.cvpsDepartmentList), headers: _jsonHeaders)
        .timeout(const Duration(milliseconds: 12000));

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load departments (HTTP ${response.statusCode})',
      );
    }

    final body = jsonDecode(response.body);

    if (body is List) {
      return body.whereType<Map<String, dynamic>>().toList();
    }

    if (body is Map<String, dynamic> && body['data'] is List) {
      return (body['data'] as List).whereType<Map<String, dynamic>>().toList();
    }

    return [];
  }

  /// GET /api/requests/history/{requestNo}
  Future<List<Map<String, dynamic>>> fetchRequestHistory(int requestNo) async {
    final response = await client
        .get(
          Uri.parse('${ApiConfig.cvpsBaseUrl}/api/requests/history/$requestNo'),
          headers: _jsonHeaders,
        )
        .timeout(const Duration(milliseconds: 12000));

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load request history (HTTP ${response.statusCode})',
      );
    }

    final body = jsonDecode(response.body);

    if (body is! List) {
      return [];
    }

    return body.whereType<Map<String, dynamic>>().toList();
  }

  /// GET /api/bp-records/{contractorCode}
  Future<Map<String, dynamic>?> fetchContractorDetails(
    String contractorCode,
  ) async {
    final code = contractorCode.trim();

    if (code.isEmpty) {
      return null;
    }

    final response = await client
        .get(
          Uri.parse('${ApiConfig.cvpsBpRecords}/${Uri.encodeComponent(code)}'),
          headers: _jsonHeaders,
        )
        .timeout(const Duration(milliseconds: 12000));

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to fetch contractor details (HTTP ${response.statusCode})',
      );
    }

    final body = jsonDecode(response.body);
    return body is Map<String, dynamic> ? body : null;
  }

  /// GET /api/documents/download/{filename}
  String getDocumentUrl(String fileName) {
    return '${ApiConfig.cvpsBaseUrl}/api/documents/download/'
        '${Uri.encodeComponent(fileName)}';
  }

  Future<Uint8List> downloadDocumentBytes(String fileName) async {
    final response = await client
        .get(Uri.parse(getDocumentUrl(fileName)), headers: {'Accept': '*/*'})
        .timeout(const Duration(milliseconds: 15000));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    throw Exception(
      'Download failed [${response.statusCode}] for ${getDocumentUrl(fileName)}',
    );
  }

  /// GET /api/manpower/documents/download/{fileName}
  String getManpowerDocumentUrl(String fileName) {
    return ApiConfig.cvpsDownloadManpowerDocument(
      Uri.encodeComponent(fileName.trim()),
    );
  }

  Future<Uint8List> downloadManpowerDocumentBytes(String fileName) async {
    final url = getManpowerDocumentUrl(fileName);

    final response = await client
        .get(Uri.parse(url), headers: {'Accept': '*/*'})
        .timeout(const Duration(milliseconds: 15000));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    throw Exception('Download failed [${response.statusCode}] for $url');
  }

  String guessMimeType(String fileName) {
    return lookupMimeType(fileName) ?? 'application/octet-stream';
  }

  /// Resolves employee name for workflow signatures.
  Future<String?> fetchEmployeeName(String empCode) async {
    final code = empCode.trim();

    if (code.isEmpty) {
      return null;
    }

    final urls = [
      '${ApiConfig.employeeReport}/${Uri.encodeComponent(code)}',
      '${ApiConfig.cvpsBaseUrl}/api/requests/employee-name/'
          '${Uri.encodeComponent(code)}',
    ];

    for (final url in urls) {
      try {
        final response = await client
            .get(Uri.parse(url), headers: _jsonHeaders)
            .timeout(const Duration(milliseconds: 12000));

        if (response.statusCode != 200) {
          continue;
        }

        final body = jsonDecode(response.body);

        Map<String, dynamic>? data;

        if (body is Map<String, dynamic>) {
          final nestedData = body['data'];
          data = nestedData is Map<String, dynamic> ? nestedData : body;
        }

        if (data == null) {
          continue;
        }

        final rawName =
            data['empName'] ??
            data['name'] ??
            data['employeeName'] ??
            data['EMPNAME'] ??
            data['EMP_NAME'] ??
            data['EMPLOYEENAME'];

        final name = rawName?.toString().trim() ?? '';

        if (name.isNotEmpty) {
          return name;
        }
      } catch (_) {
        // Try the next endpoint.
      }
    }

    return null;
  }
}

/// Represents complete detail required by the mobile pass/PDF.
class CvpsRequestDetail {
  final CvpsRequestItem request;
  final String contractorName;
  final List<CvpsDocument> vehicleDocuments;
  final List<CvpsDriver> drivers;

  CvpsRequestDetail({
    required this.request,
    required this.contractorName,
    required this.vehicleDocuments,
    required this.drivers,
  });
}

extension CvpsApiDetail on CvpsApi {
  Future<CvpsRequestDetail> fetchRequestDetail(int requestNo) async {
    final raw = await fetchRequestById(requestNo);

    final reqDto = raw['request'] as Map<String, dynamic>? ?? {};
    final docsDto = raw['vehicleDocuments'] as List<dynamic>? ?? const [];
    final employeesDto = raw['employees'] as List<dynamic>? ?? const [];

    final requestItem = CvpsRequestItem.fromRequestMap(reqDto);

    final vehicleDocs = docsDto
        .whereType<Map<String, dynamic>>()
        .map(
          (m) => CvpsDocument(
            documentType: (m['documentType'] ?? '').toString(),
            documentNo: (m['documentNo'] ?? '').toString(),
            validTill: (m['validTill'] ?? m['validTo'] ?? '').toString(),
          ),
        )
        .toList();

    final drivers = <CvpsDriver>[];

    for (final rawEmployee in employeesDto) {
      final employee = rawEmployee as Map<String, dynamic>? ?? {};

      final empNo = _firstText([
        employee['empNo'],
        employee['employeeNo'],
        employee['employeeCode'],
      ]);

      Map<String, dynamic>? manpower;

      if (empNo.isNotEmpty) {
        try {
          manpower = await fetchManpowerDocuments(empNo);
        } catch (_) {
          // Request data remains usable when manpower lookup fails.
        }
      }

      final employeeDocs = (employee['documents'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>();

      String aadhaarNo = '';
      String licenseNo = '';
      String licenseValidTill = '';

      for (final document in employeeDocs) {
        final type = (document['documentType'] ?? '')
            .toString()
            .toUpperCase()
            .replaceAll(' ', '')
            .replaceAll('_', '');

        if (['AADHAAR', 'AADHAR', 'ADHAR', 'AADHAARCARD'].contains(type)) {
          aadhaarNo = (document['documentNo'] ?? '').toString().trim();
        }

        if (['DL', 'LICENSE', 'DRIVINGLICENSE'].contains(type)) {
          licenseNo = (document['documentNo'] ?? '').toString().trim();
          licenseValidTill =
              (document['validTill'] ?? document['validTo'] ?? '')
                  .toString()
                  .trim();
        }
      }

      final role = _firstText([
        employee['empJob'],
        employee['empType'],
        employee['role'],
        employee['jobType'],
      ]);

      final name = _firstText([
        manpower?['empName'],
        manpower?['employeeName'],
        manpower?['name'],
        employee['empName'],
        employee['EMP_NAME'],
        employee['EMPNAME'],
        employee['name'],
        employee['NAME'],
        employee['employeeName'],
        employee['EMPLOYEENAME'],
      ]);

      final mobileNo = _firstText([
        manpower?['mobileNo'],
        manpower?['mobile'],
        manpower?['phoneNo'],
        employee['mobileNo'],
        employee['mobile'],
        employee['phoneNo'],
        employee['phone'],
      ]);

      final finalAadhaarNo = _firstText([
        manpower?['aadharNo'],
        manpower?['aadhaarNo'],
        employee['aadharNo'],
        employee['aadhaarNo'],
        aadhaarNo,
      ]);

      final finalLicenseNo = _firstText([
        manpower?['licenseNo'],
        manpower?['licenseNumber'],
        employee['licenseNo'],
        employee['licenseNumber'],
        licenseNo,
      ]);

      final finalLicenseValidTill = _firstText([
        manpower?['licenseExpDate'],
        manpower?['licenseTo'],
        manpower?['licenseValidTo'],
        employee['licenseExpDate'],
        employee['licenseTo'],
        employee['licenseValidTo'],
        licenseValidTill,
      ]);

      final eyeTestDate = _firstText([
        employee['eyeTestDate'],
        employee['eyetestdate'],
      ]);

      drivers.add(
        CvpsDriver(
          role: role,
          name: name,
          mobileNo: mobileNo,
          aadhaarNo: finalAadhaarNo,
          licenseNo: finalLicenseNo,
          licenseValidTill: finalLicenseValidTill,
          eyeTestDate: eyeTestDate,
        ),
      );
    }

    String contractorName = '';
    final contractorCode = (reqDto['contractorId'] ?? '').toString().trim();

    if (contractorCode.isNotEmpty) {
      try {
        final bp = await fetchContractorDetails(contractorCode);
        contractorName = (bp?['contractorName'] ?? '').toString().trim();
      } catch (_) {
        // Keep an empty contractor name if BP lookup fails.
      }
    }

    return CvpsRequestDetail(
      request: requestItem,
      contractorName: contractorName,
      vehicleDocuments: vehicleDocs,
      drivers: drivers,
    );
  }

  /// Maps API history using the same stage logic as the web pass.
  Future<List<CvpsHistoryEntry>> fetchRequestHistoryEntries(
    int requestNo,
  ) async {
    final rows = await fetchRequestHistory(requestNo);

    final entries = rows.map((row) {
      return CvpsHistoryEntry(
        id: _firstText([row['historyId'], row['id']]),
        stage: _inferHistoryStage(row),
        action: _firstText([
          row['actionTaken'],
          row['statusAfter'],
          row['status'],
        ]),
        remark: _firstText([row['remarks'], row['remark']]),
        byName: _firstText([
          row['empName'],
          row['employeeName'],
          row['name'],
          row['EMP_NAME'],
          row['EMPNAME'],
        ]),
        byEmpCode: _firstText([
          row['empNo'],
          row['employeeCode'],
          row['empCode'],
        ]),
        statusAfter: _firstText([
          row['statusAfter'],
          row['actionTaken'],
          row['status'],
        ]),
        createdAt: _firstText([
          row['actionDate'],
          row['createdAt'],
          row['createdDate'],
        ]),
      );
    }).toList();

    entries.sort((a, b) {
      final aMillis = _historySortValue(a);
      final bMillis = _historySortValue(b);

      return aMillis.compareTo(bMillis);
    });

    return entries;
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  String _normalizeHistoryAction(dynamic value) {
    return (value ?? '').toString().trim().toUpperCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  /// Exact equivalent of the web `inferHistoryStage(...)` behavior.
  String _inferHistoryStage(Map<String, dynamic> row) {
    final explicitStage = _firstText([
      row['stage'],
      row['level'],
      row['role'],
      row['actionByRole'],
      row['actionRole'],
      row['userRole'],
    ]).toUpperCase();

    final action = _normalizeHistoryAction(
      row['actionTaken'] ?? row['statusAfter'] ?? row['status'],
    );

    if (explicitStage.contains('UPLOADER') ||
        explicitStage.contains('CREATOR') ||
        explicitStage.contains('REQUESTER') ||
        explicitStage.contains('SUBMITTER')) {
      return 'UPLOADER';
    }

    if (explicitStage.contains('APPROVER')) {
      return 'APPROVER';
    }

    if (explicitStage.contains('VERIFIER')) {
      return 'VERIFIER';
    }

    if (explicitStage.contains('CONFIRMER')) {
      return 'CONFIRMER';
    }

    if (['SAVED', 'DRAFT', 'CREATED', 'SUBMITTED'].contains(action)) {
      return 'UPLOADER';
    }

    if (action == 'VERIFIED') {
      return 'VERIFIER';
    }

    if (['APPROVED', 'REJECTED'].contains(action)) {
      return 'APPROVER';
    }

    return 'CONFIRMER';
  }

  int _historySortValue(CvpsHistoryEntry entry) {
    final raw = entry.createdAt.trim();

    // ISO: 2026-08-03T15:18:55 or 2026-08-03 15:18:55
    final iso = DateTime.tryParse(raw);
    if (iso != null) {
      return iso.millisecondsSinceEpoch;
    }

    // Oracle: 03-AUG-26 03.18.55.014000000 PM
    final oracle = RegExp(
      r'^(\d{2})-([A-Za-z]{3})-(\d{2,4})\s+'
      r'(\d{2})\.(\d{2})\.(\d{2})(?:\.\d+)?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(raw);

    if (oracle == null) {
      return int.tryParse(entry.id) ?? 0;
    }

    const months = {
      'JAN': 1,
      'FEB': 2,
      'MAR': 3,
      'APR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AUG': 8,
      'SEP': 9,
      'OCT': 10,
      'NOV': 11,
      'DEC': 12,
    };

    final day = int.parse(oracle.group(1)!);
    final month = months[oracle.group(2)!.toUpperCase()] ?? 1;

    final rawYear = oracle.group(3)!;
    final year = rawYear.length == 2
        ? 2000 + int.parse(rawYear)
        : int.parse(rawYear);

    final hour12 = int.parse(oracle.group(4)!);
    final minute = int.parse(oracle.group(5)!);
    final second = int.parse(oracle.group(6)!);
    final period = oracle.group(7)!.toUpperCase();

    var hour24 = hour12;

    if (period == 'PM' && hour12 != 12) {
      hour24 += 12;
    } else if (period == 'AM' && hour12 == 12) {
      hour24 = 0;
    }

    return DateTime(
      year,
      month,
      day,
      hour24,
      minute,
      second,
    ).millisecondsSinceEpoch;
  }
}
