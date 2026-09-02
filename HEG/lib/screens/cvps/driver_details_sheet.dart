import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/cvps_api.dart';

class DriverDetailsData {
  final String empNo;
  final String name;
  final String mobileNo;
  final String aadhaarNo;
  final String licenseNo;
  final String licenseFrom;
  final String licenseTo;
  final String aadhaarFileName;
  final String photoFileName;
  final String licenseFileName;

  const DriverDetailsData({
    required this.empNo,
    required this.name,
    required this.mobileNo,
    required this.aadhaarNo,
    required this.licenseNo,
    required this.licenseFrom,
    required this.licenseTo,
    required this.aadhaarFileName,
    required this.photoFileName,
    required this.licenseFileName,
  });

  DriverDetailsData mergeApiData(Map<String, dynamic> data) {
    return DriverDetailsData(
      empNo: _value(data, ['empNo', 'employeeNo', 'employeeCode'], empNo),
      name: _value(
        data,
        [
          'empName',
          'employeeName',
          'name',
          'EMP_NAME',
          'EMPNAME',
          'EMPLOYEENAME',
        ],
        name,
      ),
      mobileNo: _value(
        data,
        ['mobileNo', 'mobile', 'phoneNo', 'phone', 'contactNo'],
        mobileNo,
      ),
      aadhaarNo: _value(
        data,
        ['aadhaarNo', 'aadharNo', 'aadhaar', 'aadhar'],
        aadhaarNo,
      ),
      licenseNo: _value(
        data,
        ['licenseNo', 'licenseNumber', 'licenceNo', 'dlNo'],
        licenseNo,
      ),
      licenseFrom: _date(
        _value(
          data,
          ['licenseActDate', 'licenseFrom', 'licenseValidFrom', 'validFrom'],
          licenseFrom,
        ),
      ),
      licenseTo: _date(
        _value(
          data,
          ['licenseExpDate', 'licenseTo', 'licenseValidTo', 'validTill'],
          licenseTo,
        ),
      ),
      aadhaarFileName: _fileName(
        _value(
          data,
          ['aadharFile', 'aadhaarFile', 'aadhaarFileName'],
          aadhaarFileName,
        ),
      ),
      photoFileName: _fileName(
        _value(
          data,
          ['empPhoto', 'photoFile', 'photoFileName'],
          photoFileName,
        ),
      ),
      licenseFileName: _fileName(
        _value(
          data,
          ['licenseFile', 'licenceFile', 'licenseFileName'],
          licenseFileName,
        ),
      ),
    );
  }

  static String _value(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  static String _fileName(String value) {
    return value.replaceAll('\\', '/').split('/').last;
  }

  static String _date(String value) {
    return value.length >= 10 ? value.substring(0, 10) : value;
  }
}

class DriverDetailsSheet extends StatefulWidget {
  final CvpsApi api;
  final DriverDetailsData driver;

  const DriverDetailsSheet({
    super.key,
    required this.api,
    required this.driver,
  });

  @override
  State<DriverDetailsSheet> createState() => _DriverDetailsSheetState();
}

class _DriverDetailsSheetState extends State<DriverDetailsSheet> {
  late DriverDetailsData _driver;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _driver = widget.driver;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (_driver.empNo.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.api.fetchManpowerDocuments(_driver.empNo);

      if (data != null && mounted) {
        setState(() => _driver = _driver.mergeApiData(data));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load driver details.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _download(String fileName, String label) async {
    final name = fileName.trim();
    if (name.isEmpty) return;

    try {
      final bytes = await widget.api.downloadManpowerDocumentBytes(name);

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
        type: widget.api.guessMimeType(name),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download $label: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              _header(),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(14),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          children: [
                            if (_error != null) _message(_error!),
                            _section(
                              title: 'Personal Information',
                              icon: Icons.person,
                              children: [
                                _field('Driver Name', _driver.name),
                                _field('Employee Number', _driver.empNo),
                                _field('Mobile Number', _driver.mobileNo),
                                _field('Aadhaar Number', _driver.aadhaarNo),
                                _fileField(
                                  'Aadhaar File',
                                  _driver.aadhaarFileName,
                                ),
                                _fileField(
                                  'Driver Photo',
                                  _driver.photoFileName,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _section(
                              title: 'Driving Licence Information',
                              icon: Icons.badge_outlined,
                              children: [
                                _field('License Number', _driver.licenseNo),
                                _field('License From', _driver.licenseFrom),
                                _field('License To', _driver.licenseTo),
                                _fileField(
                                  'License File',
                                  _driver.licenseFileName,
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 10),
          child: Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                color: Color(0xFF1D4ED8),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Driver Details',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF102A43),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF2563EB)),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF102A43),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return _box(
      label,
      Text(
        value.trim().isEmpty ? '—' : value.trim(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _fileField(String label, String fileName) {
    final hasFile = fileName.trim().isNotEmpty;

    return _box(
      label,
      hasFile
          ? OutlinedButton.icon(
              onPressed: () => _download(fileName, label),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                visualDensity: VisualDensity.compact,
              ),
            )
          : const Text(
              'Not available',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
    );
  }

  Widget _box(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }

  Widget _message(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF9A3412),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}