/// CVPS Vehicle Permission list screen.
/// Mirrors vehicle-permission-list.ts and uses same Pass Registry UI style.
library;

import 'package:flutter/material.dart';

import '../../widgets/heg_app_bar.dart';
import '../../data/cvps_api.dart';
import '../../data/gate_log_api.dart';
import '../../data/session_store.dart';
import '../../models/cvps_request_item.dart';
// The list page no longer needs cvps_document, cvps_driver, cvps_history_entry,
// or cvps_pass_pdf_service, because PDF is generated from CvpsPassPage.
// Remove unused imports if they still exist.

class CvpsRequestsPage extends StatefulWidget {
  const CvpsRequestsPage({super.key});

  @override
  State<CvpsRequestsPage> createState() => _CvpsRequestsPageState();
}

class _CvpsRequestsPageState extends State<CvpsRequestsPage> {
  // API client to call CVPS backend.
  final CvpsApi api = CvpsApi();

  // Search text controller.
  final TextEditingController searchController = TextEditingController();

  // All rows from API.
  List<CvpsRequestItem> allRows = [];

  // Filtered rows after search/status filter.
  List<CvpsRequestItem> filteredRows = [];

  bool loading = true;
  bool hasError = false;
  String errorMessage = '';

  final Set<int> _gateActionLoading = <int>{};
  final Map<int, String> _lastGateActionByRequest = <int, String>{};

  // Filter state: search string and status.
  String searchText = '';
  String statusFilter = 'ALL';

  // Same gradient colors and panel style as Pass Registry.
  static const Color bg1 = Color(0xFF0B1E3A);
  static const Color bg2 = Color(0xFF0EA5A4);

  static const Color panelBg = Colors.white;
  static const Color panelBorder = Color(0xFFD9E2EC);
  static const Color textPrimary = Color(0xFF102A43);
  static const Color textSecondary = Color(0xFF627D98);
  static const Color accentTeal = Color(0xFF0EA5A4);
  static const Color accentDark = Color(0xFF0B1E3A);

