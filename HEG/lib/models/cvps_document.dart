class CvpsDocument {
  final String documentType; // e.g. 'RC', 'Insurance'
  final String documentNo;
  final String validTill;    // ISO string from backend, e.g. '2026-09-05'

  CvpsDocument({
    required this.documentType,
    required this.documentNo,
    required this.validTill,
  });
}