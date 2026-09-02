import 'package:flutter/material.dart';
import '../data/dummy_employees.dart';
import '../models/employee.dart';
import '../widgets/notification_bell.dart';

class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Important so the gradient behind can be seen.
      backgroundColor: Colors.transparent, // [web:2225][web:2220]
      appBar: AppBar(
        title: const Text('Employees'),
        actions: const [NotificationBell(), SizedBox(width: 8)],
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
        ), // [web:2222]
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: dummyEmployees.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final Employee e = dummyEmployees[index];

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(e.name.isNotEmpty ? e.name[0] : '?'),
                ),
                title: Text(e.name),
                subtitle: Text('${e.id} • ${e.department}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/employeeDetails',
                    arguments: e,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
