import 'dart:async';
import 'package:flutter/material.dart';

import '../widgets/notification_bell.dart';
import '../widgets/chat_bubble_button.dart';
import '../data/session_store.dart';
import '../data/notification_store.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const _bg1 = Color(0xFF0B1220);
  static const _bg2 = Color(0xFF0EA5A4);
  static const Color _accentBlue = Color(0xFF2563EB);

  static const List<_MenuItem> _items = [
    _MenuItem('My Profile', Icons.person, '/profile'),
    _MenuItem('Pass System', Icons.directions_car, '/vehicleTracking'),
    _MenuItem('Permission System', Icons.receipt_long, '/cvpsRequests'),

    // Below items will stay visible but non-clickable
    _MenuItem('Attendance', Icons.event_available, '/attendance'),
    _MenuItem('Employees', Icons.groups_2, '/employees'),
    _MenuItem('Settings', Icons.settings, '/settings'),
    _MenuItem('Insurance Upload', Icons.upload_file, '/insuranceUpload'),
    _MenuItem('Leave Apply', Icons.event_note, '/leaveApply'),
    _MenuItem('Self Service Portal', Icons.support_agent, '/selfServicePortal'),
    _MenuItem('Overtime Management', Icons.timelapse, '/overtimeManagement'),
    _MenuItem(
      'Manpower Dashboard',
      Icons.dashboard_customize,
      '/manpowerDashboard',
    ),
    _MenuItem('Applicants', Icons.badge, '/applicants'),
  ];

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationStore.refreshUnreadCount();
      _startPolling();
    });
  }

  void _startPolling() {
    _notifTimer?.cancel();
    _notifTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      NotificationStore.refreshUnreadCount();
    });
  }

  void _stopPolling() {
    _notifTimer?.cancel();
    _notifTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationStore.refreshUnreadCount();
      _startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await SessionStore.logout();
    NotificationStore.resetLocal();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Current session user
    final String currentUserId = SessionStore.employeeId ?? 'emp_001';
    final String currentUserName = SessionStore.employeeName ?? 'Employee';

    // ✅ Role check (set this in SessionStore)
    final bool isAdmin = SessionStore.isAdmin ?? (currentUserId == 'admin');

    // ✅ For employee: receiver is admin
    // ✅ For admin: receiver can be 'all' (button opens AdminChatList anyway)
    final String receiverId = isAdmin ? 'all' : 'admin';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('HEG HRMS'),
        backgroundColor: const Color.fromARGB(255, 235, 240, 239),
        elevation: 0,
        actions: const [NotificationBell()],
      ),

      // ✅ Chat FAB
      floatingActionButton: ChatBubbleButton(
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        receiverId: receiverId,
        isAdmin: isAdmin,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [HomePage._bg1, HomePage._bg2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Color.fromARGB(255, 248, 248, 248),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose an option to continue',
                  style: TextStyle(
                    color: const Color.fromARGB(
                      255,
                      249,
                      249,
                      250,
                    ).withAlpha((0.80 * 255).round()),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    itemCount: HomePage._items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                    itemBuilder: (context, index) {
                      final item = HomePage._items[index];

                      // Only these routes should be clickable
                      final bool isEnabled =
                          item.route == '/profile' ||
                          item.route == '/vehicleTracking' ||
                          item.route == '/cvpsRequests';

                      return _MenuCard(
                        title: item.title,
                        icon: item.icon,
                        isEnabled: isEnabled,
                        onTap: isEnabled
                            ? () => Navigator.pushNamed(context, item.route)
                            : null, // disabled
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: HomePage._bg2),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('My Profile'),
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────

class _MenuItem {
  final String title;
  final IconData icon;
  final String route;
  const _MenuItem(this.title, this.icon, this.route);
}

class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isEnabled;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.onTap,
    required this.isEnabled,
  });

  static const Color _accentBlue = HomePage._accentBlue;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(18));

    final Color borderColor = isEnabled ? Colors.black26 : Colors.black12;
    final Color titleColor = isEnabled
        ? _accentBlue
        : _accentBlue.withOpacity(0.4);
    final Color iconBg = _accentBlue.withAlpha(
      isEnabled ? (0.12 * 255).round() : (0.05 * 255).round(),
    );
    final Color iconColor = isEnabled
        ? _accentBlue
        : _accentBlue.withOpacity(0.4);
    final Color subtitleColor = _accentBlue.withAlpha(
      isEnabled ? (0.75 * 255).round() : (0.30 * 255).round(),
    );

    return Card(
      color: Colors.white,
      elevation: isEnabled ? 6 : 2,
      shadowColor: borderColor,
      shape: const RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: isEnabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEnabled ? 'Tap to open' : 'Coming soon',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subtitleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
