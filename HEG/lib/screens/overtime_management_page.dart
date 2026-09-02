import 'package:flutter/material.dart';
import '../widgets/notification_bell.dart';

class OvertimeManagementPage extends StatelessWidget {
  const OvertimeManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overtime Management'),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
