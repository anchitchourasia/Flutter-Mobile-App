import 'package:flutter/material.dart';
import '../widgets/notification_bell.dart';

class LeaveApplyPage extends StatelessWidget {
  const LeaveApplyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // [web:2245]
      appBar: AppBar(
        title: const Text('Leave Apply'),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 15, 83, 185),
              Color.fromARGB(255, 27, 125, 138),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ), // [web:2222]
        child: const Center(
          child: Text('Coming soon', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
