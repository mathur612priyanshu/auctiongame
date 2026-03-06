import 'dart:async';
import 'dart:math';

import 'package:auctiongame/providers/userprovider.dart';
import 'package:auctiongame/screens/auctions/chatBottom.dart';
import 'package:auctiongame/sockets/socket_service.dart';
import 'package:auctiongame/theme/appcolor.dart';
import 'package:auctiongame/widgets/live_chat_overlay.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'dart:ui'; // For ImageFilter

class Auctiondetailscreen extends StatefulWidget {
  final int auctionId;
  final String auctionName;

  const Auctiondetailscreen({
    super.key,
    required this.auctionId,
    required this.auctionName,
  });

  @override
  State<Auctiondetailscreen> createState() => _AuctiondetailscreenState();
}

class _AuctiondetailscreenState extends State<Auctiondetailscreen>
    with TickerProviderStateMixin {
  late AnimationController _timerController;
  late AnimationController _pulseController;
  late AnimationController _bidController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bidAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  // bool _isClockTickPlaying = false;
  Map<String, dynamic>? _selectedUserTeam;
  String? _selectedUserName;

  // Timer? _auctionTimer;
  int _timeRemaining = 12;
  // Separate audio players for different sounds
  final AudioPlayer _bidSoundPlayer = AudioPlayer();
  final AudioPlayer _userJoinPlayer = AudioPlayer();
  final AudioPlayer _clickSoundPlayer = AudioPlayer();
  final AudioPlayer _applausePlayer = AudioPlayer();
  final AudioPlayer _clockTickPlayer = AudioPlayer();
  final AudioPlayer _sadSoundPlayer = AudioPlayer();
  final AudioPlayer _appMusicPlayer = AudioPlayer();

  final SocketService _socketService = SocketService.instance;
  List<Map<String, dynamic>> _connectedUsers = [];
  List<Map<String, dynamic>> _liveBids = [];
  int currentUserId = 1;
  late String currentUserName;
  late String profilepic;
  List<Map<String, dynamic>> _chatMessages = [];
  Map<String, bool> _typingUsers = {}; // userId -> isTyping
  Timer? _typingTimer;
  final StreamController<List<Map<String, dynamic>>> _chatStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  final StreamController<Map<String, bool>> _typingStreamController =
      StreamController<Map<String, bool>>.broadcast();

  void _initializeAudio() async {
    try {
      // Initialize all audio players
      List<AudioPlayer> players = [
        _bidSoundPlayer,
        _userJoinPlayer,
        _clickSoundPlayer,
        _applausePlayer,
        _clockTickPlayer,
        _sadSoundPlayer,
      ];

      // Special configuration for background music player
      await _appMusicPlayer.setReleaseMode(
        ReleaseMode.loop,
      ); // Set to loop mode
      await _appMusicPlayer.setPlayerMode(
        PlayerMode.mediaPlayer,
      ); // Better for background music

      // Configure other sound effects players
      for (AudioPlayer player in players) {
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
      }

      // Start playing background music immediately
      await _playAppSound();

      print('🔊 All audio players initialized');
    } catch (e) {
      print('❌ Error initializing audio: $e');
    }
  }

  // Add this property to your class
  bool _isBackgroundMusicPlaying = false;

  // Update the _playAppSound method
  Future<void> _playAppSound() async {
    try {
      if (_isBackgroundMusicPlaying) return;

      await _appMusicPlayer.stop();
      await _appMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _appMusicPlayer.setVolume(0.3); // Lower volume for background music
      await _appMusicPlayer.play(AssetSource('sounds/app_music.mp3'));
      _isBackgroundMusicPlaying = true;

      // Add listener for playback completion
      _appMusicPlayer.onPlayerComplete.listen((event) {
        _isBackgroundMusicPlaying = false;
        _playAppSound(); // Restart music
      });

      print('🎵 Background music started/resumed');
    } catch (e) {
      print('❌ Error playing background music: $e');
      _isBackgroundMusicPlaying = false;
    }
  }

  // Update _playSpecificSound to handle background music
  Future<void> _playSpecificSound(AudioPlayer player, String soundFile) async {
    try {
      // Temporarily pause background music
      if (_isBackgroundMusicPlaying) {
        await _appMusicPlayer.pause();
      }

      await player.stop();
      await player.play(AssetSource('sounds/$soundFile'));

      // Resume background music after a short delay
      Future.delayed(Duration(milliseconds: 3000), () {
        if (_isBackgroundMusicPlaying) {
          _appMusicPlayer.resume();
        }
      });

      print('🔊 Playing sound: $soundFile');
    } catch (e) {
      print('❌ Error playing sound $soundFile: $e');
    }
  }

  Future<void> _playBidSound() async {
    await _playSpecificSound(_bidSoundPlayer, 'bid_placed.mp3');
  }

  Future<void> _playUserJoinSound() async {
    await _playSpecificSound(_userJoinPlayer, 'user_enter.mp3');
  }

  Future<void> _playClickSound() async {
    await _playSpecificSound(_clickSoundPlayer, 'click.mp3');
  }

  Future<void> _playApplauseSound() async {
    await _playSpecificSound(_applausePlayer, 'applause.mp3');
  }

  Future<void> _playClockTick() async {
    await _playSpecificSound(_clockTickPlayer, 'clock-tick.mp3');
  }

  // Static auction data
  Map<String, dynamic> currentPlayer = {
    "id": -1,
    "name": "NULL",
    "basePrice": 100000,
    "team": "India",
    "type": "Batsman",
    "age": 35,
    "matches": 223,
    // "runs": 7263,
    "average": 50.4,
    "strikeRate": 137.96,
    "previousTeam": "RCB",
    "previousPrice": 170000000,
    "metadata": {},
    "image":
        "https://www.hindustantimes.com/static-content/1y/cricket-logos/players/virat-kohli.png",
  };

  int currentBid = 100000;
  String highestBidder = "You";

  List<Map<String, dynamic>> teams = [];

  List<Map<String, dynamic>> auctionHistory = [];

  Map<String, dynamic> auctionStats = {
    "totalPlayers": 100,
    "soldPlayers": 15,
    "unsoldPlayers": 3,
    "averagePrice": 85000000,
    "highestSale": 240000000,
    "totalSpent": 1275000000,
  };

  int yourBudget = 900000000;
  int yourSpent = 0;
  List<Map<String, dynamic>> yourTeam = [];
  bool canBid = true;
  Map<String, dynamic> yourBudgetInfo = {
    'totalBudget': 900000000,
    'spentAmount': 0,
    'remainingBudget': 900000000,
    'playersCount': 0,
    'isActive': true,
  };
  List<Map<String, dynamic>> allUserBudgets = [];
  Map<String, dynamic> liveAuctionStats = {};

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    currentUserId = userProvider.user!.id!;
    currentUserName = userProvider.user?.name ?? "Unknown User";
    profilepic = userProvider.user?.profilepic ?? "";

    _timerController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _bidController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bidAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _bidController, curve: Curves.elasticOut),
    );
    _initializeAudio(); // Add this line

    // Initialize socket connection
    _initializeSocket();
  }

  Future<void> _playSadSound() async {
    await _playSpecificSound(_sadSoundPlayer, 'sad.mp3');
  }

  Future<void> _playSound(String soundFile) async {
    try {
      await _audioPlayer.stop(); // Stop any previous sound first
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
      print('🔊 Playing sound: $soundFile');
    } catch (e) {
      print('❌ Error playing sound $soundFile: $e');
    }
  }

  void _initializeSocket() {
    print('🔧 Initializing socket connection...');

    // Ensure socket is connected
    if (!_socketService.isConnected) {
      _socketService.connect();

      // Wait a bit for connection to establish
      Future.delayed(Duration(milliseconds: 1000), () {
        if (_socketService.isConnected) {
          _joinAuctionRoom();
        } else {
          print('❌ Failed to connect to socket server');
          _showErrorSnackBar('Failed to connect to auction server');
        }
      });
    } else {
      _joinAuctionRoom();
    }
  }

  void _joinAuctionRoom() {
    print('🚪 Joining auction room...');

    // Join auction room
    _socketService.joinAuction(
      widget.auctionId,
      currentUserId,
      currentUserName,
      profilepic,
    );

    // Set up all socket listeners
    _setupSocketListeners();
    Future.delayed(Duration(milliseconds: 1000), () {
      _socketService.getChatHistory(widget.auctionId, currentUserId);
    });
  }

  void _onTypingChanged(bool isTyping) {
    if (!_socketService.isConnected) return;

    _socketService.sendTypingStatus(
      widget.auctionId,
      currentUserId,
      currentUserName,
      isTyping,
    );
  }

  void _setupSocketListeners() {
    print('🎧 Setting up socket listeners...');
    _socketService.onSpecificUserTeam((data) {
      print('🎯 Setting user team data: $data'); // Add this log
      if (mounted) {
        setState(() {
          _selectedUserTeam = data;
          print(
            '💾 Updated _selectedUserTeam: $_selectedUserTeam',
          ); // Add this log
        });
      }
    });

    _socketService.onNewChatMessage((data) {
      if (mounted) {
        final newMessage = {
          'id': data['id'],
          'userId': data['userId'],
          'userName': data['userName'],
          'message': data['message'],
          'timestamp': DateTime.parse(data['timestamp']),
          'isYou': data['userId'] == currentUserId,
        };

        // Keep only last 100 messages
        setState(() {
          _chatMessages = [
            ..._chatMessages,
            newMessage,
          ]; // Create new list to ensure update

          // Keep only last 100 messages
          if (_chatMessages.length > 100) {
            _chatMessages.removeAt(0);
          }
        });

        // Update stream for real-time updates
        _chatStreamController.add(List.from(_chatMessages));

        // Show toast notification for messages from other users
        if (data['userId'] != currentUserId) {
          _showChatMessageToast(data['userName'], data['message']);
        }

        print('💬 Added new chat message: ${data['message']}');
      }
    });

    _socketService.onChatHistory((data) {
      if (mounted) {
        setState(() {
          _chatMessages.clear();
          final messages = data['messages'] as List;
          _chatMessages.addAll(
            messages
                .map<Map<String, dynamic>>(
                  (msg) => {
                    'id': msg['id'],
                    'userId': msg['userId'],
                    'userName': msg['userName'],
                    'message': msg['message'],
                    'timestamp': DateTime.parse(msg['timestamp']),
                    'isYou': msg['userId'] == currentUserId,
                  },
                )
                .toList(),
          );
        });

        // Update stream
        _chatStreamController.add(List.from(_chatMessages));

        print('📜 Loaded chat history: ${_chatMessages.length} messages');
      }
    });

    _socketService.onUserTypingStatus((data) {
      if (mounted && data['userId'] != currentUserId) {
        setState(() {
          if (data['isTyping']) {
            _typingUsers[data['userId'].toString()] = true;
          } else {
            _typingUsers.remove(data['userId'].toString());
          }
        });

        // Update typing stream
        _typingStreamController.add(Map.from(_typingUsers));

        // Auto-remove typing status after 3 seconds
        Timer(Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _typingUsers.remove(data['userId'].toString());
            });
            _typingStreamController.add(Map.from(_typingUsers));
          }
        });
      }
    });
    _socketService.onUserTypingStatus((data) {
      if (mounted && data['userId'] != currentUserId) {
        setState(() {
          if (data['isTyping']) {
            _typingUsers[data['userId'].toString()] = true;
          } else {
            _typingUsers.remove(data['userId'].toString());
          }
        });

        // NEW: Update typing stream
        _typingStreamController.add(Map.from(_typingUsers));

        // Auto-remove typing status after 3 seconds
        Timer(Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _typingUsers.remove(data['userId'].toString());
            });
            _typingStreamController.add(Map.from(_typingUsers));
          }
        });
      }
    });

    print('✅ All socket listeners set up');

    // Listen for current player data
    _socketService.onCurrentPlayer((data) {
      print("📨 Current Player Data: $data");

      if (mounted) {
        final player = data['player'];
        final highestBid = data['highestBid'];
        final currentBid = data['currentBid'] ?? player['basePrice'];
        final highestBidder = data['highestBidder'] ?? "No bids yet";
        final liveBids = data['liveBids'] ?? [];

        setState(() {
          // Update current player with data from socket
          currentPlayer = {
            "id": player['id'],
            "name": player['name'] ?? 'Unknown Player',
            "image":
                player['image'] ??
                "https://www.hindustantimes.com/static-content/1y/cricket-logos/players/virat-kohli.png",
            "basePrice": player['basePrice'] ?? 0,
            "team": player['team'] ?? 'Unknown',
            "type": player['type'] ?? 'Unknown',
            "age": player['age'] ?? 0,
            "matches": player['matches'] ?? 0,
            "runs": player['runs'] ?? 0,
            "average": player['average'] ?? 0.0,
            "strikeRate": player['strikeRate'] ?? 0.0,
            "previousTeam": player['previousTeam'] ?? 'Unknown',
            "previousPrice": player['previousPrice'] ?? 0,
            "metadata": player['metadata'] ?? {},
          };

          // Update bid information
          this.currentBid = currentBid;
          this.highestBidder = highestBidder;

          // ✅ IMPORTANT: Clear and repopulate live bids
          _liveBids.clear();
          if (liveBids.isNotEmpty) {
            print(
              "📊 Populating ${liveBids.length} live bids for ${player['name']}",
            );
            _liveBids.addAll(
              liveBids.map<Map<String, dynamic>>((bid) {
                return {
                  'bidder': bid['bidder'],
                  'bidderId': bid['bidderId'],
                  'amount': bid['amount'],
                  'timestamp': DateTime.parse(bid['timestamp'].toString()),
                  'isYou': bid['bidderId'] == currentUserId,
                };
              }).toList(),
            );
          }

          // Reset timer and enable bidding
          canBid = true;
          _timeRemaining = data['timeRemaining'] ?? 12;
        });

        // Cancel existing timer and restart
        _startAuctionTimer();

        print(
          '✅ Current player data updated: ${player['name']} with ${_liveBids.length} live bids',
        );
      }
    });
    _socketService.onCurrentPlayerBids((data) {
      print("📨 Current Player Bids Data: $data");

      if (mounted && data['playerId'] == currentPlayer['id']) {
        final bids = data['bids'] ?? [];
        setState(() {
          _liveBids.clear();
          if (bids.isNotEmpty) {
            print("📊 Updating ${bids.length} current player bids");
            _liveBids.addAll(
              bids.map<Map<String, dynamic>>((bid) {
                return {
                  'bidder': bid['bidder'],
                  'bidderId': bid['bidderId'],
                  'amount': bid['amount'],
                  'timestamp': DateTime.parse(bid['timestamp'].toString()),
                  'isYou': bid['bidderId'] == currentUserId,
                };
              }).toList(),
            );
          }
        });
        print('📨 Updated current player bids: ${_liveBids.length} bids');
      }
    });

    // Listen for new bids
    _socketService.onNewBid((data) {
      if (mounted) {
        setState(() {
          currentBid = data['bidAmount'];
          highestBidder = data['bidder'];
          _timeRemaining = data['timeRemaining'] ?? 12;

          // Add to live bids list at the beginning (most recent first)
          _liveBids.insert(0, {
            'bidder': data['bidder'],
            'bidderId': data['bidderId'],
            'amount': data['bidAmount'],
            'timestamp': DateTime.now(),
            'isYou': data['bidderId'] == currentUserId,
          });

          // Keep only last 10 bids
          if (_liveBids.length > 10) {
            _liveBids = _liveBids.take(10).toList();
          }
        });

        _bidController.forward().then((_) => _bidController.reverse());
        _playBidSound();
        _showBidNotification(data['bidder'], data['bidAmount']);
      }
    });

    // Listen for new bids
    // _socketService.onNewBid((data) {
    //   if (mounted) {
    //     setState(() {
    //       currentBid = data['bidAmount'];
    //       highestBidder = data['bidder'];
    //       _timeRemaining = data['timeRemaining'] ?? 12;

    //       // Add to live bids list
    //       _liveBids.insert(0, {
    //         'bidder': data['bidder'],
    //         'amount': data['bidAmount'],
    //         'timestamp': DateTime.now(),
    //         'isYou': data['bidderId'] == currentUserId,
    //       });
    //       // Play bid success sound if it's your bid
    //       // if (data['bidderId'] == currentUserId) {

    //       // }
    //       _bidController.forward().then((_) => _bidController.reverse());
    //       _playBidSound();
    //       _showBidNotification(data['bidder'], data['bidAmount']);

    //       // Keep only last 10 bids
    //       if (_liveBids.length > 10) {
    //         _liveBids = _liveBids.take(10).toList();
    //       }
    //     });

    //     _bidController.forward().then((_) => _bidController.reverse());
    //     _showBidNotification(data['bidder'], data['bidAmount']);
    //   }
    // });

    // Listen for timer updates
    _socketService.onTimerUpdate((data) {
      if (mounted) {
        final newTime = data['timeRemaining'];
        if (newTime == 3) {
          print('🔊 Playing clock tick at 8 seconds');
          _playClockTick();
        }

        setState(() {
          _timeRemaining = newTime;
        });

        // Play clock tick at 8 seconds
        _timerController.forward().then((_) => _timerController.reverse());
      }
    });

    // Listen for auction ended
    _socketService.onAuctionEnded((data) {
      if (mounted) {
        // _auctionTimer?.cancel();
        setState(() {
          canBid = false;
          _timeRemaining = 0;
        });

        _showPlayerSoldDialog(data);
        _playSound('applause.mp3');
        _updateAuctionHistory(data);
      }
    });
    _socketService.onAuctionHistory((data) {
      if (mounted) {
        setState(() {
          auctionHistory = List<Map<String, dynamic>>.from(data['history']);
        });
        print('📜 Received auction history: ${auctionHistory.length} items');
      }
    });

    // Listen for user team data

    // Listen for new player auction
    _socketService.onNewPlayerAuction((data) {
      if (mounted) {
        setState(() {
          currentPlayer = {
            "id": data['currentPlayer']['id'],
            "name": data['currentPlayer']['name'],
            "basePrice": data['currentPlayer']['basePrice'],
            "team": data['currentPlayer']['team'] ?? 'Unknown',
            "type": data['currentPlayer']['type'],
            "age": data['currentPlayer']['age'] ?? 0,
            "matches": data['currentPlayer']['matches'] ?? 0,
            "runs": data['currentPlayer']['runs'] ?? 0,
            "average": data['currentPlayer']['average'] ?? 0.0,
            "strikeRate": data['currentPlayer']['strikeRate'] ?? 0.0,
            "previousTeam": data['currentPlayer']['previousTeam'] ?? 'Unknown',
            "previousPrice": data['currentPlayer']['previousPrice'] ?? 0,
            "metadata": data['currentPlayer']['metadata'] ?? {},
            "image":
                data['currentPlayer']['image'] ??
                "https://www.hindustantimes.com/static-content/1y/cricket-logos/players/virat-kohli.png",
          };
          currentBid = data['currentBid'];
          highestBidder = data['highestBidder'];
          _timeRemaining = data['timeRemaining'];
          canBid = true;

          // ✅ Clear bids for new player
          _liveBids.clear();
        });

        _startAuctionTimer();
      }
    });

    // Listen for users joining
    _socketService.onUserJoined((data) {
      if (mounted) {
        setState(() {
          // Check if user already exists to avoid duplicates
          bool userExists = _connectedUsers.any(
            (user) => user['userId'] == data['userId'],
          );
          if (!userExists) {
            _connectedUsers.add({
              'userId': data['userId'],
              'userName': data['userName'],
              'joinTime': DateTime.now(),
            });
          }
        });
        _playSound('user_enter.mp3');

        _showUserJoinedNotification(data['userName']);
      }
    });

    // Listen for users leaving
    _socketService.onUserLeft((data) {
      if (mounted) {
        setState(() {
          _connectedUsers.removeWhere(
            (user) => user['userId'] == data['userId'],
          );
        });
      }
    });
    _socketService.onConnectedUsers((data) {
      if (mounted) {
        setState(() {
          _connectedUsers = List<Map<String, dynamic>>.from(
            data['users'].map(
              (user) => {
                'userId': user['userId'],
                'userName': user['userName'],
                'joinTime': DateTime.now(),
              },
            ),
          );
        });
        print('👥 Updated connected users: ${_connectedUsers.length}');
      }
    });

    // Listen for auction state
    _socketService.onAuctionState((data) {
      if (mounted) {
        print('playerdtail=> $data');
        setState(() {
          if (data['currentPlayer'] != null) {
            final player = data['currentPlayer'];
            currentPlayer = {
              "id": player['id'],
              "name": player['name'],
              "basePrice": player['basePrice'],
              "team": player['team'] ?? 'Unknown',
              "type": player['type'],
              "age": player['age'] ?? 0,
              "matches": player['matches'] ?? 0,
              "runs": player['runs'] ?? 0,
              "average": player['average'] ?? 0.0,
              "strikeRate": player['strikeRate'] ?? 0.0,
              "previousTeam": player['previousTeam'] ?? 'Unknown',
              "previousPrice": player['previousPrice'] ?? 0,
              "metadata": player['metadata'] ?? {},
              "image":
                  player['image'] ??
                  "https://www.hindustantimes.com/static-content/1y/cricket-logos/players/virat-kohli.png",
            };
          }
          currentBid = data['currentBid'] ?? currentBid;
          highestBidder = data['highestBidder'] ?? highestBidder;
          _timeRemaining = data['timeRemaining'] ?? _timeRemaining;
        });
        print('📊 Auction state updated');
      }
    });

    // Listen for bid errors
    _socketService.onBidError((data) {
      if (mounted) {
        _showErrorSnackBar(data['message']);
      }
    });

    // Listen for auction completion
    _socketService.onAuctionCompleted((data) {
      if (mounted) {
        // _auctionTimer?.cancel();
        _showAuctionCompletedDialog(data['message']);
      }
    });
    _socketService.onUserBudget((data) {
      if (mounted) {
        setState(() {
          yourBudgetInfo = {
            'totalBudget': data['totalBudget'],
            'spentAmount': data['spentAmount'],
            'remainingBudget': data['remainingBudget'],
            'playersCount': data['playersCount'],
            'isActive': data['isActive'],
          };
        });
        print(
          '💰 Your budget updated: ₹${_formatCurrency(yourBudgetInfo['remainingBudget'])}',
        );
      }
    });
    _socketService.onUserTeam((data) {
      if (mounted) {
        setState(() {
          yourTeam = List<Map<String, dynamic>>.from(data['team']);
          // Update other team-related data if needed
        });
        print('👥 Received user team: ${yourTeam.length} players');
      }
    });

    // NEW: Listen for all users budget updates
    _socketService.onBudgetUpdated((data) {
      if (mounted) {
        setState(() {
          allUserBudgets = List<Map<String, dynamic>>.from(data['budgets']);

          // Update your own budget info from the list
          final myBudget = allUserBudgets.firstWhere(
            (budget) => budget['userId'] == currentUserId,
            orElse: () => {},
          );

          if (myBudget.isNotEmpty) {
            yourBudgetInfo = {
              'totalBudget': myBudget['totalBudget'],
              'spentAmount': myBudget['spentAmount'],
              'remainingBudget': myBudget['remainingBudget'],
              'playersCount': myBudget['playersCount'],
              'isActive': myBudget['isActive'],
            };
          }
        });
        print('📊 All budgets updated: ${allUserBudgets.length} users');
      }
    });
    _socketService.onAuctionStatsUpdated((data) {
      if (mounted) {
        setState(() {
          liveAuctionStats = data['stats'];
        });
        print(
          '📈 Auction stats updated: ${liveAuctionStats['soldPlayers']} sold',
        );
      }
    });

    print('✅ All socket listeners set up');
  }

  // Update the _placeBid method
  // Update the _placeBid method to accept increment amount
  void _placeBid(int incrementAmount) {
    if (!_socketService.isConnected) {
      _showErrorSnackBar('Not connected to auction server');
      return;
    } // Add this in _setupSocketListeners method
    // _socketService.onCurrentPlayerBids((data) {
    //   if (mounted && data['playerId'] == currentPlayer['id']) {
    //     final bids = data['bids'] ?? [];
    //     setState(() {
    //       _liveBids.clear();
    //       _liveBids.addAll(
    //         bids
    //             .map<Map<String, dynamic>>(
    //               (bid) => {
    //                 'bidder': bid['bidder'],
    //                 'bidderId': bid['bidderId'],
    //                 'amount': bid['amount'],
    //                 'timestamp': DateTime.parse(bid['timestamp'].toString()),
    //                 'isYou': bid['bidderId'] == currentUserId,
    //               },
    //             )
    //             .toList(),
    //       );
    //     });
    //     print('📨 Updated current player bids: ${_liveBids.length} bids');
    //   }
    // });

    final nextBidAmount = currentBid + incrementAmount;

    if (!canBid) {
      _showErrorSnackBar('Bidding is currently closed');
      return;
    }

    // Check against real-time budget
    if (nextBidAmount > yourBudgetInfo['remainingBudget']) {
      _showErrorSnackBar('Insufficient budget for this bid');
      return;
    }

    if (!yourBudgetInfo['isActive']) {
      _showErrorSnackBar('Your account is inactive');
      return;
    }

    print(
      '💰 Attempting to place bid: ₹${_formatCurrency(nextBidAmount)} (+₹${_formatCurrency(incrementAmount)})',
    );

    _socketService.placeBid(
      widget.auctionId,
      currentUserId,
      currentUserName,
      nextBidAmount,
      currentPlayer['id'],
    );
  }

  // Add method to update auction history from socket data
  void _updateAuctionHistory(Map<String, dynamic> data) {
    setState(() {
      auctionHistory.insert(0, {
        "player": data['playerName'],
        "team": data['winner'] ?? 'Unsold',
        "price": data['finalBid'] ?? 0,
        "status": data['winner'] != null ? "sold" : "unsold",
      });

      // Update your team if you won
      if (data['winnerId'] == currentUserId && data['winner'] != null) {
        yourTeam.add({
          "id": currentPlayer['id'],
          "name": data['playerName'],
          "role": currentPlayer['type'],
          "price": data['finalBid'],
          "team": currentPlayer['team'],
          "image": currentPlayer['image'],
        });
      }

      auctionStats['soldPlayers']++;
      auctionStats['totalSpent'] += data['finalBid'] ?? 0;
    });
  }

  // void _placeBid() {
  //   if (canBid && currentBid + 1000000 <= (yourBudget - yourSpent)) {
  //     _socketService.placeBid(
  //       widget.auctionId,
  //       currentUserId,
  //       currentUserName,
  //       currentBid + 1000000,
  //       currentPlayer['id'],
  //     );
  //   } else {
  //     _showErrorSnackBar('Cannot place bid. Check your budget or bid amount.');
  //   }
  // }

  void _showBidNotification(String bidder, int amount) {
    if (bidder != currentUserName) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$bidder bid ₹${_formatCurrency(amount)}'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.primaryColor,
        ),
      );
    }
  }

  void _showAuctionCompletedDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Color(0xFF1B4332),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Auction Completed!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              message,
              style: TextStyle(color: Color(0xFF95D5B2)),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to auction list
                },
                child: Text('OK', style: TextStyle(color: Color(0xFF95D5B2))),
              ),
            ],
          ),
    );
  }

  void _showUserJoinedNotification(String userName) {
    if (userName != currentUserName) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userName joined the auction'),
          duration: Duration(seconds: 1),
          backgroundColor: AppColors.primaryColor,
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatCurrency(int amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)} L';
    } else {
      return '₹${amount.toString()}';
    }
  }

  void dispose() {
    print('🗑️ Disposing AuctionDetailScreen...');

    // Leave the auction room first
    if (_socketService.isConnected) {
      _socketService.leaveAuction(
        widget.auctionId,
        currentUserId,
        currentUserName,
      );
    }

    // Remove all listeners
    _socketService.removeAllListeners();

    // Dispose animation controllers
    _timerController.dispose();
    _pulseController.dispose();
    _bidController.dispose();
    _audioPlayer.dispose();
    _clockTickPlayer.dispose();
    _sadSoundPlayer.dispose(); // Add this line

    // Cancel timer
    // _auctionTimer?.cancel();
    _chatStreamController.close();
    _typingStreamController.close();

    print('✅ AuctionDetailScreen disposed');
    super.dispose();
  }

  // Update the _startAuctionTimer method
  void _startAuctionTimer() {
    // _auctionTimer?.cancel();
    // _auctionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
    if (mounted) {
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
          if (_timeRemaining == 8) {
            _playClockTick();
          }

          _timerController.forward().then((_) => _timerController.reverse());
        } else {
          _onTimeUp();
        }
      });
    } else {
      // timer.cancel();
    }
    // });
  }

  void _onTimeUp() {
    // _auctionTimer?.cancel();
    setState(() {
      canBid = false;
    });
    print('⏰ Local timer expired, waiting for server confirmation');
  }

  void _simulateOtherBids() {
    Future.delayed(Duration(milliseconds: 1500), () {
      if (mounted && _timeRemaining > 112 && Random().nextBool()) {
        List<Map<String, dynamic>> activeBidders =
            teams
                .where(
                  (b) => b['isActive'] && b['remaining'] > currentBid + 1000000,
                )
                .toList();

        if (activeBidders.isNotEmpty) {
          var randomBidder =
              activeBidders[Random().nextInt(activeBidders.length)];
          setState(() {
            currentBid += 1000000;
            highestBidder = randomBidder['name'];
            _timeRemaining = 30;
          });
        }
      }
    });
  }

  void _skipPlayer() {
    // _auctionTimer?.cancel();
    _showNextPlayer();
  }

  void _showNextPlayer() {
    setState(() {
      currentPlayer = {
        "id": 2,
        "name": "MS Dhoni",
        "basePrice": 40000000,
        "team": "India",
        "type": "Wicket Keeper",
        "age": 42,
        "matches": 264,
        "runs": 4876,
        "average": 38.1,
        "strikeRate": 135.9,
        "previousTeam": "CSK",
        "previousPrice": 100000,
      };
      currentBid = currentPlayer['basePrice'];
      highestBidder = "No bids yet";
      _timeRemaining = 30;
      canBid = true;
    });
    _startAuctionTimer();
  }

  void _showTeamDetails(Map<String, dynamic> team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTeamDetailsSheet(team),
    );
  }

  void _showAuctionStats() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAuctionStatsSheet(),
    );
  }

  void _showYourTeam() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildYourTeamSheet(),
    );
  }

  void _showremainingPlayers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildRemainingPlayersSheet(),
    );
  }

  void _showAuctionHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAuctionHistorySheet(),
    );
  }

  void _handleReconnection() {
    print('🔄 Handling reconnection...');

    if (!_socketService.isConnected) {
      _socketService.connect();

      Future.delayed(Duration(milliseconds: 2000), () {
        if (_socketService.isConnected) {
          print('✅ Reconnected, rejoining auction...');
          _joinAuctionRoom();
        } else {
          print('❌ Reconnection failed');
          _showErrorSnackBar('Failed to reconnect to auction server');
        }
      });
    }
  }

  void _showPlayerSoldDialog(Map<String, dynamic> data) {
    final confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Start confetti immediately for impact
    if (data['winnerId'] != null) {
      // Start confetti for sold players
      confettiController.play();
      _playApplauseSound(); // Play applause for sold
    } else {
      // Play sad sound for unsold players
      _playSadSound();
    }

    // Auto-close timer
    Timer? autoCloseTimer;
    autoCloseTimer = Timer(const Duration(seconds: 3), () {
      if (Navigator.canPop(context)) {
        confettiController.stop();
        Navigator.pop(context);
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            autoCloseTimer?.cancel();
            confettiController.stop();
            return true;
          },
          child: Scaffold(
            backgroundColor: Colors.black.withOpacity(0.8),
            body: Stack(
              children: [
                // Subtle animated background
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors:
                          data['winner'] != null
                              ? [
                                const Color(0xFF0a0e27).withOpacity(0.9),
                                const Color(0xFF1a1a2e).withOpacity(0.95),
                                Colors.black.withOpacity(0.98),
                              ]
                              : [
                                const Color(0xFF2d1b1b).withOpacity(0.9),
                                const Color(0xFF1a0a0a).withOpacity(0.95),
                                Colors.black.withOpacity(0.98),
                              ],
                    ),
                  ),
                ),

                // Main content
                Center(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.5 + (value * 0.5),
                        child: Opacity(
                          opacity: value.clamp(0.0, 1.0),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            constraints: const BoxConstraints(maxWidth: 400),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 40,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Header section with status
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 28,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors:
                                          data['winnerId'] != null
                                              ? [
                                                const Color(0xFF4CAF50),
                                                const Color(0xFF2E7D32),
                                              ]
                                              : [
                                                const Color(0xFFFF5722),
                                                const Color(0xFFD84315),
                                              ],
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Status icon
                                      TweenAnimationBuilder<double>(
                                        duration: const Duration(
                                          milliseconds: 800,
                                        ),
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        curve: Curves.elasticOut,
                                        builder: (context, iconValue, child) {
                                          return Transform.scale(
                                            scale: iconValue,
                                            child: Container(
                                              width: 64,
                                              height: 64,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.3),
                                                  width: 2,
                                                ),
                                              ),
                                              child: Icon(
                                                data['winner'] != null
                                                    ? Icons.check_circle_outline
                                                    : Icons.cancel_outlined,
                                                color: Colors.white,
                                                size: 32,
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 16),

                                      // Status text
                                      Text(
                                        data['winnerId'] != null
                                            ? 'SOLD!'
                                            : 'UNSOLD',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Content section
                                Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      // Player name
                                      SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.3),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent:
                                                ModalRoute.of(
                                                  context,
                                                )!.animation!,
                                            curve: const Interval(
                                              0.3,
                                              0.8,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          '${data['playerName']}',
                                          style: const TextStyle(
                                            color: Color(0xFF1a1a2e),
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),

                                      const SizedBox(height: 24),

                                      // Divider
                                      Container(
                                        height: 1,
                                        width: 60,
                                        color: Colors.grey[300],
                                      ),

                                      const SizedBox(height: 24),

                                      // Sale/Unsold information
                                      if (data['winner'] != null) ...[
                                        // Winner information
                                        FadeTransition(
                                          opacity: Tween<double>(
                                            begin: 0.0,
                                            end: 1.0,
                                          ).animate(
                                            CurvedAnimation(
                                              parent:
                                                  ModalRoute.of(
                                                    context,
                                                  )!.animation!,
                                              curve: const Interval(
                                                0.5,
                                                1.0,
                                                curve: Curves.easeIn,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                'Sold to',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),

                                              const SizedBox(height: 8),

                                              data['winnerId'] == null
                                                  ? Text(
                                                    'No body',
                                                    style: const TextStyle(
                                                      color: Color(0xFF1a1a2e),
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  )
                                                  : Text(
                                                    '${data['winner']}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF1a1a2e),
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),

                                              const SizedBox(height: 20),

                                              // Price display
                                              TweenAnimationBuilder<double>(
                                                duration: const Duration(
                                                  milliseconds: 1000,
                                                ),
                                                tween: Tween(
                                                  begin: 0.0,
                                                  end: 1.0,
                                                ),
                                                curve: Curves.easeOutBack,
                                                builder: (
                                                  context,
                                                  priceValue,
                                                  child,
                                                ) {
                                                  return Transform.scale(
                                                    scale:
                                                        0.9 +
                                                        (priceValue * 0.1),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 24,
                                                            vertical: 16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        gradient:
                                                            const LinearGradient(
                                                              colors: [
                                                                Color(
                                                                  0xFFFFD700,
                                                                ),
                                                                Color(
                                                                  0xFFFFA500,
                                                                ),
                                                              ],
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: const Color(
                                                              0xFFFFD700,
                                                            ).withOpacity(0.3),
                                                            blurRadius: 15,
                                                            spreadRadius: 0,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  4,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        '₹${_formatCurrency(data['finalBid'])}',
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF1a1a2e,
                                                          ),
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else ...[
                                        // Unsold information
                                        FadeTransition(
                                          opacity: Tween<double>(
                                            begin: 0.0,
                                            end: 1.0,
                                          ).animate(
                                            CurvedAnimation(
                                              parent:
                                                  ModalRoute.of(
                                                    context,
                                                  )!.animation!,
                                              curve: const Interval(
                                                0.5,
                                                1.0,
                                                curve: Curves.easeIn,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                'No bids received',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),

                                              const SizedBox(height: 16),

                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  color: Colors.grey[50],
                                                  border: Border.all(
                                                    color: Colors.grey[200]!,
                                                  ),
                                                ),
                                                child: Text(
                                                  'Base Price: ₹${_formatCurrency(currentPlayer['basePrice'])}',
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 32),

                                      // Continue button and auto-close indicator
                                      ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.0,
                                          end: 1.0,
                                        ).animate(
                                          CurvedAnimation(
                                            parent:
                                                ModalRoute.of(
                                                  context,
                                                )!.animation!,
                                            curve: const Interval(
                                              0.7,
                                              1.0,
                                              curve: Curves.elasticOut,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            // Auto-close indicator
                                            Text(
                                              'Auto-closing in 3 seconds...',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),

                                            const SizedBox(height: 16),

                                            // Continue button
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  autoCloseTimer?.cancel();
                                                  confettiController.stop();
                                                  Navigator.pop(context);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF1a1a2e,
                                                  ),
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 16,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                child: const Text(
                                                  'Continue',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Confetti overlay (more subtle)
                if (data['winnerId'] != null)
                  Positioned.fill(
                    child: ConfettiWidget(
                      confettiController: confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      emissionFrequency: 0.005,
                      numberOfParticles: 50,
                      gravity: 0.3,
                      particleDrag: 0.05,
                      colors: const [
                        Color(0xFFFFD700),
                        Color(0xFF4CAF50),
                        Color(0xFF2196F3),
                        Color(0xFFFF9800),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      autoCloseTimer?.cancel();
      confettiController.dispose();
    });
  }

  void _sendChatMessage(String message) {
    if (!_socketService.isConnected) {
      _showErrorSnackBar('Not connected to chat server');
      return;
    }

    _socketService.sendChatMessage(
      widget.auctionId,
      currentUserId,
      currentUserName,
      message,
    );
  }

  void _openBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // IMPORTANT!

      isScrollControlled: true, // Optional: for full height
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: ChatBottomSheet(
            initialMessages: List.from(_chatMessages),
            initialTypingUsers: Map.from(_typingUsers),
            // Pass streams for real-time updates
            messagesStream: _chatStreamController.stream,
            typingUsersStream: _typingStreamController.stream,
            onSendMessage: _sendChatMessage,
            onTypingChanged: _onTypingChanged,
            currentUserName: currentUserName,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            colors: [AppColors.accentColor, AppColors.accentColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (currentPlayer['id'] < 0)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.deepPurple,
                        strokeWidth: 4,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading player data...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: Stack(
                    children: [
                      _buildBackground(),
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildMainContent(),
                            _buildActionButtons(),
                            _buildBiddersPanel(),
                            SizedBox(height: 14),
                            _buildLiveBidsPanel(),
                          ],
                        ),
                      ),
                      _buildTimer(),
                      _buildQuickActions(),
                      // YouTube-live style chat overlay
                      LiveChatOverlay(
                        messages: _chatMessages,
                        onSendMessage: _sendChatMessage,
                        currentUserName: currentUserName,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: Colors.white),
          ),
          Column(
            children: [
              Text(
                widget.auctionName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _showYourTeam,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    yourBudgetInfo['isActive']
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: yourBudgetInfo['isActive'] ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '₹${_formatCurrency(yourBudgetInfo['remainingBudget'])}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  // Text(
                  //   'Bid on (${yourBudgetInfo['playersCount']})',
                  //   style: TextStyle(color: Color(0xFF95D5B2), fontSize: 10),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Original background image
          Container(
            // decoration: BoxDecoration(
            //   image: DecorationImage(
            //     image: NetworkImage(currentPlayer['image']),
            //     fit: BoxFit.cover,
            //     opacity: 0.1,
            //   ),
            // ),
          ),
          // Animated green dots
          ...List.generate(25, (index) {
            return AnimatedPositioned(
              duration: Duration(seconds: 3 + (index % 4)),
              curve: Curves.easeInOut,
              left: (index * 47.0) % MediaQuery.of(context).size.width,
              top: (index * 73.0) % MediaQuery.of(context).size.height,
              child: TweenAnimationBuilder<double>(
                duration: Duration(seconds: 2 + (index % 3)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(
                      sin(value * 2 * pi + index) * 30,
                      cos(value * 3 * pi + index) * 40,
                    ),
                    child: Transform.scale(
                      scale: 0.5 + (sin(value * 4 * pi + index) * 0.3),
                      child: Container(
                        width: 8 + (index % 4) * 3,
                        height: 8 + (index % 4) * 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primaryColor.withOpacity(0.8),
                              AppColors.primaryColor.withOpacity(0.3),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.7, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                onEnd: () {
                  // Restart animation
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            );
          }),
          // Additional floating particles
          ...List.generate(15, (index) {
            return Positioned(
              left: (index * 83.0) % MediaQuery.of(context).size.width,
              top: (index * 97.0) % MediaQuery.of(context).size.height,
              child: TweenAnimationBuilder<double>(
                duration: Duration(seconds: 4 + (index % 2)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.linear,
                builder: (context, value, child) {
                  return Transform.rotate(
                    angle: value * 2 * pi,
                    child: Transform.translate(
                      offset: Offset(
                        cos(value * 3 * pi) * 25,
                        sin(value * 2 * pi) * 35,
                      ),
                      child: Container(
                        width: 4 + (index % 3) * 2,
                        height: 4 + (index % 3) * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF95D5B2).withOpacity(0.6),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF95D5B2).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                onEnd: () {
                  // Restart animation
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _timerController,
          builder: (context, child) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color:
                    _timeRemaining <= 10 ? Colors.red : AppColors.primaryColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: (_timeRemaining <= 10
                            ? Colors.red
                            : AppColors.primaryColor)
                        .withOpacity(0.5),
                    blurRadius: _timeRemaining <= 10 ? 15 : 10,
                    spreadRadius: _timeRemaining <= 10 ? 3 : 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, color: Colors.white, size: 20),
                  SizedBox(width: 5),
                  Text(
                    '${_timeRemaining}s',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 60),
          _buildPlayerCard(),
          SizedBox(height: 10),

          // _buildPlayerHistory(),
          // SizedBox(height: 10),
          _buildCurrentBid(),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildPlayerCard() {
    print('currentPlayer-> $currentPlayer');
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 280,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 90,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      currentPlayer['image'] != null
                          ? NetworkImage(currentPlayer['image'])
                          : null,
                  child:
                      currentPlayer['image'] == null
                          ? Text(
                            currentPlayer['name']
                                .toString()
                                .split(' ')
                                .map((n) => n.isNotEmpty ? n[0] : '')
                                .join(''),
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : null,
                ),
                SizedBox(height: 15),
                Text(
                  currentPlayer['name'],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${currentPlayer['type']} • ${currentPlayer['team']}',
                  style: TextStyle(color: Color(0xFF95D5B2), fontSize: 14),
                ),
                SizedBox(height: 15),
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceAround,
                //   children: [
                //     _buildStatColumn('Matches', '${currentPlayer['matches']}'),
                //     if (currentPlayer['runs'] != null &&
                //         currentPlayer['runs'] > 0)
                //       _buildStatColumn('Runs', '${currentPlayer['runs']}'),
                //     if (currentPlayer['average'] != null &&
                //         currentPlayer['average'] > 0)
                //       _buildStatColumn('Avg', '${currentPlayer['average']}'),
                //     if (currentPlayer['strikeRate'] != null &&
                //         currentPlayer['strikeRate'] > 0)
                //       _buildStatColumn('SR', '${currentPlayer['strikeRate']}'),
                //   ],
                // ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerHistory() {
    if (currentPlayer['previousTeam'] == null ||
        currentPlayer['previousPrice'] == null) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1B4332).withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, color: Color(0xFF95D5B2), size: 16),
          SizedBox(width: 5),
          Text(
            'Previous: ${currentPlayer['previousTeam']} (₹${_formatCurrency(currentPlayer['previousPrice'])})',
            style: TextStyle(color: Color(0xFF95D5B2), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(color: Color(0xFF95D5B2), fontSize: 10)),
      ],
    );
  }

  Widget _buildCurrentBid() {
    return AnimatedBuilder(
      animation: _bidAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _bidAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFF1B4332),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryColor, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  'Current Bid',
                  style: TextStyle(color: Color(0xFF95D5B2), fontSize: 14),
                ),
                Text(
                  '₹${_formatCurrency(currentBid)}',
                  style: TextStyle(
                    color: Colors.yellow,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Highest: $highestBidder',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                SizedBox(height: 5),
                Text(
                  'Base: ₹${_formatCurrency(currentPlayer['basePrice'])}',
                  style: TextStyle(color: Color(0xFF95D5B2), fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBiddersPanel() {
    return Container(
      height: 80, // Increased height for better visibility
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'BIDDERS (${_connectedUsers.length})',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child:
                _connectedUsers.isEmpty
                    ? Center(
                      child: Text(
                        'No other bidders',
                        style: TextStyle(
                          color: Color(0xFF95D5B2),
                          fontSize: 12,
                        ),
                      ),
                    )
                    : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _connectedUsers.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.only(right: 8),
                          child: _buildBidderItem(_connectedUsers[index]),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildBidderItem(Map<String, dynamic> user) {
    // Find budget info for this user
    final userBudget = allUserBudgets.firstWhere(
      (budget) => budget['userId'] == user['userId'],
      orElse:
          () => {'remainingBudget': 0, 'isActive': false, 'playersCount': 0},
    );

    return GestureDetector(
      onTap: () => _showUserBudgetDetails(user, userBudget),
      child: Container(
        width: 120,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFF1B4332).withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: userBudget['isActive'] ? Colors.green : Colors.grey,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user['userName'],
              style: TextStyle(
                color: userBudget['isActive'] ? Colors.white : Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              '₹${_formatCurrency(userBudget['remainingBudget'])}',
              style: TextStyle(
                color: userBudget['isActive'] ? Color(0xFF95D5B2) : Colors.grey,
                fontSize: 10,
              ),
            ),
            Text(
              '${userBudget['playersCount']} players',
              style: TextStyle(
                color: userBudget['isActive'] ? Color(0xFF95D5B2) : Colors.grey,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Positioned(
      left: 10,
      top: 100,
      child: Column(
        children: [
          _buildQuickActionButton(
            Icons.bar_chart,
            'Statistics',
            _showAuctionStats,
          ),
          SizedBox(height: 10),
          _buildQuickActionButton(
            Icons.history,
            'All History',
            _showAuctionHistory,
          ),
          SizedBox(height: 10),
          _buildQuickActionButton(Icons.group, 'My Players', _showYourTeam),
          SizedBox(height: 10),

          _buildQuickActionButton(
            Icons.navigate_next_outlined,
            'Remaining',
            _showremainingPlayers,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF1B4332),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Color(0xFF95D5B2), size: 20),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Color(0xFF95D5B2), fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBidsPanel() {
    if (_liveBids.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      height: 120,
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Bids',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _liveBids.length,
              itemBuilder: (context, index) {
                final bid = _liveBids[index];
                return Container(
                  margin: EdgeInsets.only(bottom: 4),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        bid['isYou']
                            ? AppColors.primaryColor.withOpacity(0.3)
                            : Color(0xFF1B4332).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          bid['isYou']
                              ? AppColors.primaryColor
                              : Color(0xFF95D5B2).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        bid['bidder'],
                        style: TextStyle(
                          color:
                              bid['isYou'] ? Colors.white : Color(0xFF95D5B2),
                          fontWeight:
                              bid['isYou']
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '₹${_formatCurrency(bid['amount'])}',
                        style: TextStyle(
                          color: Colors.yellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isConnected = _socketService.isConnected;

    return Container(
      width: MediaQuery.of(context).size.width * 0.95,
      child: Column(
        children: [
          // Connection status (optional - you can remove this if you don't want it)
          if (!isConnected)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 5),
                  Text(
                    'Disconnected',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Single bid button that shows options when clicked
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: isConnected && canBid ? _showBidOptions : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isConnected && canBid ? Colors.white : Colors.red,
                      foregroundColor:
                          isConnected && canBid
                              ? AppColors.secondaryaccentColor
                              : Colors.white,
                      shadowColor: Colors.black.withOpacity(0.3),
                      // padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: isConnected && canBid ? 8 : 1,
                      disabledBackgroundColor:
                          Colors.red, // This ensures disabled state shows red
                      disabledForegroundColor:
                          Colors.white, // This ensures disabled text is white
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.gavel,
                          color:
                              isConnected && canBid
                                  ? AppColors.secondaryaccentColor
                                  : Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          isConnected && canBid ? 'PLACE BID' : 'CANNOT BID',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color:
                                isConnected && canBid
                                    ? AppColors.secondaryaccentColor
                                    : Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(
                          isConnected && canBid
                              ? Icons.keyboard_arrow_up
                              : Icons.block,
                          color:
                              isConnected && canBid
                                  ? AppColors.secondaryaccentColor
                                  : Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _openBottomSheet(context),
                  icon: Icon(Icons.chat),
                  label: Text('Chat'),
                ),
              ],
            ),
          ),

          // Error messages and reconnect option
          if (!isConnected)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () {
                  _socketService.connect();
                  Future.delayed(Duration(milliseconds: 1000), () {
                    if (_socketService.isConnected) {
                      _joinAuctionRoom();
                    }
                  });
                },
                child: Text(
                  'Tap to reconnect',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Add this new method to show bid options
  void _showBidOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B4332), Color(0xFF0D1B2A)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                SizedBox(height: 20),

                // Title
                Text(
                  'Select Bid Amount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),

                // Current bid info
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    // color: AppColors.primaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.primaryColor.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Bid:',
                        style: TextStyle(
                          color: Color(0xFF95D5B2),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '₹${_formatCurrency(currentBid)}',
                        style: TextStyle(
                          color: Colors.yellow,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Bid increment buttons
                Column(
                  children: [
                    _buildBidOptionButton(
                      label: '+₹1L',
                      incrementAmount: 100000,
                      subtitle: '₹${_formatCurrency(currentBid + 100000)}',
                    ),
                    SizedBox(height: 12),
                    _buildBidOptionButton(
                      label: '+₹2L',
                      incrementAmount: 200000,
                      subtitle: '₹${_formatCurrency(currentBid + 200000)}',
                    ),
                    SizedBox(height: 12),
                    _buildCustomAmountButton(),
                  ],
                ),
                SizedBox(height: 20),

                // Cancel button
                Container(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
    );
  }

  Widget _buildBidOptionButton({
    required String label,
    required int incrementAmount,
    required String subtitle,
  }) {
    final nextBidAmount = currentBid + incrementAmount;
    final canAffordBid = nextBidAmount <= yourBudgetInfo['remainingBudget'];
    final isButtonEnabled =
        canBid && canAffordBid && yourBudgetInfo['isActive'];

    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed:
            isButtonEnabled
                ? () {
                  _playClickSound();
                  Navigator.pop(context);
                  _placeBid(incrementAmount);
                }
                : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isButtonEnabled ? AppColors.primaryColor : Colors.grey,
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isButtonEnabled ? 3 : 1,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.secondaryaccentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.secondaryaccentColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (!canAffordBid && canBid)
              Text(
                'Budget exceeded',
                style: TextStyle(
                  color: Colors.red[300],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              )
            else if (!yourBudgetInfo['isActive'])
              Text(
                'Account inactive',
                style: TextStyle(
                  color: Colors.red[300],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.secondaryaccentColor,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBidButton({
    required String label,
    required int incrementAmount,
    required bool isConnected,
  }) {
    final nextBidAmount = currentBid + incrementAmount;
    final canAffordBid = nextBidAmount <= (yourBudget - yourSpent);
    final isButtonEnabled = canBid && canAffordBid && isConnected;

    return Column(
      children: [
        ElevatedButton(
          onPressed: isButtonEnabled ? () => _placeBid(incrementAmount) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isButtonEnabled ? AppColors.primaryColor : Colors.grey,
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isButtonEnabled ? 3 : 1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '₹${_formatCurrency(nextBidAmount)}',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),

        // Show error message for individual button if needed
        if (!canAffordBid && canBid && isConnected)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Budget exceeded',
              style: TextStyle(color: Colors.red, fontSize: 8),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  // Bottom Sheet Builders
  // Bottom Sheet Builders (continued from the cut-off point)
  Widget _buildTeamDetailsSheet(Map<String, dynamic> team) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B4332), Color(0xFF0D1B2A)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 5,
            margin: EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        // color: team['color'],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          team['name'],
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team['userName'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Captain: ${team['captain']}',
                            style: TextStyle(
                              color: Color(0xFF95D5B2),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Coach: ${team['coach']}',
                            style: TextStyle(
                              color: Color(0xFF95D5B2),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTeamStatCard(
                        'Budget',
                        '₹${_formatCurrency(team['budget'])}',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildTeamStatCard(
                        'Remaining',
                        '₹${_formatCurrency(team['remaining'])}',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildTeamStatCard(
                        'Players',
                        '${team['playersCount']}/25',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildTeamStatCard(
                        'Status',
                        team['isActive'] ? 'Active' : 'Inactive',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  'Squad Composition',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildSlotCard(
                        'Batsman',
                        team['slotsRemaining']['batsman'],
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildSlotCard(
                        'Bowler',
                        team['slotsRemaining']['bowler'],
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildSlotCard(
                        'All-rounder',
                        team['slotsRemaining']['allrounder'],
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildSlotCard(
                        'WK',
                        team['slotsRemaining']['wicketkeeper'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Squad',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: team['players'].length,
                      itemBuilder: (context, index) {
                        var player = team['players'][index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      player['name'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      player['role'],
                                      style: TextStyle(
                                        color: Color(0xFF95D5B2),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${_formatCurrency(player['price'])}',
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamStatCard(String label, String value) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: TextStyle(color: Color(0xFF95D5B2), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSlotCard(String role, int remaining) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$remaining',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(role, style: TextStyle(color: Color(0xFF95D5B2), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAuctionStatsSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B4332), Color(0xFF0D1B2A)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 5,
            margin: EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live Auction Statistics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Players',
                        '${liveAuctionStats['totalPlayers']}',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'Sold Players',
                        '${liveAuctionStats['soldPlayers']}',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Unsold Players',
                        '${liveAuctionStats['unsoldPlayers']}',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'Participants',
                        '${liveAuctionStats['totalParticipants']}',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Highest Sale',
                        '₹${_formatCurrency(liveAuctionStats['highestSale'])}',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'Total Spent',
                        '₹${_formatCurrency(liveAuctionStats['totalSpent'])}',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Players',
                        '${liveAuctionStats['totalplayers']}',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'Remaining Players',
                        '${liveAuctionStats['remainingPlayerslength']}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(color: Color(0xFF95D5B2), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingPlayersSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B4332), Color(0xFF0D1B2A)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 5,
            margin: EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remaining Players',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 15),

                SizedBox(height: 15),
                Row(
                  children: [
                    Text(
                      'Remaining Players: ${liveAuctionStats['remainingPlayerslength']}',
                      style: TextStyle(color: Color(0xFF95D5B2), fontSize: 14),
                    ),
                    Spacer(),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child:
                  liveAuctionStats['remainingPlayers'].isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_add,
                              color: Color(0xFF95D5B2),
                              size: 60,
                            ),
                            SizedBox(height: 15),
                            Text(
                              'No players yet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ' players!',
                              style: TextStyle(
                                color: Color(0xFF95D5B2),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        itemCount:
                            liveAuctionStats['remainingPlayers']?.length ?? 0,
                        itemBuilder: (context, index) {
                          var player =
                              liveAuctionStats['remainingPlayers'][index];
                          print(
                            'Player data: $player',
                          ); // Debug the actual player data

                          return Container(
                            margin: EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryColor.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Player Image
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        player['imageurl'] ??
                                            '', // Changed from 'image' to 'imageurl'
                                      ),
                                      onBackgroundImageError:
                                          (e, s) => Icon(Icons.person),
                                      child:
                                          player['imageurl'] == null
                                              ? Text(player['name']?[0] ?? '?')
                                              : null,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 15),
                                // Player Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        player['name'] ?? 'Unknown Player',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        player['type'] ??
                                            '', // Changed from 'role' to 'type'
                                        style: TextStyle(
                                          color: Color(0xFF95D5B2),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Base Price (for remaining players)
                              ],
                            ),
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourTeamSheet() {
    print('players => => $yourTeam');

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B4332), Color(0xFF0D1B2A)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 5,
            margin: EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Team & Budget',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildTeamStatCard(
                        'Total Budget',
                        '₹${_formatCurrency(yourBudgetInfo['totalBudget'])}',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildTeamStatCard(
                        'Spent',
                        '₹${_formatCurrency(yourBudgetInfo['spentAmount'])}',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildTeamStatCard(
                        'Remaining',
                        '₹${_formatCurrency(yourBudgetInfo['remainingBudget'])}',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Text(
                      'Players: ${yourBudgetInfo['playersCount']}/25',
                      style: TextStyle(color: Color(0xFF95D5B2), fontSize: 14),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            yourBudgetInfo['isActive']
                                ? Colors.green
                                : Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        yourBudgetInfo['isActive'] ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child:
                  yourTeam.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_add,
                              color: Color(0xFF95D5B2),
                              size: 60,
                            ),
                            SizedBox(height: 15),
                            Text(
                              'No players yet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Start bidding to build your team!',
                              style: TextStyle(
                                color: Color(0xFF95D5B2),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        itemCount: yourTeam.length,
                        itemBuilder: (context, index) {
                          var player = yourTeam[index];

                          // Safely compute initials
                          String initials = '';
                          try {
                            initials = player['name']
                                .toString()
                                .trim()
                                .split(' ')
                                .where((n) => n.isNotEmpty)
                                .map((n) => n[0])
                                .join('');
                          } catch (e) {
                            print('Error computing initials: $e');
                            initials = '?';
                          }

                          return Container(
                            margin: EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryColor.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        player['image'] ?? '',
                                      ),
                                      child:
                                          player['image'] == null
                                              ? Text(player['name'][0])
                                              : null,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        player['name'] ?? '',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        player['role'] ?? '',
                                        style: TextStyle(
                                          color: Color(0xFF95D5B2),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${_formatCurrency(player['price'])}',
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuctionHistorySheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B4332), Color(0xFF0D1B2A)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 5,
            margin: EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Auction History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ListView.builder(
                itemCount: auctionHistory.length,
                itemBuilder: (context, index) {
                  var history = auctionHistory[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            history['status'] == 'sold'
                                ? AppColors.primaryColor.withOpacity(0.5)
                                : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color:
                                history['status'] == 'sold'
                                    ? Colors.green
                                    : Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                history['player'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                history['status'] == 'sold'
                                    ? 'Sold to ${history['team']}'
                                    : 'Unsold',
                                style: TextStyle(
                                  color: Color(0xFF95D5B2),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (history['status'] == 'sold')
                          Text(
                            '₹${_formatCurrency(history['price'])}',
                            style: TextStyle(
                              color: Colors.yellow,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserBudgetDetails(
    Map<String, dynamic> user,
    Map<String, dynamic> budget,
  ) {
    _socketService.requestUserTeam(user['userId'], widget.auctionId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B4332), Color(0xFF0D1B2A)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 5,
                  margin: EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color:
                                  budget['isActive']
                                      ? AppColors.primaryColor
                                      : Colors.grey,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Center(
                              child: Text(
                                user['userName']
                                    .toString()
                                    .split(' ')
                                    .map((n) => n[0])
                                    .join(''),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['userName'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        budget['isActive']
                                            ? Colors.green
                                            : Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    budget['isActive'] ? 'ACTIVE' : 'INACTIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTeamStatCard(
                              'Total Budget',
                              '₹${_formatCurrency(budget['totalBudget'] ?? 0)}',
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _buildTeamStatCard(
                              'Spent',
                              '₹${_formatCurrency(budget['spentAmount'] ?? 0)}',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTeamStatCard(
                              'Remaining',
                              '₹${_formatCurrency(budget['remainingBudget'] ?? 0)}',
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _buildTeamStatCard(
                              'Players',
                              '${budget['playersCount'] ?? 0}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(
                  color: Colors.white.withOpacity(0.1),
                  indent: 20,
                  endIndent: 20,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        'Team Players',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          '${budget['playersCount'] ?? 0} Players',
                          style: TextStyle(
                            color: Color(0xFF95D5B2),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      _selectedUserTeam == null
                          ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          )
                          : _selectedUserTeam!['team'].isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.group_off,
                                  color: Color(0xFF95D5B2),
                                  size: 60,
                                ),
                                SizedBox(height: 15),
                                Text(
                                  'No players yet',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            itemCount: _selectedUserTeam!['team'].length,
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            itemBuilder: (context, index) {
                              final player = _selectedUserTeam!['team'][index];
                              return Container(
                                margin: EdgeInsets.only(bottom: 10),
                                padding: EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor.withOpacity(
                                    0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primaryColor.withOpacity(
                                      0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        player['image'] ?? '',
                                      ),
                                      child:
                                          player['image'] == null
                                              ? Text(player['name'][0])
                                              : null,
                                    ),
                                    SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            player['name'],
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            player['role'],
                                            style: TextStyle(
                                              color: Color(0xFF95D5B2),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₹${_formatCurrency(player['price'])}',
                                      style: TextStyle(
                                        color: Colors.yellow,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }

  void _showChatMessageToast(String userName, String message) {
    // Limit message length for toast
    String displayMessage =
        message.length > 50 ? '${message.substring(0, 50)}...' : message;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
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
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    displayMessage,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 16),
          ],
        ),
        backgroundColor: Color(0xFF1B4332),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 16,
          right: 16,
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: Color(0xFF95D5B2),
          onPressed: () {
            _openBottomSheet(context);
          },
        ),
      ),
    );
  }

  Widget _buildCustomAmountButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context); // Close the bid options sheet
          _showCustomAmountDialog(); // Show custom amount dialog
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Amount',
                    style: TextStyle(
                      color: AppColors.secondaryaccentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Enter your bid amount',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryaccentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, size: 20, color: AppColors.secondaryaccentColor),
          ],
        ),
      ),
    );
  }

  void _showCustomAmountDialog() {
    final TextEditingController _customAmountController =
        TextEditingController();
    final FocusNode _focusNode = FocusNode();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => AlertDialog(
            backgroundColor: Color(0xFF1B4332),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Enter Custom Bid Amount',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current bid info
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryColor.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Bid:',
                        style: TextStyle(
                          color: Color(0xFF95D5B2),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '₹${_formatCurrency(currentBid)}',
                        style: TextStyle(
                          color: Colors.yellow,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Budget info
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Budget:',
                        style: TextStyle(
                          color: Color(0xFF95D5B2),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '₹${_formatCurrency(yourBudgetInfo['remainingBudget'])}',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Custom amount input
                TextField(
                  controller: _customAmountController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Enter bid amount',
                    labelStyle: TextStyle(color: Color(0xFF95D5B2)),
                    hintText: 'e.g., ${currentBid + 100000}',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixText: '₹',
                    prefixStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primaryColor.withOpacity(0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Helper text
                Text(
                  'Minimum bid: ₹${_formatCurrency(currentBid + 1)}',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  final String amountText = _customAmountController.text.trim();
                  if (amountText.isEmpty) {
                    _showErrorSnackBar('Please enter a bid amount');
                    return;
                  }

                  final int? customAmount = int.tryParse(amountText);
                  if (customAmount == null) {
                    _showErrorSnackBar('Please enter a valid number');
                    return;
                  }

                  if (customAmount <= currentBid) {
                    _showErrorSnackBar(
                      'Bid must be higher than current bid of ₹${_formatCurrency(currentBid)}',
                    );
                    return;
                  }

                  if (customAmount > yourBudgetInfo['remainingBudget']) {
                    _showErrorSnackBar(
                      'Bid exceeds your remaining budget of ₹${_formatCurrency(yourBudgetInfo['remainingBudget'])}',
                    );
                    return;
                  }

                  Navigator.pop(context);

                  // Place the custom bid
                  final incrementAmount = customAmount - currentBid;
                  _placeBid(incrementAmount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Place Bid'),
              ),
            ],
          ),
    ).then((_) {
      // Auto-focus the text field when dialog opens
      Future.delayed(Duration(milliseconds: 100), () {
        _focusNode.requestFocus();
      });
    });
  }
}

// Method to close all open dialogs when new player auction starts
void _closeAllOpenDialogs(context) {
  // Close any open dialogs by popping the navigation stack
  // This will close custom amount dialog, bid options sheet, etc.
  while (Navigator.canPop(context)) {
    try {
      Navigator.pop(context);
    } catch (e) {
      // If there's an error popping, break the loop to avoid infinite loop
      break;
    }
  }
}
