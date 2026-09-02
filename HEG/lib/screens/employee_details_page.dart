import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../widgets/notification_bell.dart';

class EmployeeDetailsPage extends StatelessWidget {
  const EmployeeDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final employee = ModalRoute.of(context)!.settings.arguments as Employee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Details'),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _row('Employee ID', employee.id),
                _row('Department', employee.department),
                _row('Designation', employee.designation),
                _row('Join Date', employee.joinDate),
                const Divider(height: 24),
                _row('Mobile', employee.phone),
                _row('Email', employee.email),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Text(':  '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
