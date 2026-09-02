// lib/services/cvps_pass_pdf_service.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../models/cvps_request_item.dart';
import '../models/cvps_document.dart';
import '../models/cvps_driver.dart';
import '../models/cvps_history_entry.dart';

/// Simple style holder for remark chips (expired/expiring/valid).
class _RemarkStyle {
  final PdfColor fillColor;
  final PdfColor textColor;

  const _RemarkStyle(this.fillColor, this.textColor);
}

class CvpsPassPdfService {
  Future<void> generateAndOpenPassPdf({
    required CvpsRequestItem request,
    required List<CvpsDocument> vehicleDocuments,
    required List<CvpsDriver> drivers,
    required List<CvpsHistoryEntry> history,
    required String contractorName,
    required String formNo,
    required int requestNo,
  }) async {
    final pdf = pw.Document();

    // Load logos from Flutter assets
    final Uint8List? securityLogoBytes = await _loadAssetBytes(
      'assets/images/security.jpg',
    );
    final Uint8List? hegLogoBytes = await _loadAssetBytes(
      'assets/images/heg_logo.jpg',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          _buildHeader(formNo, securityLogoBytes, hegLogoBytes),
          pw.SizedBox(height: 12),
          _buildGeneralInfo(request, contractorName, requestNo),
          pw.SizedBox(height: 12),
          _buildVehicleDocsTable(vehicleDocuments, request),
          pw.SizedBox(height: 12),
          _buildDriversTable(drivers),
        ],
        footer: (context) {
          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _buildSignaturesRow(request, contractorName, history),
              pw.SizedBox(height: 8),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'vehicle-permission-pass-$requestNo.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await OpenFilex.open(file.path);
  }

  Future<Uint8List?> _loadAssetBytes(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ── HEADER ──────────────────────────────────────────────

  pw.Widget _buildHeader(
    String formNo,
    Uint8List? securityLogoBytes,
    Uint8List? hegLogoBytes,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Left: Security logo
          pw.Container(
            width: 40,
            height: 40,
            alignment: pw.Alignment.center,
            child: securityLogoBytes != null
                ? pw.Image(
                    pw.MemoryImage(securityLogoBytes),
                    fit: pw.BoxFit.contain,
                  )
                : pw.Text(
                    'SECURITY',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
          ),

          // Center: Title + subtitle
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'VENDORS VEHICLE/CONTRACTOR PERMISSION FORM',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'HEG LIMITED, MANDIDEEP',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.normal,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),

          // Right: HEG logo
          pw.Container(
            width: 40,
            height: 40,
            alignment: pw.Alignment.center,
            child: hegLogoBytes != null
                ? pw.Image(pw.MemoryImage(hegLogoBytes), fit: pw.BoxFit.contain)
                : pw.Text(
                    'HEG',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
          ),
        ],
      ),
    );
  }

  // ── GENERAL INFO ────────────────────────────────────────