  // Status filter options (same as web statusOptions).
  final List<String> statusOptions = const [
    'ALL',
    'SAVED',
    'CREATED',
    'CONFIRMED',
    'APPROVED',
    'REJECTED',
    'HOLD',
    'MODIFY',
    'SUBMITTED',
  ];

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// Loads all CVPS requests from backend and applies filters.
  Future<void> _loadRows() async {
    setState(() {
      loading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      final rows = await api.fetchAllRequests();

      if (!mounted) return;

      setState(() {
        allRows = rows;
        _applyFilters();
        loading = false;
      });

      await _loadGateActionsForApprovedRows(rows);
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _loadGateActionsForApprovedRows(
    List<CvpsRequestItem> rows,
  ) async {
    final approvedRows = rows.where(
      (row) => row.reqStatus.trim().toUpperCase() == 'APPROVED',
    );

    for (final row in approvedRows) {
      try {
        final lastAction = await GateLogApi.getLatestAction(row.requestNo);

        if (!mounted) return;

        setState(() {
          if (lastAction == null) {
            _lastGateActionByRequest.remove(row.requestNo);
          } else {
            _lastGateActionByRequest[row.requestNo] = lastAction;
          }
        });
      } catch (_) {
        if (!mounted) return;

        setState(() {
          // Unknown backend state: do not assume IN is safe.
          // Use a special state so neither IN nor OUT is displayed.
          _lastGateActionByRequest[row.requestNo] = 'UNKNOWN';
        });
      }
    }
  }

  /// Applies search + status filters to allRows to produce filteredRows.
  void _applyFilters() {
    final search = searchText.trim().toLowerCase();
    final statusUpper = statusFilter.trim().toUpperCase();

    filteredRows = allRows.where((row) {
      final rowStatus = row.reqStatus.trim().toUpperCase();

      // Status match: ALL or exact status.
      final matchesStatus = statusUpper == 'ALL' || rowStatus == statusUpper;

      // Search match: requestNo, contractorCode, vehicleNo, vehicleType,
      // natureOfJob, createdBy.
      final matchesSearch =
          search.isEmpty ||
          row.requestNo.toString().contains(search) ||
          row.contractorCode.toLowerCase().contains(search) ||
          row.vehicleNo.toLowerCase().contains(search) ||
          row.vehicleType.toLowerCase().contains(search) ||
          row.natureOfJob.toLowerCase().contains(search) ||
          row.createdBy.toLowerCase().contains(search);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  /// Called when search text changes.
  void _onSearchChange(String value) {
    setState(() {
      searchText = value;
      _applyFilters();
    });
  }

  /// Called when status dropdown changes.
  void _onStatusChange(String? value) {
    if (value == null) return;
    setState(() {
      statusFilter = value;
      _applyFilters();
    });
  }

  /// Returns human-readable label for a status.
  String _getStatusLabel(String status) {
    final normalized = status.trim().toUpperCase();
    switch (normalized) {
      case 'CREATED':
      case 'SUBMITTED':
        return 'Submitted';
      case 'SAVED':
        return 'Saved';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'HOLD':
        return 'Hold';
      case 'MODIFY':
        return 'MODIFY';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  /// Returns a color for status badge.
  Color _getStatusColor(String status) {
    final normalized = status.trim().toUpperCase();
    switch (normalized) {
      case 'SUBMITTED':
      case 'CREATED':
        return const Color(0xFF2563EB); // blue
      case 'CONFIRMED':
        return const Color(0xFF0891B2); // teal
      case 'APPROVED':
        return const Color(0xFF16A34A); // green
      case 'REJECTED':
        return const Color(0xFFDC2626); // red
      case 'HOLD':
      case 'MODIFY':
        return const Color(0xFFF59E0B); // amber
      case 'SAVED':
        return const Color(0xFF6B7280); // gray
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// When user taps View button on a row.
  /// Opens full CVPS form screen in view mode.
  void _viewRequest(CvpsRequestItem row) {
    Navigator.pushNamed(
      context,
      '/cvpsForm', // define this route in main.dart
      arguments: row.requestNo,
    );
  }

  /// Navigate to Pass UI screen for this request.
  /// From that screen user can view pass and click Download/Print.
  void _viewPass(CvpsRequestItem row) {
    Navigator.pushNamed(
      context,
      '/cvpsPass', // define this route in main.dart
      arguments: row.requestNo,
    );
  }

  Future<void> _recordGateAction(CvpsRequestItem row, String action) async {
    final normalizedAction = action.trim().toUpperCase();

    if (normalizedAction != 'IN' && normalizedAction != 'OUT') {
      return;
    }

    if (row.reqStatus.trim().toUpperCase() != 'APPROVED') {
      return;
    }

    if (_gateActionLoading.contains(row.requestNo)) {
      return;
    }

    final enterBy = SessionStore.currentUser?.ec.trim() ?? '';

    if (enterBy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB91C1C),
          content: Text('Logged-in employee code is missing.'),
        ),
      );
      return;
    }

    setState(() {
      _gateActionLoading.add(row.requestNo);
    });

    try {
      await GateLogApi.saveAction(
        permissionNo: row.requestNo,
        action: normalizedAction,
        enterBy: enterBy,
      );

      if (!mounted) return;

      setState(() {
        _lastGateActionByRequest[row.requestNo] = normalizedAction;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: normalizedAction == 'IN'
              ? const Color(0xFF15803D)
              : const Color(0xFFB91C1C),
          content: Text(
            'Gate $normalizedAction saved to dummy database for '
            'Permission No. ${row.requestNo}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB91C1C),
          content: Text('Could not save Gate $normalizedAction: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _gateActionLoading.remove(row.requestNo);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HegAppBar(title: 'Permission Requests'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [bg1, bg2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : hasError
            ? ErrorView(message: errorMessage, onRetry: _loadRows)
            : RefreshIndicator(
                color: accentTeal,
                onRefresh: _loadRows,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  children: [
                    _buildSummaryPanel(),
                    const SizedBox(height: 10),
                    _buildControlPanel(),
                    const SizedBox(height: 12),
                    if (filteredRows.isEmpty)
                      const EmptyState()
                    else
                      ...filteredRows.map(_buildRequestCard),
                  ],
                ),
              ),
      ),
    );
  }

  /// Summary at top: shows total & filtered counts.
  Widget _buildSummaryPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Permission Requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Contractor vehicle permissions with search and filters',
            style: TextStyle(
              color: Colors.white.withAlpha(185),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryStat('Total', allRows.length.toString())),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryStat('Filtered', filteredRows.length.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(165),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// Search + status filter panel, same style as Pass Registry.
  Widget _buildControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: panelBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: _onSearchChange,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: textSecondary,
              ),
              hintText: 'Search request no, contractor, vehicle, status...',
              hintStyle: const TextStyle(fontSize: 13, color: textSecondary),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: panelBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: accentTeal, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: statusOptions.contains(statusFilter)
                ? statusFilter
                : 'ALL',
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Status',
              labelStyle: const TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: panelBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: accentTeal, width: 1.2),
              ),
            ),
            items: statusOptions
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _onStatusChange,
          ),
        ],
      ),
    );
  }

  /// Builds a single CVPS request card.
  /// Includes a View button and a View Pass button (when Approved).
  Widget _buildRequestCard(CvpsRequestItem row) {
    final badgeColor = _getStatusColor(row.reqStatus);

    final isApproved = row.reqStatus.trim().toUpperCase() == 'APPROVED';

    final isGateActionLoading = _gateActionLoading.contains(row.requestNo);

    final lastGateAction = _lastGateActionByRequest[row.requestNo];
    final showInButton = lastGateAction == null || lastGateAction == 'OUT';
    final showOutButton = lastGateAction == 'IN';
    final gateStateUnavailable = lastGateAction == 'UNKNOWN';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: panelBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 56,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.vehicleNo.isEmpty ? '-' : row.vehicleNo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          _topMeta('Req No', row.requestNo.toString()),
                          _topMeta(
                            'Contractor',
                            row.contractorCode.isEmpty
                                ? '-'
                                : row.contractorCode,
                          ),
                          _topMeta(
                            'Type',
                            row.vehicleType.isEmpty ? '-' : row.vehicleType,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: badgeColor.withAlpha(40)),
                  ),
                  child: Text(
                    _getStatusLabel(row.reqStatus),
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: panelBorder),
            const SizedBox(height: 12),
            _dataLine('Nature of Job', row.natureOfJob),
            _dataLine('Permission To', row.permissionTo),
            _dataLine('Created By', row.createdBy),
            _dataLine('Created Date', row.createdDate),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statBox('Personnel', row.personnelCount.toString()),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statBox(
                    'Documents',
                    row.vehicleDocumentCount.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // View always appears.
            // View Pass, IN, and OUT appear only for APPROVED requests.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionButton(
                  label: 'View',
                  icon: Icons.visibility_outlined,
                  foreground: accentDark,
                  background: const Color(0xFFEAF2FF),
                  onTap: () => _viewRequest(row),
                ),
                if (isApproved)
                  _actionButton(
                    label: 'View Pass',
                    icon: Icons.picture_as_pdf_outlined,
                    foreground: const Color(0xFF16A34A),
                    background: const Color(0xFFEFFDF5),
                    onTap: () => _viewPass(row),
                  ),
                if (isApproved && !gateStateUnavailable && showInButton)
                  _actionButton(
                    label: isGateActionLoading ? 'Please wait...' : 'IN',
                    icon: isGateActionLoading
                        ? Icons.hourglass_top
                        : Icons.login,
                    foreground: const Color(0xFF15803D),
                    background: const Color(0xFFDCFCE7),
                    onTap: isGateActionLoading
                        ? () {}
                        : () => _recordGateAction(row, 'IN'),
                  ),

                if (isApproved && !gateStateUnavailable && showOutButton)
                  _actionButton(
                    label: isGateActionLoading ? 'Please wait...' : 'OUT',
                    icon: isGateActionLoading
                        ? Icons.hourglass_top
                        : Icons.logout,
                    foreground: const Color(0xFFB91C1C),
                    background: const Color(0xFFFEE2E2),
                    onTap: isGateActionLoading
                        ? () {}
                        : () => _recordGateAction(row, 'OUT'),
                  ),
              ],
            ),

            if (isApproved && gateStateUnavailable) ...[
              const SizedBox(height: 10),
              _gateStateUnavailableStatus(),
            ] else if (isApproved && lastGateAction != null) ...[
              const SizedBox(height: 10),
              _localGateActionStatus(lastGateAction),
            ],
          ],
        ),
      ),
    );
  }

  Widget _gateStateUnavailableStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC2410C)),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Gate status could not be verified. Pull down to refresh.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC2410C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _localGateActionStatus(String action) {
    final isIn = action == 'IN';

    final foreground = isIn ? const Color(0xFF15803D) : const Color(0xFFB91C1C);

    final background = isIn ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);

    final border = isIn ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(isIn ? Icons.login : Icons.logout, size: 16, color: foreground),
          const SizedBox(width: 7),
          Text(
            'Gate Action: $action',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
          const Spacer(),
          const Text(
            'Saved',
            style: TextStyle(
              fontSize: 10,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topMeta(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12,
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color foreground,
    required Color background,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: foreground.withAlpha(28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple error view (reuse style from Pass Registry).
class ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
                'Failed to load CVPS requests',
                style: TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF627D98),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => onRetry(),
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

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E2EC)),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 42, color: Color(0xFF9FB3C8)),
          SizedBox(height: 10),
          Text(
            'No permission requests found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF102A43),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try changing search text or filter values.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF627D98),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
