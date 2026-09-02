import 'dart:async';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_sheet.dart';
import 'admin_chat_list.dart';

class ChatBubbleButton extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String receiverId;
  final bool isAdmin;

  const ChatBubbleButton({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.receiverId,
    required this.isAdmin,
  });

  @override
  State<ChatBubbleButton> createState() => _ChatBubbleButtonState();
}

class _ChatBubbleButtonState extends State<ChatBubbleButton>
    with SingleTickerProviderStateMixin {
  int _userUnreadCount = 0;
  bool _isChatOpen = false;

  // -1 = not initialized yet, >=0 = baseline set
  int _seenAdminMsgCount = -1;

  bool _wsConnected = false;
  Timer? _connectionTimer;
  Timer? _backgroundPollTimer;

  StreamSubscription<ChatMessage>? _singleMessageSub;
  StreamSubscription<Set<String>>? _unreadSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _wsConnected = ChatService.isConnected;
    _startConnectionWatcher();

    if (widget.isAdmin) {
      ChatService.connect(
        userId: widget.currentUserId,
        receiverId: widget.currentUserId,
      );
      _unreadSub = ChatService.unreadSendersStream.listen((_) {
        if (mounted) setState(() {});
      });
    } else {
      ChatService.connect(
        userId: widget.currentUserId,
        receiverId: widget.receiverId,
      );
      _startUserUnreadWatcher();
    }
  }

  void _startConnectionWatcher() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final latest = ChatService.isConnected;
      if (latest != _wsConnected) setState(() => _wsConnected = latest);
    });
  }

  // ✅ Starts BOTH watchers immediately — no pre-fetch blocking
  void _startUserUnreadWatcher() {
    // ── WebSocket fast path ──────────────────────────────────────────────
    // Catches admin messages instantly when WS is alive
    // Only counts AFTER baseline is set (_seenAdminMsgCount >= 0)
    _singleMessageSub?.cancel();
    _singleMessageSub = ChatService.messageStream.listen((msg) {
      if (!mounted || _isChatOpen) return;
      if (_seenAdminMsgCount == -1) return; // baseline not ready yet

      final fromAdmin =
          msg.senderId == widget.receiverId &&
          msg.receiverId == widget.currentUserId;
      if (!fromAdmin) return;

      // Sync baseline so poll doesn't double-count this message
      _seenAdminMsgCount++;
      setState(() => _userUnreadCount++);
    });

    // ── Poll path ────────────────────────────────────────────────────────
    // ✅ Run IMMEDIATELY so baseline is set within milliseconds
    // Then every 3 seconds as reliable fallback
    _pollForNewMessages();
    _backgroundPollTimer?.cancel();
    _backgroundPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollForNewMessages(),
    );
  }

  // Single unified poll method — handles both init and delta detection
  Future<void> _pollForNewMessages() async {
    if (!mounted || _isChatOpen) return;

    try {
      final history = await ChatService.fetchHistoryFromServer(
        widget.currentUserId,
        widget.receiverId,
      );
      if (!mounted || _isChatOpen) return;

      final adminCount = history
          .where((m) => m.senderId == widget.receiverId)
          .length;

      if (_seenAdminMsgCount == -1) {
        // ✅ First successful fetch → set baseline, no badge shown
        _seenAdminMsgCount = adminCount;
        return;
      }

      if (adminCount > _seenAdminMsgCount) {
        final newCount = adminCount - _seenAdminMsgCount;
        _seenAdminMsgCount = adminCount;
        setState(() => _userUnreadCount += newCount);
      }
    } catch (_) {
      // Network error — will retry on next tick
    }
  }

  void _openChat() {
    if (widget.isAdmin) {
      setState(() => _isChatOpen = true);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        builder: (_) => AdminChatList(
          adminId: widget.currentUserId,
          adminName: widget.currentUserName,
        ),
      ).whenComplete(() {
        if (!mounted) return;
        setState(() => _isChatOpen = false);
        ChatService.clearAllUnread();
      });
    } else {
      setState(() {
        _userUnreadCount = 0;
        _isChatOpen = true;
      });

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        builder: (_) => ChatSheet(
          currentUserId: widget.currentUserId,
          currentUserName: widget.currentUserName,
          receiverId: widget.receiverId,
          receiverName: 'Admin Support',
        ),
      ).whenComplete(() {
        if (!mounted) return;
        setState(() => _isChatOpen = false);

        ChatService.connect(
          userId: widget.currentUserId,
          receiverId: widget.receiverId,
        );

        // ✅ Reset baseline so next immediate poll re-syncs correctly
        // Prevents double-counting messages seen inside ChatSheet
        _seenAdminMsgCount = -1;
        _pollForNewMessages(); // immediate re-sync after chat closes
      });
    }
  }

  bool get _showAdminBadge =>
      widget.isAdmin && ChatService.totalUnreadCount > 0;

  bool get _showUserBadge => !widget.isAdmin && _userUnreadCount > 0;

  bool get _showAnyBadge => _showAdminBadge || _showUserBadge;

  String get _badgeLabel {
    if (widget.isAdmin) {
      final count = ChatService.totalUnreadCount;
      return count > 99 ? '99+' : '$count';
    }
    return _userUnreadCount > 99 ? '99+' : '$_userUnreadCount';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _singleMessageSub?.cancel();
    _unreadSub?.cancel();
    _connectionTimer?.cancel();
    _backgroundPollTimer?.cancel();
    ChatService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          onPressed: _openChat,
          backgroundColor: const Color(0xFFB8962E),
          tooltip: widget.isAdmin ? 'Admin Inbox' : 'Chat with Admin',
          elevation: 6,
          child: Icon(
            widget.isAdmin ? Icons.forum : Icons.chat_bubble,
            color: Colors.white,
            size: 26,
          ),
        ),

        // 🔴 Pulsing red badge
        if (_showAnyBadge)
          Positioned(
            right: -6,
            top: -6,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    _badgeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // WebSocket connection dot
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _wsConnected ? Colors.greenAccent : Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
