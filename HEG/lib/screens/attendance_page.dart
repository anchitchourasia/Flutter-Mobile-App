import 'package:flutter/material.dart';
import '../widgets/notification_bell.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  static const Color _bg1 = Color(0xFF0B1220);
  static const Color _bg2 = Color(0xFF0EA5A4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // lets gradient go behind AppBar
      backgroundColor: const Color.fromARGB(
        255,
        238,
        234,
        234,
      ), // important when using gradient
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: const [NotificationBell(), SizedBox(width: 8)],
        backgroundColor: const Color.fromARGB(255, 238, 234, 234),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 12, 27, 49),
              Color.fromARGB(255, 24, 118, 131),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: const [
                _AttendanceTile(
                  title: 'Today',
                  subtitle: 'Status: Present (dummy)',
                  icon: Icons.today,
                ),
                _AttendanceTile(
                  title: 'This month',
                  subtitle: 'Working days: 22 • Present: 20 (dummy)',
                  icon: Icons.calendar_month,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _AttendanceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
