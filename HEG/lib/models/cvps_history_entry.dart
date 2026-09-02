class CvpsHistoryEntry {
  final String id;
  final String stage;     // 'UPLOADER' | 'CONFIRMER' | 'APPROVER'
  final String action;
  final String remark;
  final String byName;
  final String byEmpCode;
  final String statusAfter;
  final String createdAt;

  CvpsHistoryEntry({
    required this.id,
    required this.stage,
    required this.action,
    required this.remark,
    required this.byName,
    required this.byEmpCode,
    required this.statusAfter,
    required this.createdAt,
  });

  factory CvpsHistoryEntry.fromJson(Map<String, dynamic> m) {
    // Raw fields from backend
    final historyId = m['historyId']?.toString();
    final empNo = (m['empNo'] ?? '').toString().trim();
    final actionTaken = (m['actionTaken'] ?? '').toString();
    final remarks = (m['remarks'] ?? '').toString();
    final actionDate = (m['actionDate'] ?? '').toString();

    // Match Angular inferHistoryStage(row)
    final explicitStage = (m['stage'] ??
            m['level'] ??
            m['role'] ??
            m['actionByRole'] ??
            m['actionRole'] ??
            m['userRole'] ??
            '')
        .toString()
        .trim()
        .toUpperCase();

    String normalizeAction(String? v) {
      return (v ?? '')
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'\s+'), ' ');
    }

    final actionNorm = normalizeAction(
      m['actionTaken'] ?? m['statusAfter'] ?? m['status'],
    );

    String inferredStage;
    if (explicitStage.contains('UPLOADER') ||
        explicitStage.contains('CREATOR') ||
        explicitStage.contains('REQUESTER') ||
        explicitStage.contains('SUBMITTER')) {
      inferredStage = 'UPLOADER';
    } else if (explicitStage.contains('APPROVER')) {
      inferredStage = 'APPROVER';
    } else if (explicitStage.contains('CONFIRMER')) {
      inferredStage = 'CONFIRMER';
    } else if (['SAVED', 'DRAFT', 'CREATED', 'SUBMITTED'].contains(actionNorm)) {
      inferredStage = 'UPLOADER';
    } else if (['APPROVED', 'REJECTED'].contains(actionNorm)) {
      inferredStage = 'APPROVER';
    } else {
      inferredStage = 'CONFIRMER';
    }

    return CvpsHistoryEntry(
      id: historyId ?? '0',
      stage: inferredStage,
      action: actionTaken,
      remark: remarks,
      byName: '',       // we'll fill via EMPLOYEE_REPORT if you want, see below
      byEmpCode: empNo.isEmpty ? 'SYSTEM' : empNo,
      statusAfter: actionTaken,
      createdAt: actionDate,
    );
  }
}