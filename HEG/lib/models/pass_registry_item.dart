class PassRegistryItem {
  final int id;
  final int passId;
  final String passNo;
  final String vehicleNo;
  final String vehicleType;
  final String employeeNo;
  final String empType;
  final String name;
  final String deptCode;
  final String deptName;
  final String contractorCode;
  final String contractorName;
  final String aadhaarNo;
  final String status;
  final String passStatus;
  final String gateNo;

  const PassRegistryItem({
    required this.id,
    required this.passId,
    required this.passNo,
    required this.vehicleNo,
    required this.vehicleType,
    required this.employeeNo,
    required this.empType,
    required this.name,
    required this.deptCode,
    required this.deptName,
    required this.contractorCode,
    required this.contractorName,
    required this.aadhaarNo,
    required this.status,
    required this.passStatus,
    required this.gateNo,
  });

  factory PassRegistryItem.fromJson(Map<String, dynamic> row) {
    final rawStatus = (row['status'] ?? '').toString().trim().toUpperCase();

    String displayStatus = (row['status'] ?? '').toString();
    if (rawStatus == 'APPROVED' || rawStatus == 'ACTIVE') {
      displayStatus = 'ACTIVE';
    } else if (rawStatus == 'MODIFY' ||
        rawStatus == 'NEEDS_MODIFICATION' ||
        rawStatus == 'NEEDSMODIFICATION') {
      displayStatus = 'NEEDS_MODIFICATION';
    } else if (rawStatus == 'REGRET' ||
        rawStatus == 'REJECTED' ||
        rawStatus == 'REJECT') {
      displayStatus = 'REJECT';
    }

    return PassRegistryItem(
      id: _toInt(row['id']),
      passId: _toInt(row['id']),
      passNo: (row['passNo'] ?? '').toString(),
      vehicleNo: (row['vehicleNo'] ?? '').toString(),
      vehicleType: (row['vehicleType'] ?? '').toString(),
      employeeNo: (row['employeeNo'] ?? '').toString(),
      empType: (row['empType'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      deptCode: (row['deptCode'] ?? '').toString(),
      deptName: (row['deptName'] ?? '').toString(),
      contractorCode: (row['contractorCode'] ?? '').toString(),
      contractorName: (row['contractorName'] ?? '').toString(),
      aadhaarNo: (row['aadhaarNo'] ?? '').toString(),
      status: displayStatus,
      passStatus: displayStatus,
      gateNo: (row['gateNo'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  bool matchesSearch(String search) {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return true;

    return passNo.toLowerCase().contains(q) ||
        vehicleNo.toLowerCase().contains(q) ||
        employeeNo.toLowerCase().contains(q) ||
        name.toLowerCase().contains(q) ||
        contractorCode.toLowerCase().contains(q) ||
        contractorName.toLowerCase().contains(q) ||
        empType.toLowerCase().contains(q);
  }

  bool matchesStatus(String filter) {
    final normalizedFilter = filter.trim().toUpperCase();
    final rowStatus = status.trim().toUpperCase();

    if (normalizedFilter == 'ALL' || normalizedFilter.isEmpty) return true;
    if (normalizedFilter == 'REJECT' ||
        normalizedFilter == 'REJECTED' ||
        normalizedFilter == 'REGRET') {
      return rowStatus == 'REJECT';
    }
    if (normalizedFilter == 'NEEDS_MODIFICATION' ||
        normalizedFilter == 'MODIFY' ||
        normalizedFilter == 'NEEDSMODIFICATION') {
      return rowStatus == 'NEEDS_MODIFICATION';
    }
    if (normalizedFilter == 'ACTIVE' || normalizedFilter == 'APPROVED') {
      return rowStatus == 'ACTIVE';
    }

    return rowStatus == normalizedFilter;
  }

  bool matchesEmpType(String filter) {
    if (filter == 'ALL') return true;
    return empType.trim().toUpperCase() == filter.trim().toUpperCase();
  }

  bool matchesVehicleType(String filter) {
    final selected = filter.trim().toUpperCase();

    if (selected.isEmpty || selected == 'ALL') {
      return true;
    }

    final actual = vehicleType
        .trim()
        .toUpperCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    // Direct match: CAR = CAR, JCB = JCB, etc.
    if (actual == selected) {
      return true;
    }

    // Handles common backend category variations.
    switch (selected) {
      case 'BIKE':
      case 'SCOOTER':
        return actual.contains('BIKE') ||
            actual.contains('SCOOTER') ||
            actual.contains('TWO WHEELER');

      case 'CAR':
        return actual.contains('CAR') || actual.contains('FOUR WHEELER');

      case 'TRUCK':
        return actual.contains('TRUCK') || actual.contains('HEAVY VEHICLE');

      case 'DUMPER':
        return actual.contains('DUMPER');

      case 'JCB':
        return actual.contains('JCB');

      case 'CRANE':
        return actual.contains('CRANE');

      case 'TRACTOR':
        return actual.contains('TRACTOR');

      default:
        return false;
    }
  }

  bool get canEdit {
    final s = status.trim().toUpperCase();
    return s == 'DRAFT' ||
        s == 'SAVED' ||
        s == 'NEEDS_MODIFICATION' ||
        s == 'NEEDSMODIFICATION' ||
        s == 'MODIFY';
  }
}
