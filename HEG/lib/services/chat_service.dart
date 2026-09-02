import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ add

class ChatMessage {
  final String senderId;
  final String receiverId;
  final String message;
  final String senderName;
  final String timestamp;

  ChatMessage({
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.senderName,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? '',
      timestamp:
          map['timestamp']?.toString() ??
          map['sentAt']?.toString() ??
          map['time']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'senderName': senderName,
      'timestamp': timestamp,
    };
  }

  bool isSameAs(ChatMessage other) {
    return senderId == other.senderId &&
        receiverId == other.receiverId &&
        message == other.message &&
        timestamp == other.timestamp;
  }
}

class ChatSendResult {
  final bool ok;
  final String message;

  const ChatSendResult({required this.ok, required this.message});
}

class ChatService {
  // ── Base URL ────────────────────────────────────────────────────────────
  // ✅ REPLACE WITH
  static String apiKeyHeaderName = 'X-API-KEY';
  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';
  static String? get apiKey => dotenv.env['API_KEY'];

  static StompClient? _client;
  static bool isConnected = false;
  static bool _socketReady = false;

  static Timer? _pollingTimer;
  static String? _currentUserId;
  static String? _currentReceiverId;

  // ── Presence ────────────────────────────────────────────────────────────
  static bool _isReceiverOnline = false;
  static bool get isReceiverOnline => _isReceiverOnline;

  // ── Message store ───────────────────────────────────────────────────────
  static final List<ChatMessage> messages = [];

  // ── 🔴 Unread tracking ──────────────────────────────────────────────────
  // Stores senderId of each person who has sent an unread message
  static final Set<String> _unreadSenders = {};

  // Also stores last unread message per sender for preview
  static final Map<String, String> _unreadLastMessage = {};

  static final StreamController<Set<String>> _unreadController =
      StreamController<Set<String>>.broadcast();

  // Stream — listen in chat bubble button & admin list
  static Stream<Set<String>> get unreadSendersStream =>
      _unreadController.stream;

  // Total count — for chat bubble badge number
  static int get totalUnreadCount => _unreadSenders.length;

  // Check if specific sender has unread — for per-employee badge
  static bool hasUnread(String senderId) =>
      _unreadSenders.contains(senderId.trim().toLowerCase());

  // Get last unread message preview for a sender
  static String getUnreadPreview(String senderId) =>
      _unreadLastMessage[senderId.trim().toLowerCase()] ?? '';

  // Call when admin opens a specific employee chat
  static void markAsRead(String senderId) {
    final key = senderId.trim().toLowerCase();
    _unreadSenders.remove(key);
    _unreadLastMessage.remove(key);
    _emitUnread();
  }

  // Call when admin opens the full chat list (clears all)
  static void clearAllUnread() {
    _unreadSenders.clear();
    _unreadLastMessage.clear();
    _emitUnread();
  }

  static void _emitUnread() {
    if (!_unreadController.isClosed) {
      _unreadController.add(Set<String>.from(_unreadSenders));
    }
  }

  // Marks a sender as having unread message (only if NOT currently chatting with them)
  static void _markUnread(ChatMessage msg) {
    final senderId = msg.senderId.trim().toLowerCase();
    final currentReceiver = (_currentReceiverId ?? '').trim().toLowerCase();

    // Don't mark unread if admin is already in that conversation
    if (senderId == currentReceiver) return;

    _unreadSenders.add(senderId);
    _unreadLastMessage[senderId] = msg.message;
    _emitUnread();
  }

  // ── Streams ─────────────────────────────────────────────────────────────
  static final StreamController<List<ChatMessage>> _messagesController =
      StreamController<List<ChatMessage>>.broadcast();
  static Stream<List<ChatMessage>> get messagesStream =>
      _messagesController.stream;

  static final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  static Stream<ChatMessage> get messageStream => _messageController.stream;

  static final StreamController<bool> _presenceController =
      StreamController<bool>.broadcast();
  static Stream<bool> get presenceStream => _presenceController.stream;

  static final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  static Stream<String> get statusStream => _statusController.stream;

