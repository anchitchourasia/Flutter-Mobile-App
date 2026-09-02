class Employee {
  final String id;
  final String name;
  final String department;
  final String designation;
  final String phone;
  final String email;
  final String joinDate;

  const Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.designation,
    required this.phone,
    required this.email,
    required this.joinDate,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      designation: (json['designation'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      joinDate: (json['joinDate'] ?? '').toString(),
    );
  }
}
