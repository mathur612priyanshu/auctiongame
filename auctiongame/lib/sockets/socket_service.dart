import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:auctiongame/constants.dart';

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;

  static SocketService get instance {
    _instance ??= SocketService._internal();
    return _instance!;
  }

  SocketService._internal();
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  void connect() {
    print('🔌 Connecting to socket server at $socketUrl');

    if (_socket?.connected == true) {
      print('🔄 Disconnecting existing connection...');
      _socket?.disconnect();
      _socket?.dispose();
    }

    _socket = IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'timeout': 20000,
      'forceNew': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print('✅ Connected to socket server');
      _connectionController.add(true);
    });

    _socket!.onDisconnect((reason) {
      print('❌ Disconnected from socket server: $reason');
      _connectionController.add(false);
    });

    _socket!.onError((error) {
      print('🔥 Socket error: $error');
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      print('🔥 Socket connection error: $error');
      _connectionController.add(false);
    });
  }

  void disconnect() {
    print('🔌 Disconnecting socket...');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    print('✅ Socket disconnected and disposed');
  }

  bool get isConnected => _socket?.connected ?? false;

  void joinAuction(
    int auctionId,
    int userId,
    String userName,
    String? profilepic,
  ) {
    if (!isConnected) {
      print('❌ Cannot join auction - socket not connected');
      connect();
      return;
    }
    print('📥 Joining auction: $auctionId as $userName');
    _socket?.emit('joinAuction', {
      'auctionId': auctionId,
      'userId': userId,
      'userName': userName,
      'profilepic': profilepic,
    });
  }

  void leaveAuction(int auctionId, int userId, String userName) {
    if (!isConnected) {
      print('❌ Cannot leave auction - socket not connected');
      return;
    }
    print('📤 Leaving auction: $auctionId for user: $userName');
    _socket?.emit('leaveAuction', {
      'auctionId': auctionId,
      'userId': userId,
      'userName': userName,
    });
  }

  void placeBid(
    int auctionId,
    int userId,
    String userName,
    int bidAmount,
    int playerId,
  ) {
    if (!isConnected) {
      print('❌ Cannot place bid - socket not connected');
      return;
    }
    print('💰 Placing bid: $bidAmount for player: $playerId');
    _socket?.emit('placeBid', {
      'auctionId': auctionId,
      'userId': userId,
      'userName': userName,
      'bidAmount': bidAmount,
      'playerId': playerId,
    });
  }

  // Existing event listeners
  void onCurrentPlayerBids(Function(Map<String, dynamic>) callback) {
    print('💰 Setting up current player bids listener');
    _socket?.on('currentPlayerBids', (data) {
      print(
        '📨 Received current player bids: ${data['bids']?.length ?? 0} bids',
      );
      callback(data);
    });
  }

  void onCurrentPlayer(Function(Map<String, dynamic>) callback) {
    print('🎯 Setting up current-player listener');
    _socket?.on('current-player', (data) {
      print('📨 Received current-player: $data');
      callback(data);
    });
  }

  void onNewBid(Function(Map<String, dynamic>) callback) {
    _socket?.on('newBid', (data) {
      print('📨 Received newBid: $data');
      callback(data);
    });
  }

  void onTimerUpdate(Function(Map<String, dynamic>) callback) {
    _socket?.on('timerUpdate', (data) {
      print('⏰ Timer update: ${data['timeRemaining']}s');
      callback(data);
    });
  }

  void onAuctionEnded(Function(Map<String, dynamic>) callback) {
    _socket?.on('auctionEnded', (data) {
      print('🏁 Auction ended: $data');
      callback(data);
    });
  }

  void onNewPlayerAuction(Function(Map<String, dynamic>) callback) {
    _socket?.on('newPlayerAuction', (data) {
      print('👤 New player auction: $data');
      callback(data);
    });
  }

  void onUserJoined(Function(Map<String, dynamic>) callback) {
    _socket?.on('userJoined', (data) {
      print('👋 User joined: $data');
      callback(data);
    });
  }

  void onUserLeft(Function(Map<String, dynamic>) callback) {
    _socket?.on('userLeft', (data) {
      print('👋 User left: $data');
      callback(data);
    });
  }

  void onAuctionState(Function(Map<String, dynamic>) callback) {
    _socket?.on('auctionState', (data) {
      print('📊 Auction state: $data');
      callback(data);
    });
  }

  void onBidError(Function(Map<String, dynamic>) callback) {
    _socket?.on('bidError', (data) {
      print('❌ Bid error: $data');
      callback(data);
    });
  }

  void onAuctionCompleted(Function(Map<String, dynamic>) callback) {
    _socket?.on('auctionCompleted', (data) {
      print('🎉 Auction completed: $data');
      callback(data);
    });
  }

  void onConnectedUsers(Function(Map<String, dynamic>) callback) {
    _socket?.on('connectedUsers', (data) {
      print(
        '👥 Connected users update: ${data['users']?.length ?? 0} users ${data['users']}',
      );
      callback(data);
    });
  }

  // NEW: Budget and Stats Event Listeners
  void onUserBudget(Function(Map<String, dynamic>) callback) {
    print('💰 Setting up user budget listener');
    _socket?.on('userBudget', (data) {
      print('📨 Received user budget: $data');
      callback(data);
    });
  }

  void onBudgetUpdated(Function(Map<String, dynamic>) callback) {
    print('📊 Setting up budget updated listener');
    _socket?.on('budgetUpdated', (data) {
      print(
        '📨 Received budget updates for ${data['budgets']?.length ?? 0} users',
      );
      callback(data);
    });
  }

  void onAuctionStatsUpdated(Function(Map<String, dynamic>) callback) {
    print('📈 Setting up auction stats listener');
    _socket?.on('auctionStatsUpdated', (data) {
      print('📨 Received auction stats update: ${data['stats']}');
      callback(data);
    });
  }

  void onTeamUpdated(Function(Map<String, dynamic>) callback) {
    print('👥 Setting up team updated listener');
    _socket?.on('teamUpdated', (data) {
      print('📨 Received team update: $data');
      callback(data);
    });
  }

  void onBudgetWarning(Function(Map<String, dynamic>) callback) {
    print('⚠️ Setting up budget warning listener');
    _socket?.on('budgetWarning', (data) {
      print('📨 Received budget warning: $data');
      callback(data);
    });
  }

  void onUserTeam(Function(Map<String, dynamic>) callback) {
    _socket?.on('userTeam', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void requestUserTeam(int targetUserId, int auctionId) {
    _socket?.emit('requestUserTeam', {
      'targetUserId': targetUserId,
      'auctionId': auctionId,
    });
  }

  void onSpecificUserTeam(Function(Map<String, dynamic>) callback) {
    _socket?.on('specificUserTeam', (data) {
      print('Socket received specificUserTeam event');
      print('Raw data: $data');
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onAuctionHistory(Function(Map<String, dynamic>) callback) {
    _socket?.on('auctionHistory', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void removeAllListeners() {
    print('🧹 Removing all socket listeners');
    _socket?.clearListeners();
  }

  void removeListener(String event) {
    _socket?.off(event);
  }

  void sendChatMessage(
    int auctionId,
    int userId,
    String userName,
    String message,
  ) {
    if (!isConnected) {
      print('❌ Cannot send chat message - socket not connected');
      return;
    }
    print('💬 Sending chat message: $message');
    _socket?.emit('sendChatMessage', {
      'auctionId': auctionId,
      'userId': userId,
      'userName': userName,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void getChatHistory(int auctionId, int userId) {
    if (!isConnected) {
      print('❌ Cannot get chat history - socket not connected');
      return;
    }
    print('📜 Requesting chat history for auction: $auctionId');
    _socket?.emit('getChatHistory', {'auctionId': auctionId, 'userId': userId});
  }

  void sendTypingStatus(
    int auctionId,
    int userId,
    String userName,
    bool isTyping,
  ) {
    if (!isConnected) return;
    _socket?.emit('userTyping', {
      'auctionId': auctionId,
      'userId': userId,
      'userName': userName,
      'isTyping': isTyping,
    });
  }

  // NEW: Chat Event Listeners
  void onNewChatMessage(Function(Map<String, dynamic>) callback) {
    print('💬 Setting up new chat message listener');
    _socket?.on('newChatMessage', (data) {
      print('📨 Received new chat message: ${data['message']}');
      callback(data);
    });
  }

  void onChatHistory(Function(Map<String, dynamic>) callback) {
    print('📜 Setting up chat history listener');
    _socket?.on('chatHistory', (data) {
      print(
        '📨 Received chat history: ${data['messages']?.length ?? 0} messages',
      );
      callback(data);
    });
  }

  void onChatError(Function(Map<String, dynamic>) callback) {
    print('❌ Setting up chat error listener');
    _socket?.on('chatError', (data) {
      print('📨 Received chat error: ${data['message']}');
      callback(data);
    });
  }

  void onUserTypingStatus(Function(Map<String, dynamic>) callback) {
    print('⌨️ Setting up typing status listener');
    _socket?.on('userTypingStatus', (data) {
      print('📨 User typing status: ${data['userName']} - ${data['isTyping']}');
      callback(data);
    });
  }

  void onAuctionDetails(Function(Map<String, dynamic>) callback) {
    print('📋 Setting up auction details listener');
    _socket?.on('auctionDetails', (data) {
      print(
        '📨 Received auction details: ${data['name']} - maxPlayerAllowed: ${data['maxPlayerAllowed']}',
      );
      callback(data);
    });
  }
}