  pw.Widget _buildGeneralInfo(
    CvpsRequestItem req,
    String contractorName,
    int requestNo,
  ) {
    final contractorDisplay = contractorName.isEmpty
        ? (req.contractorCode.isEmpty ? '-' : req.contractorCode)
        : '$contractorName (${req.contractorCode.isEmpty ? '-' : req.contractorCode})';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Section title row with form chip
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'General Information',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
              ),
              child: pw.Text(
                'W-OHS-SECURITY-12',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
          },
          children: [
            _infoRow(
              'Permission No.',
              requestNo.toString(),
              'Contractor Name (Code)',
              contractorDisplay,
              'Request Date',
              _fmtDate(req.createdDate),
            ),
            _infoRow(
              'Nature of Job',
              req.natureOfJob.isEmpty ? '-' : req.natureOfJob,
              'Permission To',
              _fmtDate(req.permissionTo),
              'Current Status',
              req.reqStatus.isEmpty ? '-' : req.reqStatus,
            ),
          ],
        ),
      ],
    );
  }

  pw.TableRow _infoRow(
    String l1,
    String v1,
    String l2,
    String v2,
    String l3,
    String v3,
  ) {
    return pw.TableRow(
      children: [_fieldCell(l1, v1), _fieldCell(l2, v2), _fieldCell(l3, v3)],
    );
  }

  pw.Widget _fieldCell(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value.isEmpty ? '-' : value,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ── VEHICLE DETAILS TITLE ───────────────────────────────

  String _vehicleDetailsTitle(CvpsRequestItem req) {
    final vehicleNo = req.vehicleNo.isEmpty ? '-' : req.vehicleNo.trim();
    final vehicleType = req.vehicleType.isEmpty ? '-' : req.vehicleType.trim();
    return 'Vehicle Details ($vehicleNo, $vehicleType)';
  }

  // ── VEHICLE DOCUMENTS TABLE ─────────────────────────────

  pw.Widget _buildVehicleDocsTable(
    List<CvpsDocument> docs,
    CvpsRequestItem req,
  ) {
    final data = docs
        .map(
          (d) => [
            d.documentType.isEmpty ? '-' : d.documentType,
            d.documentNo.isEmpty ? '-' : d.documentNo,
            _fmtDate(d.validTill),
            _remarkText(d.validTill),
          ],
        )
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          _vehicleDetailsTitle(req),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableHeaderCell('Vehicle Documents'),
                _tableHeaderCell('Doc. Number'),
                _tableHeaderCell('Valid Upto'),
                _tableHeaderCell('Remark'),
              ],
            ),
            ...data.map((row) {
              final remarkStyle = _remarkStyle(row[2]);
              return pw.TableRow(
                children: [
                  _tableCell(row[0]),
                  _tableCell(row[1]),
                  _tableCell(row[2]),
                  _remarkCell(row[3], remarkStyle),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── DRIVERS TABLE ───────────────────────────────────────

  pw.Widget _buildDriversTable(List<CvpsDriver> drivers) {
    final data = drivers
        .map(
          (d) => [
            d.role.isEmpty ? '-' : d.role,
            d.name.isEmpty ? '-' : d.name,
            d.mobileNo.isEmpty ? '-' : d.mobileNo,
            d.aadhaarNo.isEmpty ? '-' : d.aadhaarNo,
            d.licenseNo.isEmpty ? '-' : d.licenseNo,
            _fmtDate(d.licenseValidTill),
            _fmtDate(d.eyeTestDate),
            _remarkText(d.licenseValidTill),
          ],
        )
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Driver / Conductor Details',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableHeaderCell('Role'),
                _tableHeaderCell('Name'),
                _tableHeaderCell('Contact No.'),
                _tableHeaderCell('Aadhar No.'),
                _tableHeaderCell('License No.'),
                _tableHeaderCell('License Valid Upto'),
                _tableHeaderCell('Eye Test Date'),
                _tableHeaderCell('Remark (License)'),
              ],
            ),
            ...data.map((row) {
              final remarkStyle = _remarkStyle(row[5]);
              return pw.TableRow(
                children: [
                  _tableCell(row[0]),
                  _tableCell(row[1]),
                  _tableCell(row[2]),
                  _tableCell(row[3]),
                  _tableCell(row[4]),
                  _tableCell(row[5]),
                  _tableCell(row[6]),
                  _remarkCell(row[7], remarkStyle),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── SIGNATURES ──────────────────────────────────────────

  pw.Widget _buildSignaturesRow(
    CvpsRequestItem req,
    String contractorName,
    List<CvpsHistoryEntry> history,
  ) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _signatureBlock(
                name: contractorName.isEmpty ? '-' : contractorName,
                code: req.contractorCode.isEmpty ? '-' : req.contractorCode,
                dateText: _fmtDateTime(
                  _latestStageDate(history, 'UPLOADER') ?? '',
                ),
                role: 'uploader',
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: _signatureBlock(
                name: _stageName(history, 'CONFIRMER'),
                code: _stageEmpCode(history, 'CONFIRMER'),
                dateText: _fmtDateTime(
                  _latestStageDate(history, 'CONFIRMER') ?? '',
                ),
                role: 'confirmer',
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: _signatureBlock(
                name: _stageName(history, 'VERIFIER'),
                code: _stageEmpCode(history, 'VERIFIER'),
                dateText: _fmtDateTime(
                  _latestStageDate(history, 'VERIFIER') ?? '',
                ),
                role: 'verifier',
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: _signatureBlock(
                name: _stageName(history, 'APPROVER'),
                code: _stageEmpCode(history, 'APPROVER'),
                dateText: _fmtDateTime(
                  _latestStageDate(history, 'APPROVER') ?? '',
                ),
                role: 'approver',
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _signatureBlock({
    required String name,
    required String code,
    required String dateText,
    required String role,
  }) {
    final displayName = name.trim().isEmpty ? '-' : name.trim();
    final displayCode = code.trim().isEmpty ? '-' : code.trim();
    final displayDate = dateText.trim().isEmpty ? '-' : dateText.trim();

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.SizedBox(
            height: 18,
            child: pw.Center(
              child: pw.Text(
                displayName,
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Container(height: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 3),
          pw.Text(
            displayCode,
            maxLines: 1,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            displayDate,
            maxLines: 1,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 5.5),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            role,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 6),
          ),
        ],
      ),
    );
  }
  // ── FOOTER ──────────────────────────────────────────────

  pw.Widget _buildFooter() {
    final now = DateTime.now();
    final generatedText =
        'Generated on: ${now.day.toString().padLeft(2, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(generatedText, style: const pw.TextStyle(fontSize: 8)),
        pw.Text('HEG Limited', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  // ── TABLE CELL HELPERS ─────────────────────────────────

  pw.Widget _tableHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      color: PdfColors.grey200,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700,
        ),
      ),
    );
  }

  pw.Widget _tableCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text.isEmpty ? '-' : text,
        style: const pw.TextStyle(fontSize: 8.5),
      ),
    );
  }

  pw.Widget _remarkCell(String text, _RemarkStyle style) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: style.fillColor,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: style.textColor,
        ),
      ),
    );
  }

  // ── HELPERS ─────────────────────────────────────────────

  String _fmtDate(String value) {
    if (value.trim().isEmpty) return '-';

    try {
      final d = DateTime.parse(value);

      return '${d.day.toString().padLeft(2, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.year}';
    } catch (_) {
      return value;
    }
  }

  String _fmtDateTime(String value) {
    final raw = value.trim();

    if (raw.isEmpty) {
      return '-';
    }

    // Oracle timestamp:
    // 03-AUG-26 03.18.55.014000000 PM
    final oracleMatch = RegExp(
      r'^(\d{2})-([A-Za-z]{3})-(\d{2,4})\s+'
      r'(\d{2})\.(\d{2})\.(\d{2})(?:\.\d+)?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(raw);

    if (oracleMatch != null) {
      final day = oracleMatch.group(1)!;
      final monthName = oracleMatch.group(2)!.toUpperCase();
      final shortOrLongYear = oracleMatch.group(3)!;
      final hour12 = int.parse(oracleMatch.group(4)!);
      final minute = oracleMatch.group(5)!;
      final second = oracleMatch.group(6)!;
      final period = oracleMatch.group(7)!.toUpperCase();

      const monthNumbers = {
        'JAN': '01',
        'FEB': '02',
        'MAR': '03',
        'APR': '04',
        'MAY': '05',
        'JUN': '06',
        'JUL': '07',
        'AUG': '08',
        'SEP': '09',
        'OCT': '10',
        'NOV': '11',
        'DEC': '12',
      };

      final month = monthNumbers[monthName] ?? '01';
      final year = shortOrLongYear.length == 2
          ? '20$shortOrLongYear'
          : shortOrLongYear;

      var hour24 = hour12;

      if (period == 'PM' && hour12 != 12) {
        hour24 += 12;
      }

      if (period == 'AM' && hour12 == 12) {
        hour24 = 0;
      }

      return '$day-$month-$year '
          '${hour24.toString().padLeft(2, '0')}:$minute:$second';
    }

    // ISO timestamp without timezone:
    // 2026-08-03T15:18:55
    final isoMatch = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[T\s]'
      r'(\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(raw);

    if (isoMatch != null) {
      return '${isoMatch.group(3)}-${isoMatch.group(2)}-'
          '${isoMatch.group(1)} ${isoMatch.group(4)}:'
          '${isoMatch.group(5)}:${isoMatch.group(6)}';
    }

    return raw;
  }

  int? _daysDiff(String value) {
    if (value.isEmpty) return null;
    try {
      final target = DateTime.parse(value);
      final today = DateTime.now();
      final base = DateTime(today.year, today.month, today.day);
      return target.difference(base).inDays;
    } catch (_) {
      return null;
    }
  }

  String _remarkText(String value) {
    final diffDays = _daysDiff(value);
    if (diffDays == null) return '-';
    if (diffDays < 0) {
      final n = diffDays.abs();
      return 'Expired $n day${n == 1 ? '' : 's'} ago';
    }
    if (diffDays == 0) return 'Expires today';
    if (diffDays <= 30) {
      return 'Expires in $diffDays day${diffDays == 1 ? '' : 's'}';
    }
    return 'Valid';
  }

  _RemarkStyle _remarkStyle(String value) {
    final diffDays = _daysDiff(value);
    if (diffDays == null) {
      return const _RemarkStyle(PdfColors.grey100, PdfColors.grey700);
    }
    if (diffDays < 0) {
      return const _RemarkStyle(PdfColors.red100, PdfColors.red700);
    }
    if (diffDays == 0 || diffDays <= 30) {
      return const _RemarkStyle(PdfColors.orange100, PdfColors.orange800);
    }
    return const _RemarkStyle(PdfColors.green100, PdfColors.green700);
  }

  String? _latestStageDate(List<CvpsHistoryEntry> history, String stage) {
    final matches = history
        .where((h) => h.stage.toUpperCase() == stage.toUpperCase())
        .toList();
    if (matches.isEmpty) return null;

    matches.sort((a, b) {
      final ta = DateTime.tryParse(a.createdAt)?.millisecondsSinceEpoch ?? 0;
      final tb = DateTime.tryParse(b.createdAt)?.millisecondsSinceEpoch ?? 0;
      return ta.compareTo(tb);
    });

    return matches.last.createdAt;
  }

  String _stageName(List<CvpsHistoryEntry> history, String stage) {
    final matches = history
        .where((h) => h.stage.toUpperCase() == stage.toUpperCase())
        .toList();
    if (matches.isEmpty) return '-';
    final name = matches.last.byName.trim();
    return name.isEmpty ? '-' : name;
  }

  String _stageEmpCode(List<CvpsHistoryEntry> history, String stage) {
    final matches = history
        .where((h) => h.stage.toUpperCase() == stage.toUpperCase())
        .toList();
    if (matches.isEmpty) return '-';
    final code = matches.last.byEmpCode.trim();
    return code.isEmpty ? '-' : code;
  }
}
