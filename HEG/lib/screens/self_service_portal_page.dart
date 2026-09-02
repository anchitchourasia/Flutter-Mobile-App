import 'package:flutter/material.dart';
import '../widgets/notification_bell.dart';

class SelfServicePortalPage extends StatelessWidget {
  const SelfServicePortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self Service Portal'),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
