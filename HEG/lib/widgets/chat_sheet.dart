import 'dart:async';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class ChatSheet extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String receiverId;
  final String receiverName;

  const ChatSheet({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.receiverId,
    this.receiverName = 'Admin Support',
  });

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<bool>? _presenceSubscription;

  bool _isLoading = true;
  bool _isSending = false;
  bool _isOnline = false; // Used ONLY for the green/red dot — never blocks send

  @override
  void initState() {
    super.initState();
    _listenStatus();
    _listenPresence();
    _loadHistory();
  }

  void _listenStatus() {
    _statusSubscription = ChatService.statusStream.listen((status) {
      if (!mounted || status.trim().isEmpty) return;

      // Don't show online/offline as snackbar — it's shown as dot in header
      if (status.toLowerCase().contains('online') ||
          status.toLowerCase().contains('offline') ||
          status.toLowerCase().contains('connected') ||
          status.toLowerCase().contains('disconnected') ||
          status.toLowerCase().contains('socket') ||
          status.toLowerCase().contains('stomp') ||
          status.toLowerCase().contains('sending...')) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status),
          backgroundColor:
              status.toLowerCase().contains('failed') ||
                  status.toLowerCase().contains('error') ||
                  status.toLowerCase().contains('network')
              ? Colors.red
              : const Color(0xFF0D4C5E),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  void _listenPresence() {
    // Dot indicator ONLY — no send blocking
    _presenceSubscription = ChatService.presenceStream.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
  }

  Future<void> _loadHistory() async {
    if (mounted) setState(() => _isLoading = true);

    await ChatService.initChat(widget.currentUserId, widget.receiverId);

    if (!mounted) return;

    setState(() {
      _isOnline = ChatService.isReceiverOnline;
      _isLoading = false;
    });

    ChatService.connect(
      userId: widget.currentUserId,
      receiverId: widget.receiverId,
    );

    _scrollToBottom(jump: true);
  }

  void _scrollToBottom({bool jump = false}) {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!_scrollController.hasClients) return;
      if (!_scrollController.position.hasContentDimensions) return;

      final offset = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(offset);
      } else {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    // ✅ NO online/offline check here — anyone can send anytime
    setState(() => _isSending = true);
    _controller.clear();
    setState(() {}); // refresh send button immediately

    final result = await ChatService.sendMessage(
      senderId: widget.currentUserId,
      receiverId: widget.receiverId,
      message: text,
      senderName: widget.currentUserName,
    );

    if (!mounted) return;

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    _scrollToBottom();
    setState(() => _isSending = false);
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _presenceSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    ChatService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ canSend depends ONLY on text + sending state, NOT on online status
    final canSend = !_isSending && _controller.text.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Color(0xFFF0F4F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessages()),
            _buildInputBar(canSend),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isAdminChat = widget.receiverName == 'Admin Support';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D4C5E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFB8962E),
            child: Icon(
              isAdminChat ? Icons.support_agent : Icons.person,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receiverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    // ✅ Dot is ONLY for visual indicator
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: _isOnline
                          ? Colors.greenAccent
                          : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: _isOnline ? Colors.greenAccent : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0D4C5E)),
            SizedBox(height: 12),
            Text('Loading messages...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return StreamBuilder<List<ChatMessage>>(
      stream: ChatService.messagesStream,
      initialData: ChatService.messages,
      builder: (context, snapshot) {
        final allMessages = snapshot.data ?? [];

        final messages = allMessages.where((msg) {
          return (msg.senderId == widget.currentUserId &&
                  msg.receiverId == widget.receiverId) ||
              (msg.senderId == widget.receiverId &&
                  msg.receiverId == widget.currentUserId);
        }).toList();

        _scrollToBottom();

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 52,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                const Text(
                  'No messages yet',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Send a message to start the conversation',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final msg = messages[i];
            final isMe = msg.senderId == widget.currentUserId;

            return Column(
              children: [
                if (i == 0) const _DateChip(label: 'Today'),
                _ChatBubble(
                  msg: msg,
                  isMe: isMe,
                  otherName: widget.receiverName == 'Admin Support'
                      ? (msg.senderName.isEmpty ? 'Admin' : msg.senderName)
                      : widget.receiverName,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar(bool canSend) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isSending, // ✅ Only locked while a message is sending
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type a message...', // ✅ Always shows this
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (canSend) _send();
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: canSend ? _send : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                // ✅ Gold when text typed, grey when empty
                color: canSend ? const Color(0xFFB8962E) : Colors.grey[400],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (canSend ? const Color(0xFFB8962E) : Colors.grey)
                        .withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  final String otherName;

  const _ChatBubble({
    required this.msg,
    required this.isMe,
    required this.otherName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF0D4C5E),
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFB8962E) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        otherName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  Text(
                    msg.message,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      msg.timestamp,
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white60 : Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFB8962E),
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
