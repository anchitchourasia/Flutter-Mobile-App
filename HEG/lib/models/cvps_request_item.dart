/// Data model for a single CVPS vehicle permission row.
/// This mirrors the VehiclePermissionRow interface in vehicle-permission-list.ts.
class CvpsRequestItem {
  /// Unique request number (primary key).
  final int requestNo;

  /// Contractor code (e.g. contractor ID from CVPS).
  final String contractorCode;

  /// Vehicle number (e.g. MP04 AB 1234).
  final String vehicleNo;

  /// Vehicle type (e.g. FOUR_WHEEL, HEAVY).
  final String vehicleType;

  /// Text describing the nature of job.
  final String natureOfJob;

  /// Permission date (To) formatted as YYYY-MM-DD (web uses formatDate).
  final String permissionTo;

  /// Normalized request status (web’s normalizeRequestStatus).
  final String reqStatus;

  /// Who created this request (emp code).
  final String createdBy;

  /// Created date formatted as YYYY-MM-DD.
  final String createdDate;

  /// Count of personnel (employees array length).
  final int personnelCount;

  /// Count of vehicle documents (vehicleDocuments array length).
  final int vehicleDocumentCount;

  CvpsRequestItem({
    required this.requestNo,
    required this.contractorCode,
    required this.vehicleNo,
    required this.vehicleType,
    required this.natureOfJob,
    required this.permissionTo,
    required this.reqStatus,
    required this.createdBy,
    required this.createdDate,
    required this.personnelCount,
    required this.vehicleDocumentCount,
  });

  // ─────────────────────────────────────────────────────────
  // Helper functions shared by both factories
  // ─────────────────────────────────────────────────────────

  static String _formatDate(dynamic value) {
    if (value == null) return '';
    final s = value.toString();
    // Web splits on 'T', so do the same.
    return s.split('T').first;
  }

  static String _normalizeStatus(dynamic status) {
    final normalized = (status ?? '').toString().trim().toUpperCase();
    switch (normalized) {
      case 'DRAFT':
        return 'SAVED';
      case 'MODIFY':
        return 'MODIFY';
      case 'CREATED':
        return 'SUBMITTED';
      default:
        return normalized;
    }
  }

  /// Factory that maps a full CreateRequestDTO JSON into this row.
  /// This is equivalent to mapToRow(dto: CreateRequestDTO) in the web list code.
  ///
  /// Expected shape:
  /// {
  ///   "request": { ... },
  ///   "employees": [ ... ],
  ///   "vehicleDocuments": [ ... ]
  /// }
  factory CvpsRequestItem.fromCreateRequestDto(Map<String, dynamic> dto) {
    // request object inside CreateRequestDTO
    final req = dto['request'] as Map<String, dynamic>? ?? {};

    // employees and vehicleDocuments arrays from DTO.
    final employees = dto['employees'] as List<dynamic>? ?? const [];
    final vehicleDocs = dto['vehicleDocuments'] as List<dynamic>? ?? const [];

    return CvpsRequestItem(
      requestNo: int.tryParse('${req['requestNo'] ?? 0}') ?? 0,
      contractorCode: (req['contractorId'] ?? '').toString(),
      vehicleNo: (req['vehicleNo'] ?? '').toString(),
      vehicleType: (req['vehicleType'] ?? '').toString(),
      natureOfJob: (req['natureOfJob'] ?? '').toString(),
      permissionTo: _formatDate(req['permissionTo']),
      reqStatus: _normalizeStatus(req['reqStatus']),
      createdBy: (req['createdBy'] ?? '').toString(),
      createdDate: _formatDate(req['createdDate']),
      personnelCount: employees.length,
      vehicleDocumentCount: vehicleDocs.length,
    );
  }

  /// Factory that maps a single request map (the inner `request` object)
  /// into CvpsRequestItem. This is used by the pass page, which already
  /// has `raw['request']` from CreateRequestDTO.
  ///
  /// Expected shape:
  /// {
  ///   "requestNo": ...,
  ///   "contractorId": ...,
  ///   "vehicleNo": ...,
  ///   "vehicleType": ...,
  ///   "natureOfJob": ...,
  ///   "permissionTo": ...,
  ///   "reqStatus": ...,
  ///   "createdBy": ...,
  ///   "createdDate": ...
  /// }
  factory CvpsRequestItem.fromRequestMap(Map<String, dynamic> req) {
    return CvpsRequestItem(
      requestNo: int.tryParse('${req['requestNo'] ?? 0}') ?? 0,
      contractorCode: (req['contractorId'] ?? '').toString(),
      vehicleNo: (req['vehicleNo'] ?? '').toString(),
      vehicleType: (req['vehicleType'] ?? '').toString(),
      natureOfJob: (req['natureOfJob'] ?? '').toString(),
      permissionTo: _formatDate(req['permissionTo']),
      reqStatus: _normalizeStatus(req['reqStatus']),
      createdBy: (req['createdBy'] ?? '').toString(),
      createdDate: _formatDate(req['createdDate']),
      // counts are not needed on the pass screen
      personnelCount: 0,
      vehicleDocumentCount: 0,
    );
  }
}
