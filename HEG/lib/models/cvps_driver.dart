class CvpsDriver {
  final String role;
  final String name;
  final String mobileNo;
  final String aadhaarNo;
  final String licenseNo;
  final String licenseValidTill;
  final String eyeTestDate;

  CvpsDriver({
    required this.role,
    required this.name,
    required this.mobileNo,
    required this.aadhaarNo,
    required this.licenseNo,
    required this.licenseValidTill,
    this.eyeTestDate = '',
  });
}
