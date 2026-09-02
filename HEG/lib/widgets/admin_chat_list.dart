import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/chat_service.dart';
import 'chat_sheet.dart';

class AdminChatList extends StatefulWidget {
  final String adminId;
  final String adminName;

  const AdminChatList({
    super.key,
    required this.adminId,
    required this.adminName,
  });

  @override
  State<AdminChatList> createState() => _AdminChatListState();
}

class _AdminChatListState extends State<AdminChatList> {
  final Map<String, _Conversation> _byUserId = {};
  List<_Conversation> _sorted = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _adminManualOnline = false;

  Timer? _refreshTimer;
  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<Set<String>>? _unreadSub;

  String? _openChatUserId;

  @override
  void initState() {
    super.initState();

    ChatService.connect(userId: widget.adminId, receiverId: widget.adminId);

    _loadAvailability();
    _loadConversations();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _loadAvailability(silent: true);
      await _loadConversations(silent: true);
    });

    _messageSub = ChatService.messageStream.listen(_onRealtimeMessage);

    _unreadSub = ChatService.unreadSendersStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _unreadSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onRealtimeMessage(ChatMessage msg) {
    if (!mounted) return;

    final involvesAdmin =
        msg.senderId == widget.adminId || msg.receiverId == widget.adminId;
    if (!involvesAdmin) return;

    final otherUserId = msg.senderId == widget.adminId
        ? msg.receiverId
        : msg.senderId;
    if (otherUserId.isEmpty || otherUserId == widget.adminId) return;

    final otherName = (msg.senderId == widget.adminId)
        ? (_byUserId[otherUserId]?.senderName ?? 'Employee')
        : (msg.senderName.trim().isEmpty ? 'Employee' : msg.senderName.trim());

    final existing = _byUserId[otherUserId];
    if (existing == null) {
      _byUserId[otherUserId] = _Conversation(
        userId: otherUserId,
        senderName: otherName,
        lastMessage: msg.message,
        lastTime: msg.timestamp,
      )..touch();
    } else {
      existing.senderName = existing.senderName.trim().isNotEmpty
          ? existing.senderName
          : otherName;
      existing.lastMessage = msg.message;
      existing.lastTime = msg.timestamp;
      existing.touch();
    }

    setState(_resort);
  }

  Future<void> _loadAvailability({bool silent = false}) async {
    try {
      final url = Uri.parse(
        '${ChatService.baseUrl}/api/chat/availability/${widget.adminId}',
      );

      final headers = <String, String>{
        'Accept': 'application/json',
        if ((ChatService.apiKey ?? '').trim().isNotEmpty)
          ChatService.apiKeyHeaderName: ChatService.apiKey!.trim(),
      };

      final res = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _adminManualOnline = map['manualOnline'] == true;
        });
      }
    } catch (_) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load admin availability')),
        );
      }
    }
  }

  Future<void> _toggleAdminAvailability() async {
    final newStatus = !_adminManualOnline;

    try {
      final url = Uri.parse(
        '${ChatService.baseUrl}/api/chat/availability/${widget.adminId}?available=$newStatus',
      );

      final headers = <String, String>{
        'Accept': 'application/json',
        if ((ChatService.apiKey ?? '').trim().isNotEmpty)
          ChatService.apiKeyHeaderName: ChatService.apiKey!.trim(),
      };

      final res = await http
          .post(url, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() => _adminManualOnline = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'You are now visible as online'
                  : 'You are now visible as offline',
            ),
            backgroundColor: newStatus ? Colors.green : Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update status')));
    }
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    if (silent && mounted) setState(() => _isRefreshing = true);

    try {
      final url = Uri.parse(
        '${ChatService.baseUrl}/api/chat/conversations/${widget.adminId}',
      );

      final headers = <String, String>{
        'Accept': 'application/json',
        if ((ChatService.apiKey ?? '').trim().isNotEmpty)
          ChatService.apiKeyHeaderName: ChatService.apiKey!.trim(),
      };

      final res = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final seen = <String>{};

        for (final item in data) {
          final map = Map<String, dynamic>.from(item as Map);

          final userId = (map['userId'] ?? '').toString().trim();
          if (userId.isEmpty || userId == widget.adminId) continue;

          final senderName = (map['senderName'] ?? 'Employee')
              .toString()
              .trim();
          final lastMessage = (map['lastMessage'] ?? '').toString().trim();
          final lastTime = (map['lastTime'] ?? '').toString().trim();

          seen.add(userId);

          final existing = _byUserId[userId];
          if (existing == null) {
            _byUserId[userId] = _Conversation(
              userId: userId,
              senderName: senderName.isEmpty ? 'Employee' : senderName,
              lastMessage: lastMessage,
              lastTime: lastTime,
            )..touch();
          } else {
            if (existing.senderName.trim().isEmpty &&
                senderName.trim().isNotEmpty) {
              existing.senderName = senderName;
            }
            existing.lastMessage = lastMessage;
            existing.lastTime = lastTime;
            existing.touch();
          }
        }

        _byUserId.removeWhere((userId, _) => !seen.contains(userId));
        setState(_resort);
      }
    } catch (_) {
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _resort() {
    _sorted = _byUserId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void _openChat(_Conversation conv) {
    setState(() => _openChatUserId = conv.userId);
    ChatService.markAsRead(conv.userId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => ChatSheet(
        currentUserId: widget.adminId,
        currentUserName: widget.adminName,
        receiverId: conv.userId,
        receiverName: conv.senderName.isEmpty ? 'Employee' : conv.senderName,
      ),
    ).whenComplete(() async {
      if (!mounted) return;
      setState(() => _openChatUserId = null);
      await _loadConversations(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _header(context),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D4C5E)),
                  )
                : _sorted.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mark_chat_unread_outlined,
                          size: 52,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadConversations(),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _sorted.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (_, i) {
                        final conv = _sorted[i];
                        final title = conv.senderName.isNotEmpty
                            ? conv.senderName
                            : conv.userId;
                        final firstLetter = title.isNotEmpty
                            ? title.substring(0, 1).toUpperCase()
                            : 'E';

                        final hasUnread = ChatService.hasUnread(conv.userId);
                        final unreadPreview = ChatService.getUnreadPreview(
                          conv.userId,
                        );

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF0D4C5E),
                                child: Text(
                                  firstLetter,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              if (hasUnread)
                                Positioned(
                                  right: -3,
                                  top: -3,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.red,
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // ✅ OVERFLOW FIX — Flexible + mainAxisSize.min
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: hasUnread
                                        ? FontWeight.w900
                                        : FontWeight.bold,
                                    fontSize: 15,
                                    color: hasUnread
                                        ? Colors.black
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              if (hasUnread) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            hasUnread && unreadPreview.isNotEmpty
                                ? unreadPreview
                                : conv.lastMessage.isEmpty
                                ? 'Tap to open chat'
                                : conv.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread
                                  ? Colors.black87
                                  : Colors.grey[600],
                              fontSize: 13,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (conv.lastTime.isNotEmpty)
                                Text(
                                  conv.lastTime,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasUnread ? Colors.red : Colors.grey,
                                    fontWeight: hasUnread
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              if (_openChatUserId == conv.userId)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Open',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF0D4C5E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () => _openChat(conv),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final totalUnread = ChatService.totalUnreadCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0D4C5E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFB8962E),
            child: Icon(Icons.admin_panel_settings, color: Colors.white),
          ),
          const SizedBox(width: 10),
          // ✅ Expanded wraps the title+badge column — prevents header overflow too
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Flexible(
                  child: Text(
                    'Employee Messages',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                if (totalUnread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.red,
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      totalUnread > 99 ? '99+' : '$totalUnread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleAdminAvailability,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _adminManualOnline ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _adminManualOnline
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _adminManualOnline ? 'Online' : 'Offline',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () async {
              await _loadAvailability();
              await _loadConversations();
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _Conversation {
  final String userId;
  String senderName;
  String lastMessage;
  String lastTime;
  DateTime updatedAt;

  _Conversation({
    required this.userId,
    required this.senderName,
    required this.lastMessage,
    required this.lastTime,
  }) : updatedAt = DateTime.now();

  void touch() {
    updatedAt = DateTime.now();
  }
}
