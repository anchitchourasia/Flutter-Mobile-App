import 'package:flutter/material.dart';
import 'notification_bell.dart';

class HegAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;

  const HegAppBar({super.key, required this.title, this.showBack = true});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBack,
      title: Text(title),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      titleTextStyle: const TextStyle(
        color: Color(0xFF1F2937),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      actions: const [_BellPill(), SizedBox(width: 8)],
    );
  }
}

class _BellPill extends StatelessWidget {
  const _BellPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const NotificationBell(),
    );
  }
}
