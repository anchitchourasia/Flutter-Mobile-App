import 'package:flutter/material.dart';
import '../../widgets/heg_app_bar.dart';
import '../vehicle_tracking_page.dart';
import 'approver_pending_page.dart';

class ApproverVehicleMenuPage extends StatelessWidget {
  const ApproverVehicleMenuPage({super.key});

  static const Color _bg1 = Color(0xFF0B1E3A);
  static const Color _bg2 = Color(0xFF0EA5A4);
  static const Color _panelBg = Colors.white;
  static const Color _panelBorder = Color(0xFFD9E2EC);
  static const Color _textPrimary = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HegAppBar(title: 'Vehicle Tracking'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bg1, _bg2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select View',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose between full pass registry or pending approvals.',
                  style: TextStyle(
                    color: Colors.white.withAlpha(210),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      _MenuCard(
                        title: 'Pass Registry',
                        subtitle:
                            'View all vehicle passes with search and filters',
                        icon: Icons.list_alt,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VehicleTrackingPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _MenuCard(
                        title: 'Pending for Approver',
                        subtitle:
                            'SUBMITTED / CONFIRMED passes awaiting your approval',
                        icon: Icons.verified_user, // ← FIXED
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ApproverPendingPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  static const Color _panelBg = ApproverVehicleMenuPage._panelBg;
  static const Color _panelBorder = ApproverVehicleMenuPage._panelBorder;
  static const Color _textPrimary = ApproverVehicleMenuPage._textPrimary;
  static const Color _textSecondary = ApproverVehicleMenuPage._textSecondary;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _panelBorder),
      ),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF1D4ED8), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
