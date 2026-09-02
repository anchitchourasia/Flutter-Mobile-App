import 'package:flutter/material.dart';
import '../data/notification_store.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  int _lastCount = 0;

  @override
  void initState() {
    super.initState();

    _lastCount = NotificationStore.unreadCount.value;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    NotificationStore.unreadCount.addListener(_onCountChanged);
  }

  void _onCountChanged() {
    final c = NotificationStore.unreadCount.value;
    final increased = c > _lastCount;
    _lastCount = c;

    if (increased && c > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.forward(from: 0);
      });
    }
  }

  Future<void> _openNotifications() async {
    // 1) user is going to view notifications => consider them read locally
    await NotificationStore.markAllAsReadLocal();

    // 2) open page
    await Navigator.pushNamed(context, '/notifications');

    // 3) when back, refresh again (safe)
    await NotificationStore.refreshUnreadCount();
  }

  @override
  void dispose() {
    NotificationStore.unreadCount.removeListener(_onCountChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationStore.unreadCount,
      builder: (context, count, _) {
        return ScaleTransition(
          scale: _scale,
          child: IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(
                Icons.notifications_none,
                color: Color.fromARGB(255, 20, 20, 20),
              ),
            ),
          ),
        );
      },
    );
  }
}