  // ── HTTP headers ────────────────────────────────────────────────────────
  static Map<String, String> _httpHeaders({bool jsonBody = false}) {
    return <String, String>{
      'Accept': 'application/json',
      if (jsonBody) 'Content-Type': 'application/json',
      if ((apiKey ?? '').trim().isNotEmpty) apiKeyHeaderName: apiKey!.trim(),
    };
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  static String _norm(String? v) => (v ?? '').trim().toLowerCase();
  static bool _sameId(String? a, String? b) => _norm(a) == _norm(b);

  static String _localKey(String a, String b) {
    final pair = [a.trim(), b.trim()]..sort();
    return 'chat_${pair[0]}_${pair[1]}';
  }

  static bool _isForPair(ChatMessage msg, String a, String b) {
    return (_sameId(msg.senderId, a) && _sameId(msg.receiverId, b)) ||
        (_sameId(msg.senderId, b) && _sameId(msg.receiverId, a));
  }

  static bool _messageExists(ChatMessage msg) {
    return messages.any(
      (m) =>
          _sameId(m.senderId, msg.senderId) &&
          _sameId(m.receiverId, msg.receiverId) &&
          m.message.trim() == msg.message.trim() &&
          m.timestamp.trim() == msg.timestamp.trim(),
    );
  }

  // ── Emit helpers ────────────────────────────────────────────────────────
  static void _emitMessages() {
    if (!_messagesController.isClosed) {
      _messagesController.add(List<ChatMessage>.from(messages));
    }
  }

  static void _emitSingleMessage(ChatMessage msg) {
    if (!_messageController.isClosed) _messageController.add(msg);
  }

  static void _emitStatus(String text) {
    if (!_statusController.isClosed) _statusController.add(text);
  }

  static void _emitPresence(bool online) {
    _isReceiverOnline = online;
    if (!_presenceController.isClosed) _presenceController.add(online);
  }

  // ── Local persistence ───────────────────────────────────────────────────
  static Future<void> _savePairLocally(String a, String b) async {
    final sp = await SharedPreferences.getInstance();
    final saved = messages
        .where((m) => _isForPair(m, a, b))
        .map((m) => jsonEncode(m.toMap()))
        .toList();
    await sp.setStringList(_localKey(a, b), saved);
  }

  static Future<List<ChatMessage>> loadMessagesLocally(
    String userId,
    String receiverId,
  ) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_localKey(userId, receiverId)) ?? [];
    return list
        .map((s) {
          try {
            return ChatMessage.fromMap(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<ChatMessage>()
        .toList();
  }

  // ── Fetch history from server ───────────────────────────────────────────
  static Future<List<ChatMessage>> fetchHistoryFromServer(
    String userId,
    String receiverId,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/api/chat/history/$userId/$receiverId');
      final res = await http
          .get(url, headers: _httpHeaders())
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final List<dynamic> data = jsonDecode(res.body);
        return data
            .map((e) => ChatMessage.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Check receiver online status ────────────────────────────────────────
  static Future<void> checkReceiverOnline(String receiverId) async {
    try {
      final url = Uri.parse('$baseUrl/api/chat/presence/$receiverId');
      final res = await http
          .get(url, headers: _httpHeaders())
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        _emitPresence(map['online'] == true);
      }
    } catch (_) {}
  }

  // ── Init chat ───────────────────────────────────────────────────────────
  static Future<void> initChat(String userId, String receiverId) async {
    _currentUserId = userId;
    _currentReceiverId = receiverId;

    // Clear unread badge for this sender when opening their chat
    markAsRead(receiverId);

    messages.removeWhere((m) => _isForPair(m, userId, receiverId));
    final local = await loadMessagesLocally(userId, receiverId);
    for (final msg in local) {
      if (!_messageExists(msg)) messages.add(msg);
    }
    _emitMessages();

    final server = await fetchHistoryFromServer(userId, receiverId);
    if (server.isNotEmpty) {
      messages.removeWhere((m) => _isForPair(m, userId, receiverId));
      for (final msg in server) {
        if (!_messageExists(msg)) messages.add(msg);
      }
      await _savePairLocally(userId, receiverId);
      _emitMessages();
    }

    await checkReceiverOnline(receiverId);
    _startPolling(userId: userId, receiverId: receiverId);
  }

  // ── Connect WebSocket ───────────────────────────────────────────────────
  static void connect({required String userId, required String receiverId}) {
    _currentUserId = userId;
    _currentReceiverId = receiverId;

    if (_client != null && isConnected && _socketReady) {
      _requestPresence(requesterId: userId, targetUserId: receiverId);
      return;
    }

    _tryWebSocket(userId: userId, receiverId: receiverId);
  }

  static void _tryWebSocket({
    required String userId,
    required String receiverId,
  }) {
    try {
      _client = StompClient(
        config: StompConfig.sockJS(
          url: '$baseUrl/ws-chat?userId=$userId',
          reconnectDelay: const Duration(seconds: 8),
          stompConnectHeaders: {
            'userId': userId,
            if ((apiKey ?? '').trim().isNotEmpty)
              apiKeyHeaderName: apiKey!.trim(),
          },
          webSocketConnectHeaders: {
            'userId': userId,
            if ((apiKey ?? '').trim().isNotEmpty)
              apiKeyHeaderName: apiKey!.trim(),
          },
          onConnect: (frame) {
            isConnected = true;
            _socketReady = true;
            _emitStatus('Connected');

            _subscribeToMessages();
            _subscribeToStatus();
            _subscribeToPresence();

            _requestPresence(
              requesterId: userId,
              targetUserId: _currentReceiverId ?? receiverId,
            );
          },
          onStompError: (frame) {
            isConnected = false;
            _socketReady = false;
            _emitStatus('STOMP error');
          },
          onWebSocketError: (_) {
            isConnected = false;
            _socketReady = false;
            _emitStatus('Socket error');
          },
          onWebSocketDone: () {
            isConnected = false;
            _socketReady = false;
            _emitStatus('Socket closed');
          },
          onDisconnect: (_) {
            isConnected = false;
            _socketReady = false;
            _emitStatus('Disconnected');
          },
        ),
      );

      _client!.activate();
    } catch (_) {
      isConnected = false;
      _socketReady = false;
      _emitStatus('Realtime unavailable');
    }
  }

  // ── Subscriptions ───────────────────────────────────────────────────────
  static void _subscribeToMessages() {
    _client?.subscribe(
      destination: '/user/queue/messages',
      callback: (StompFrame frame) async {
        if (frame.body == null || frame.body!.trim().isEmpty) return;
        try {
          final data = jsonDecode(frame.body!) as Map<String, dynamic>;
          final msg = ChatMessage.fromMap(data);

          // Content-only check — ignores timestamp format mismatch
          final alreadyExists = messages.any(
            (m) =>
                _sameId(m.senderId, msg.senderId) &&
                _sameId(m.receiverId, msg.receiverId) &&
                m.message.trim() == msg.message.trim(),
          );

          if (!alreadyExists) {
            messages.add(msg);
            await _savePairLocally(msg.senderId, msg.receiverId);
            _emitMessages();
            _emitSingleMessage(msg);

            // 🔴 Mark unread if admin is NOT in this conversation
            _markUnread(msg);
          }
        } catch (_) {}
      },
    );
  }

  static void _subscribeToStatus() {
    _client?.subscribe(
      destination: '/user/queue/status',
      callback: (StompFrame frame) {
        if (frame.body == null || frame.body!.trim().isEmpty) return;
        try {
          final data = jsonDecode(frame.body!) as Map<String, dynamic>;
          final type = data['type']?.toString() ?? '';
          if (type == 'CHAT_STATUS') {
            _emitStatus(data['message']?.toString() ?? '');
          } else if (type == 'PRESENCE') {
            final targetId = data['userId']?.toString() ?? '';
            if (_sameId(targetId, _currentReceiverId)) {
              _emitPresence(data['online'] == true);
            }
          }
        } catch (_) {}
      },
    );
  }

  static void _subscribeToPresence() {
    _client?.subscribe(
      destination: '/topic/presence',
      callback: (StompFrame frame) {
        if (frame.body == null || frame.body!.trim().isEmpty) return;
        try {
          final data = jsonDecode(frame.body!) as Map<String, dynamic>;
          final targetId = data['userId']?.toString() ?? '';
          final online = data['online'] == true;
          if (_sameId(targetId, _currentReceiverId)) {
            _emitPresence(online);
          }
        } catch (_) {}
      },
    );
  }

  static void _requestPresence({
    required String requesterId,
    required String targetUserId,
  }) {
    try {
      _client?.send(
        destination: '/app/presence.check',
        body: jsonEncode({
          'requesterId': requesterId,
          'targetUserId': targetUserId,
        }),
      );
    } catch (_) {}
  }

  // ── Polling ─────────────────────────────────────────────────────────────
  static void _startPolling({
    required String userId,
    required String receiverId,
  }) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _pollNewMessages(userId: userId, receiverId: receiverId);
      await checkReceiverOnline(receiverId);
    });
  }

  static void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  static Future<void> _pollNewMessages({
    required String userId,
    required String receiverId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/chat/history/$userId/$receiverId');
      final res = await http
          .get(url, headers: _httpHeaders())
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final List<dynamic> data = jsonDecode(res.body);
        final serverMessages = data
            .map((e) => ChatMessage.fromMap(e as Map<String, dynamic>))
            .toList();

        // Find genuinely new messages before replacing
        // Used to detect new incoming messages for unread badge
        final existingCount = messages
            .where((m) => _isForPair(m, userId, receiverId))
            .length;

        // Full replace — server is always source of truth
        messages.removeWhere((m) => _isForPair(m, userId, receiverId));
        messages.addAll(serverMessages);

        // 🔴 Check for new messages from the OTHER person (not current user)
        if (serverMessages.length > existingCount) {
          final newMessages = serverMessages.skip(existingCount);
          for (final msg in newMessages) {
            // Only mark unread if message is FROM someone else TO current user
            if (!_sameId(msg.senderId, userId)) {
              _markUnread(msg);
            }
          }
        }

        await _savePairLocally(userId, receiverId);
        _emitMessages();
      }
    } catch (_) {}
  }

