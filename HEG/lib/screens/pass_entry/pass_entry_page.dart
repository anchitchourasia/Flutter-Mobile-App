import 'package:flutter/material.dart';
import 'pass_entry_form.dart';

class PassEntryPage extends StatefulWidget {
  final int? registryId;
  final bool isViewMode;
  final bool isApproverMode;

  const PassEntryPage({
    super.key,
    this.registryId,
    this.isViewMode = false,
    this.isApproverMode = false,
  });

  @override
  State<PassEntryPage> createState() => _PassEntryPageState();
}

class _PassEntryPageState extends State<PassEntryPage> {
  String get _title {
    if (widget.isApproverMode) return 'Pass Approval Form';
    if (widget.isViewMode) return 'Pass View Form';
    return 'Pass Entry Form';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F4F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFBCCCDC),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildTopBar(),
          Expanded(
            child: PassEntryForm(
              registryId: widget.registryId,
              isViewMode: widget.isViewMode,
              isApproverMode: widget.isApproverMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.badge, color: Color(0xFF1D6FD8), size: 22),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F2040),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: const Text(
              'General Details',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D6FD8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF94A3B8)),
              ),
              child: Text(
                widget.registryId != null
                    ? 'ID : ${widget.registryId}'
                    : 'Request ID generates on Save',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: widget.registryId != null
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: widget.registryId != null
                      ? const Color(0xFF1558B0)
                      : const Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
