import 'dart:async';
import 'package:flutter/material.dart';

class LiveChatOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final Function(String) onSendMessage;
  final String currentUserName;

  const LiveChatOverlay({
    Key? key,
    required this.messages,
    required this.onSendMessage,
    required this.currentUserName,
  }) : super(key: key);

  @override
  State<LiveChatOverlay> createState() => _LiveChatOverlayState();
}

class _LiveChatOverlayState extends State<LiveChatOverlay>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<AnimatedMessage> _visibleMessages = [];
  late AnimationController _inputAnimationController;
  late Animation<double> _inputAnimation;
  bool _isInputVisible = false;
  Timer? _hideInputTimer;
  final FocusNode _focusNode = FocusNode(); // Add this line

  @override
  void initState() {
    super.initState();
    _inputAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _inputAnimation = CurvedAnimation(
      parent: _inputAnimationController,
      curve: Curves.easeInOut,
    );

    // Add existing messages when widget first loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var message in widget.messages) {
        addFloatingMessage(message);
      }
    });
  }

  @override
  void didUpdateWidget(LiveChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // print('🔄 didUpdateWidget called');
    // print('Old message count: ${oldWidget.messages.length}');
    // print('New message count: ${widget.messages.length}');

    // Check for new messages
    if (widget.messages.length > oldWidget.messages.length) {
      final newMessages = widget.messages.sublist(oldWidget.messages.length);
      // print('🎯 New messages detected: ${newMessages.length}');

      for (var message in newMessages) {
        // print('➕ Adding message: ${message['message']}');

        addFloatingMessage(message);
      }
    }
  }

  void addFloatingMessage(Map<String, dynamic> message) {
    final animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    final slideAnimation = Tween<Offset>(
      begin: Offset(1.0, 0.0),
      end: Offset(0.0, 0.0),
    ).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeOut),
    );

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeIn),
    );

    final animatedMessage = AnimatedMessage(
      message: message,
      slideAnimation: slideAnimation,
      fadeAnimation: fadeAnimation,
      controller: animationController,
    );

    setState(() {
      _visibleMessages.add(animatedMessage);

      // Keep only last 6 messages
      if (_visibleMessages.length > 6) {
        final oldMessage = _visibleMessages.removeAt(0);
        oldMessage.controller.dispose();
      }
    });

    // Start animation
    animationController.forward();

    // Auto-remove after 8 seconds
    Timer(Duration(seconds: 8), () {
      if (mounted && _visibleMessages.contains(animatedMessage)) {
        // Fade out
        animationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _visibleMessages.remove(animatedMessage);
            });
            animationController.dispose();
          }
        });
      }
    });
  }

  void _toggleInput() {
    setState(() {
      _isInputVisible = !_isInputVisible;
    });

    if (_isInputVisible) {
      _inputAnimationController.forward();
      // Auto-hide after 10 seconds of inactivity
      FocusScope.of(context).requestFocus(_focusNode);

      _hideInputTimer?.cancel();
      _hideInputTimer = Timer(Duration(seconds: 10), () {
        if (mounted && _isInputVisible) {
          _hideInput();
        }
      });
    } else {
      _inputAnimationController.reverse();
      _hideInputTimer?.cancel();
    }
  }

  void _addTestMessage() {
    // Add a test message to see if overlay is working
    final testMessage = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'userId': 999,
      'userName': 'TestUser',
      'message': 'Test message to check overlay visibility',
      'timestamp': DateTime.now(),
      'isYou': false,
    };
    addFloatingMessage(testMessage);
  }

  void _hideInput() {
    if (_isInputVisible) {
      setState(() {
        _isInputVisible = false;
      });
      _inputAnimationController.reverse();
      _hideInputTimer?.cancel();
      _focusNode.unfocus();
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      widget.onSendMessage(message);

      // addFloatingMessage(message);
      _messageController.clear();
      _hideInput();
      _focusNode.unfocus();
    }
  }

  Widget _buildFloatingMessage(AnimatedMessage animatedMessage) {
    final message = animatedMessage.message;
    final isYou = message['isYou'] ?? false;

    return SlideTransition(
      position: animatedMessage.slideAnimation,
      child: FadeTransition(
        opacity: animatedMessage.fadeAnimation,
        child: Container(
          margin: EdgeInsets.only(bottom: 8, right: 16, left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isYou ? Color(0xFF40916C) : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isYou ? Color(0xFF40916C) : Color(0xFF2D3748),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        (message['userName'] ?? 'U')[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message['userName'] ?? 'Unknown',
                          style: TextStyle(
                            color: isYou ? Color(0xFF95D5B2) : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          message['message'] ?? '',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Floating messages overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 120, // Above the input area
            child: IgnorePointer(
              child: Container(
                height: 300, // Space for 6 messages
                // Debug: Add background to see the overlay area
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Show message count for debugging
                    ..._visibleMessages
                        .map((msg) => _buildFloatingMessage(msg))
                        .toList(),
                  ],
                ),
              ),
            ),
          ),

          // Chat toggle button
          Positioned(
            right: 16,
            bottom: 20,
            child: GestureDetector(
              onTap: _toggleInput,
              onLongPress: _addTestMessage, // Long press to add test message
              child: FloatingActionButton.small(
                onPressed: _toggleInput,
                backgroundColor: Color(0xFF40916C),
                child: Icon(
                  _isInputVisible ? Icons.close : Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 20,
                ),
                elevation: 4,
              ),
            ),
          ),

          // Input area (animated)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _inputAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 80 * (1 - _inputAnimation.value)),
                  child: Opacity(
                    opacity: _inputAnimation.value,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
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
                                  onSubmitted: (_) => _sendMessage(),
                                  maxLines: 1,
                                  focusNode: _focusNode, // Add this line

                                  maxLength: 200,
                                  decoration: InputDecoration(
                                    hintText: 'Type a message...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    counterText: '',
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputAnimationController.dispose();
    _messageController.dispose();
    _hideInputTimer?.cancel();
    _focusNode.dispose(); // Dispose the focus node

    // Dispose all message animation controllers
    for (var message in _visibleMessages) {
      message.controller.dispose();
    }

    super.dispose();
  }
}

class AnimatedMessage {
  final Map<String, dynamic> message;
  final Animation<Offset> slideAnimation;
  final Animation<double> fadeAnimation;
  final AnimationController controller;

  AnimatedMessage({
    required this.message,
    required this.slideAnimation,
    required this.fadeAnimation,
    required this.controller,
  });
}
