import 'package:flutter/material.dart';
import '../widgets/notification_bell.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: const Center(child: Text('Settings page (UI coming)')),
    );
  }
}