  // ── Send message — NO optimistic UI, zero duplicates ────────────────────
  static Future<ChatSendResult> sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    required String senderName,
  }) async {
    final text = message.trim();

    if (text.isEmpty) {
      return const ChatSendResult(ok: false, message: 'Message is empty');
    }

    if (isConnected && _socketReady && _client != null) {
      try {
        _client!.send(
          destination: '/app/chat.send',
          body: jsonEncode({
            'senderId': senderId,
            'receiverId': receiverId,
            'message': text,
            'senderName': senderName,
          }),
          headers: {
            if ((apiKey ?? '').trim().isNotEmpty)
              apiKeyHeaderName: apiKey!.trim(),
          },
        );

        Future.delayed(const Duration(milliseconds: 300), () {
          _pollNewMessages(userId: senderId, receiverId: receiverId);
        });

        return const ChatSendResult(ok: true, message: 'Sending...');
      } catch (_) {}
    }

    try {
      final url = Uri.parse('$baseUrl/api/chat/send');
      final res = await http
          .post(
            url,
            headers: _httpHeaders(jsonBody: true),
            body: jsonEncode({
              'senderId': senderId,
              'receiverId': receiverId,
              'message': text,
              'senderName': senderName,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 201) {
        await _pollNewMessages(userId: senderId, receiverId: receiverId);
        return const ChatSendResult(ok: true, message: 'Message delivered');
      }

      return const ChatSendResult(ok: false, message: 'Send failed');
    } catch (_) {
      return const ChatSendResult(
        ok: false,
        message: 'No connection, try again',
      );
    }
  }

  // ── Disconnect ──────────────────────────────────────────────────────────
  static void disconnect() {
    _stopPolling();
    _socketReady = false;
    _client?.deactivate();
    _client = null;
    isConnected = false;
  }

  static void clearMessages() {
    messages.clear();
    _emitMessages();
  }

  static String? get currentUserId => _currentUserId;
  static String? get currentReceiverId => _currentReceiverId;
}
