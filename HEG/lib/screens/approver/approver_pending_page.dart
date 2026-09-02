// lib/screens/approver/approver_pending_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/pass_registry_api.dart';
import '../../models/pass_registry_item.dart';
import '../../widgets/heg_app_bar.dart';
import '../pass_entry/pass_entry_page.dart';

class ApproverPendingPage extends StatefulWidget {
  const ApproverPendingPage({super.key});

  @override
  State<ApproverPendingPage> createState() => _ApproverPendingPageState();
}

class _ApproverPendingPageState extends State<ApproverPendingPage> {
  final PassRegistryApi api = PassRegistryApi();
  final TextEditingController searchController = TextEditingController();

  List<PassRegistryItem> allPasses = [];
  List<PassRegistryItem> pendingPasses = [];

  bool loading = true;
  bool hasError = false;
  String errorMessage = '';

  Timer? pollTimer;
  DateTime? lastUpdated;

  String searchText = '';

  int currentPage = 1;
  int pageSize = 10;

  static const Duration pollInterval = Duration(seconds: 30);

  static const Color bg1 = Color(0xFF0B1E3A);
  static const Color bg2 = Color(0xFF0EA5A4);

  static const Color panelBg = Colors.white;
  static const Color panelBorder = Color(0xFFD9E2EC);
  static const Color textPrimary = Color(0xFF102A43);
  static const Color textSecondary = Color(0xFF627D98);
  static const Color accentTeal = Color(0xFF0EA5A4);
  static const Color accentDark = Color(0xFF0B1E3A);

  @override
  void initState() {
    super.initState();
    loadPasses();
    startPolling();
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void startPolling() {
    pollTimer?.cancel();
    pollTimer = Timer.periodic(pollInterval, (_) {
      if (!mounted) return;
      loadPasses(silent: true);
    });
  }

  Future<void> loadPasses({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
        hasError = false;
        errorMessage = '';
      });
    }

