import 'package:flutter/material.dart';

import 'package:hive_flutter/hive_flutter.dart'; // ✅ add for offline cache (Hive)
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'data/insurance_db.dart';
import 'data/session_store.dart'; // ✅ add this
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/attendance_page.dart';
import 'screens/employees_page.dart';
import 'screens/employee_details_page.dart';
import 'screens/settings_page.dart';
import 'screens/profile_page.dart';

// New module screens
import 'screens/insurance_upload_page.dart';
import 'screens/leave_apply_page.dart';
import 'screens/vehicle_tracking_page.dart';
import 'screens/self_service_portal_page.dart';
import 'screens/overtime_management_page.dart';
import 'screens/manpower_dashboard_page.dart';
import 'screens/notifications_page.dart';
import 'screens/approver/approver_menu_page.dart';
import 'screens/cvps/cvps_requests_page.dart';
import 'screens/cvps/cvps_form_page.dart';
// ✅ NEW: Applicants page
import 'screens/applicants_page.dart';
import 'screens/cvps/cvps_pass_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: 'assets/.env');

  // DB init
  await InsuranceDb.database;

  // ✅ Load saved session (remember login)
  await SessionStore.loadFromDisk();

  // ✅ Offline cache init (Hive)
  await Hive.initFlutter();
  await Hive.openBox('cache');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final startRoute = SessionStore.isLoggedIn ? '/home' : '/login';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: startRoute, // ✅ dynamic initial route
      routes: <String, WidgetBuilder>{
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/attendance': (_) => const AttendancePage(),
        '/employees': (_) => const EmployeesPage(),
        '/employeeDetails': (_) => const EmployeeDetailsPage(),
        '/settings': (_) => const SettingsPage(),
        '/profile': (_) => const ProfilePage(),
        '/cvpsRequests': (context) => const CvpsRequestsPage(),
        '/cvpsForm': (context) => const CvpsFormPage(), // to be implemented
        '/cvpsPass': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          final requestNo = args as int;
          return CvpsPassPage(requestNo: requestNo);
        },

        '/insuranceUpload': (_) => InsuranceUploadPage(),
        '/leaveApply': (_) => LeaveApplyPage(),
        '/vehicleTracking': (context) {
          final role = SessionStore.currentUser?.role;
          if (role == 'APPROVER') {
            return const ApproverVehicleMenuPage();
          }
          return const VehicleTrackingPage();
        },
        '/selfServicePortal': (_) => SelfServicePortalPage(),
        '/overtimeManagement': (_) => OvertimeManagementPage(),
        '/manpowerDashboard': (_) => ManpowerDashboardPage(),
        '/notifications': (_) => NotificationsPage(),

        // ✅ NEW route
        '/applicants': (_) => const ApplicantsPage(),
      },
    );
  }
}
