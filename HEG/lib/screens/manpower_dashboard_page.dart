import 'package:flutter/material.dart';
import '../widgets/notification_bell.dart';

class ManpowerDashboardPage extends StatelessWidget {
  const ManpowerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manpower Dashboard'),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