    try {
      final rows = await api.fetchPassRegistry();
      if (!mounted) return;
      setState(() {
        allPasses = rows;
        // Filter only SUBMITTED or CONFIRMED passes (pending for approver)
        pendingPasses = rows.where((row) {
          final status = row.status.trim().toUpperCase();
          return status == 'SUBMITTED' || status == 'CONFIRMED';
        }).toList();
        lastUpdated = DateTime.now();
        applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          hasError = true;
          errorMessage = e.toString();
        });
      }
    } finally {
      if (!mounted) return;
      if (!silent) {
        setState(() => loading = false);
      }
    }
  }

  void applyFilters() {
    // Apply search filter
    pendingPasses = allPasses.where((row) {
      // first filter by pending status
      final status = row.status.trim().toUpperCase();
      final isPending = status == 'SUBMITTED' || status == 'CONFIRMED';
      if (!isPending) return false;

      // then by search text
      return row.matchesSearch(searchText);
    }).toList();

    final totalPagesLocal = (pendingPasses.length / pageSize).ceil();

    // Clamp currentPage into a valid range
    if (totalPagesLocal <= 0) {
      currentPage = 1;
    } else {
      if (currentPage < 1) currentPage = 1;
      if (currentPage > totalPagesLocal) currentPage = totalPagesLocal;
    }
  }

  List<PassRegistryItem> get pagedPasses {
    if (pendingPasses.isEmpty) return [];

    final totalPagesLocal = (pendingPasses.length / pageSize).ceil();
    // Safe page between 1 and totalPagesLocal
    final safePage = currentPage < 1
        ? 1
        : (currentPage > totalPagesLocal ? totalPagesLocal : currentPage);

    final start = (safePage - 1) * pageSize;
    var end = start + pageSize;
    if (start >= pendingPasses.length) return [];
    if (end > pendingPasses.length) end = pendingPasses.length;

    return pendingPasses.sublist(start, end);
  }

  int get totalPages {
    final total = (pendingPasses.length / pageSize).ceil();
    return total == 0 ? 1 : total;
  }

  void onSearch(String value) {
    setState(() {
      searchText = value;
      currentPage = 1;
      applyFilters();
    });
  }

  void changePage(int page) {
    if (page < 1 || page > totalPages) return;
    setState(() => currentPage = page);
  }

  String formatDateString(String date) {
    if (date.trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(date);
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return '$dd/$mm/$yyyy';
    } catch (_) {
      return date;
    }
  }

  void reviewPass(PassRegistryItem row) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PassEntryPage(
        registryId: row.passId,
        isViewMode: false,
        isApproverMode: true, // approver review mode
      ),
    );
    await loadPasses(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HegAppBar(title: 'Pending for Approver'),
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
            ? ErrorView(message: errorMessage, onRetry: loadPasses)
            : RefreshIndicator(
                color: accentTeal,
                onRefresh: loadPasses,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  children: [
                    _buildSummaryPanel(),
                    const SizedBox(height: 10),
                    _buildControlPanel(),
                    const SizedBox(height: 12),
                    if (pagedPasses.isEmpty)
                      const EmptyState()
                    else
                      ...pagedPasses.map(_buildPassCard),
                    const SizedBox(height: 12),
                    _buildPaginationPanel(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryPanel() {
    final lastUpdatedText = lastUpdated == null
        ? '-'
        : '${lastUpdated!.hour.toString().padLeft(2, '0')}:${lastUpdated!.minute.toString().padLeft(2, '0')}';

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
            'Pending for Approval',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Passes awaiting approver review',
            style: TextStyle(
              color: Colors.white.withAlpha(185),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryStat('Total', pendingPasses.length.toString()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryStat('Page', '$currentPage of $totalPages'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Last updated $lastUpdatedText',
                style: TextStyle(
                  color: Colors.white.withAlpha(190),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
      child: TextField(
        controller: searchController,
        onChanged: onSearch,
        style: const TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20, color: textSecondary),
          hintText: 'Search pass id, employee, contractor, vehicle...',
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
    );
  }

  Widget _buildPassCard(PassRegistryItem row) {
    final badgeColor = const Color(0xFFD97706); // Warning color for pending

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
                          _topMeta(
                            'Pass',
                            row.passNo.isEmpty ? '-' : row.passNo,
                          ),
                          _topMeta(
                            'Gate',
                            row.gateNo.isEmpty ? '-' : row.gateNo,
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
                    row.status.isEmpty ? 'PENDING' : row.status,
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
            _dataLine('Employee', row.name),
            _dataLine('EC No', row.employeeNo),
            _dataLine('Emp Type', row.empType),
            _dataLine('Department', row.deptName),
            if (row.contractorName.isNotEmpty)
              _dataLine('Contractor', row.contractorName),
            const SizedBox(height: 12),
            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionButton(
                  label: 'Review',
                  icon: Icons.visibility_outlined,
                  foreground: accentDark,
                  background: const Color(0xFFEAF2FF),
                  onTap: () => reviewPass(row),
                ),
              ],
            ),
          ],
        ),
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
            width: 92,
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

  Widget _dateBox(String label, String value) {
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

  Widget _buildPaginationPanel() {
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Rows per page',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                children: [10, 20, 50].map((size) {
                  final selected = pageSize == size;
                  return ChoiceChip(
                    label: Text(
                      size.toString(),
                      style: TextStyle(
                        color: selected ? Colors.white : textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selected: selected,
                    selectedColor: accentTeal,
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: panelBorder),
                    onSelected: (_) {
                      setState(() {
                        pageSize = size;
                        currentPage = 1;
                        applyFilters();
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: currentPage > 1
                    ? () => changePage(currentPage - 1)
                    : null,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: panelBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Prev'),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Page $currentPage of $totalPages',
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: currentPage < totalPages
                    ? () => changePage(currentPage + 1)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================== ERROR VIEW ==================
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

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
                'Failed to load pass registry',
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
                onPressed: onRetry,
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

// ================== EMPTY STATE ==================
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
            'No pending passes',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF102A43),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'All passes have been reviewed.',
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
