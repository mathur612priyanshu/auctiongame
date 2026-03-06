import 'package:flutter/material.dart';
import 'dart:async';

class ChatBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialMessages;
  final Map<String, bool> initialTypingUsers;
  final Stream<List<Map<String, dynamic>>> messagesStream;
  final Stream<Map<String, bool>> typingUsersStream;
  final Function(String) onSendMessage;
  final Function(bool) onTypingChanged;
  final String currentUserName;

  const ChatBottomSheet({
    Key? key,
    required this.initialMessages,
    required this.initialTypingUsers,
    required this.messagesStream,
    required this.typingUsersStream,
    required this.onSendMessage,
    required this.onTypingChanged,
    required this.currentUserName,
  }) : super(key: key);

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<ChatBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;

  // Local state for real-time updates
  List<Map<String, dynamic>> _messages = [];
  Map<String, bool> _typingUsers = {};

  // Stream subscriptions
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  StreamSubscription<Map<String, bool>>? _typingSubscription;

  @override
  void initState() {
    super.initState();

    // Initialize with initial data
    _messages = List.from(widget.initialMessages);
    _typingUsers = Map.from(widget.initialTypingUsers);

    // Subscribe to real-time streams
    _messagesSubscription = widget.messagesStream.listen((newMessages) {
      if (mounted) {
        setState(() {
          _messages = List.from(newMessages);
        });
        _scrollToBottom();
      }
    });

    _typingSubscription = widget.typingUsersStream.listen((newTypingUsers) {
      if (mounted) {
        setState(() {
          _typingUsers = Map.from(newTypingUsers);
        });
      }
    });

    // Scroll to bottom initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      widget.onTypingChanged(true);
    }

    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        widget.onTypingChanged(false);
      }
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      widget.onSendMessage(message);
      _messageController.clear();

      // Stop typing indicator
      if (_isTyping) {
        _isTyping = false;
        widget.onTypingChanged(false);
        _typingTimer?.cancel();
      }
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isYou = message['isYou'] as bool;
    final userName = message['userName'] as String;
    final messageText = message['message'] as String;
    final timestamp = message['timestamp'] as DateTime;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isYou ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isYou) ...[
            // Avatar for other users
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(0xFF40916C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isYou ? Color(0xFF40916C) : Color(0xFF2D3748),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(isYou ? 16 : 4),
                  bottomRight: Radius.circular(isYou ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isYou)
                    Text(
                      userName,
                      style: TextStyle(
                        color: Color(0xFF95D5B2),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (!isYou) SizedBox(height: 4),
                  Text(
                    messageText,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      color: isYou ? Colors.white70 : Color(0xFF95D5B2),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isYou) ...[
            SizedBox(width: 8),
            // Avatar for current user
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(0xFF40916C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  widget.currentUserName.isNotEmpty
                      ? widget.currentUserName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final typingUserNames =
        _typingUsers.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();

    if (typingUserNames.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(0xFF2D3748),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF95D5B2)),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              typingUserNames.length == 1
                  ? '${typingUserNames.first} is typing...'
                  : '${typingUserNames.length} people are typing...',
              style: TextStyle(
                color: Color(0xFF95D5B2),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Cancel stream subscriptions
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();

    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();

    // Stop typing indicator when closing
    if (_isTyping) {
      widget.onTypingChanged(false);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        color: Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B4332), Color(0xFF0D1B2A)],
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF40916C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_messages.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: Colors.white38, height: 1),

              // Messages area
              Expanded(
                child:
                    _messages.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                color: Color(0xFF95D5B2),
                                size: 48,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Start the conversation!',
                                style: TextStyle(
                                  color: Color(0xFF95D5B2),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                        : Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  return _buildMessage(_messages[index]);
                                },
                              ),
                            ),
                            _buildTypingIndicator(),
                          ],
                        ),
              ),

              // Input area
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF1B4332),
                  border: Border(
                    top: BorderSide(color: Colors.white24, width: 0.5),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: _messageController,
                            onChanged: _onTextChanged,
                            onSubmitted: (_) => _sendMessage,
                            maxLines: null,
                            maxLength: 500,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              counterText: '', // Hide character counter
                            ),
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF40916C),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                          splashRadius: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
