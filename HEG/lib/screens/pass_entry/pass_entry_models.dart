class PassDocumentModel {
  final int? documentId;
  String documentType; // RC, INSURANCE, LICENSE
  String documentNo;
  String expiryDate; // YYYY-MM-DD
  final String fileKey;
  final String fileName;
  // For mobile, we can store path or bytes instead of File
  final String? filePath; // or Uint8List fileBytes;

  PassDocumentModel({
    this.documentId,
    required this.documentType,
    required this.documentNo,
    required this.expiryDate,
    this.fileKey = '',
    this.fileName = '',
    this.filePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'documentId': documentId,
      'documentType': documentType,
      'documentNo': documentNo,
      'expiryDate': expiryDate,
      'fileKey': fileKey,
      'fileName': fileName,
      // backend may not need filePath in JSON; file sent separately
    };
  }
}

class PassRequestModel {
  final int? id;
  final int? passNo;
  final String vehicleNo;
  final String
  vehicleType; // BIKE, SCOOTER, CAR, TRUCK, DUMPER, JCB, CRANE, TRACTOR
  final String brandModel;
  final String employeeNo;
  final String empType; // HEG, TACC, CONTRACT, CRE-PRM
  final String? contractorCode;
  final String gateNo; // GATE_01 … GATE_05
  final String parkingToBeUsed; // P1 … P5
  final String status; // DRAFT, SAVED, SUBMITTED, etc.
  final String? remark;
  final String enterBy;
  final List<PassDocumentModel> documents;

  PassRequestModel({
    this.id,
    this.passNo,
    required this.vehicleNo,
    required this.vehicleType,
    required this.brandModel,
    required this.employeeNo,
    required this.empType,
    this.contractorCode,
    required this.gateNo,
    required this.parkingToBeUsed,
    required this.status,
    this.remark,
    required this.enterBy,
    required this.documents,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'passNo': passNo,
      'vehicleNo': vehicleNo,
      'vehicleType': vehicleType,
      'brandModel': brandModel,
      'employeeNo': employeeNo,
      'empType': empType,
      'contractorCode': contractorCode,
      'gateNo': gateNo,
      'parkingToBeUsed': parkingToBeUsed,
      'status': status,
      'remark': remark,
      'enterBy': enterBy,
      'documents': documents.map((d) => d.toJson()).toList(),
    };
  }
}

class PassHistoryItem {
  final int? id;
  final String passNo;
  final String empCode;
  final String action;
  final String remark;
  final String dateOfEntry;

  PassHistoryItem({
    this.id,
    required this.passNo,
    required this.empCode,
    required this.action,
    required this.remark,
    required this.dateOfEntry,
  });

  factory PassHistoryItem.fromJson(Map<String, dynamic> json) {
    return PassHistoryItem(
      id: json['id'] as int?,
      passNo: (json['passNo'] ?? '').toString(),
      empCode: (json['empCode'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      remark: (json['remark'] ?? '').toString(),
      dateOfEntry: (json['dateOfEntry'] ?? '').toString(),
    );
  }
}
