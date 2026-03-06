import 'package:auctiongame/constants.dart';
import 'package:auctiongame/screens/auctions/AuctionDetailScreen.dart';
import 'package:auctiongame/theme/appcolor.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuctionWidget extends StatefulWidget {
  final List<Map<String, dynamic>> auctions;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final String? currentUserId; // Add current user ID

  const AuctionWidget({
    super.key,
    required this.auctions,
    required this.isLoading,
    required this.onRefresh,
    this.currentUserId,
  });

  @override
  State<AuctionWidget> createState() => _AuctionWidgetState();
}

class _AuctionWidgetState extends State<AuctionWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Track registration status for each auction
  Map<String, bool> registrationStatus = {};
  Map<String, bool> registrationLoading = {};
  // Track participants and capacity per auction
  Map<String, int> participantCounts = {};
  Map<String, int?> capacities = {};

  // Track loading state for auction details
  Map<String, bool> isLoadingDetails = {};
  Map<String, dynamic> auctionDetails = {};

  // Track rules dialog visibility and auction details

  // Show rules dialog with auction details
  Future<void> _showRulesDialog(Map<String, dynamic> auction) async {
    final String auctionId = auction['id'].toString();
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          );
        },
      );

      // Fetch auction details
      final response = await http.get(
        Uri.parse('$serverurl/auction/$auctionId/details'),
        headers: {'Content-Type': 'application/json'},
      );

      // Close loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> details = jsonDecode(response.body)['data'];
        print('details==> $details');
        final entryAmount = details['entryAmount'] ?? 0;
        final minPlayers = details['minPlayers'] ?? 0;
        final totalPool = (entryAmount * minPlayers) * 0.8; // 20% reduction

        // Show rules dialog with fetched details
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Color(0xFF1E1E2D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Auction Rules',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInfoRow(
                      'Entry Amount:',
                      currencyFormat.format(entryAmount),
                    ),
                    _buildInfoRow('Max Number of participants:', '$minPlayers'),
                    _buildInfoRow(
                      'Counting Players:',
                      '${details['countedPlayers'] ?? 'Unlimited'}',
                    ),

                    // _buildInfoRow(
                    //   'Max Players Allowed:',
                    //   '${details['maxPlayerAllowed'] ?? 'Unlimited'}',
                    // ),
                    // _buildInfoRow(
                    //   'Max Players Allowed:',
                    //   '${details['maxPlayerAllowed'] ?? 'Unlimited'}',
                    // ),
                    // _buildInfoRow(
                    //   'Slots Booked:',
                    //   '${details['participantsCount'] ?? 0}/${details['minPlayers'] ?? 'N/A'}',
                    // ),
                    _buildInfoRow(
                      'Pool:',
                      '${currencyFormat.format(totalPool)} (after 20% reduction)',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Scoring:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    _buildInfoRow(
                      '• Run:',
                      '${details['runPoint'] ?? 1} point per run',
                    ),
                    _buildInfoRow(
                      '• Wicket:',
                      '${details['wicketPoint'] ?? 10} points',
                    ),
                    _buildInfoRow(
                      '• Captain Points:',
                      '${details['captainPoints'] ?? 'Not specified'}x points',
                    ),
                    _buildInfoRow(
                      '• Vice-Captain Points:',
                      '${details['viceCaptainPoints'] ?? 'Not specified'}x points',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close', style: TextStyle(color: Colors.blue)),
                ),
              ],
            );
          },
        );
      } else {
        throw Exception('Failed to load auction details');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load auction details. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    _slideController.forward();

    // Check registration status for all auctions
    _checkRegistrationStatus();
  }

  Future<void> _checkRegistrationStatus() async {
    for (var auction in widget.auctions) {
      await _checkUserRegistration(auction['id'].toString());
    }
  }

  Future<void> _checkUserRegistration(String auctionId) async {
    try {
      final response = await http.get(
        Uri.parse('$serverurl/auction/$auctionId/participants'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Participants response: ${data}'); // Debug log

        // Check if data structure is correct
        if (data['success'] == true && data['data'] != null) {
          final participants = data['data']['participants'] as List? ?? [];
          final totalCount =
              (data['data']['totalCount'] as num?)?.toInt() ??
              participants.length;
          final int? capacity =
              data['data']['capacity'] != null
                  ? (data['data']['capacity'] as num).toInt()
                  : null;

          bool isRegistered = false;
          if (widget.currentUserId != null) {
            isRegistered = participants.any((participant) {
              // More robust user ID comparison
              final participantUserId = participant['user']['id'].toString();
              final currentUserId = widget.currentUserId.toString();
              print(
                'Comparing: $participantUserId vs $currentUserId',
              ); // Debug log
              return participantUserId == currentUserId;
            });
          }

          setState(() {
            registrationStatus[auctionId] = isRegistered;
            participantCounts[auctionId] = totalCount;
            capacities[auctionId] = capacity;
          });

          print(
            'Registration status for $auctionId: $isRegistered, booked: $totalCount, capacity: ${capacity ?? '∞'}',
          ); // Debug log
        }
      } else {
        print('Failed to fetch participants: ${response.statusCode}');
        setState(() {
          registrationStatus[auctionId] = false;
          participantCounts[auctionId] = 0;
          capacities[auctionId] = null;
        });
      }
    } catch (error) {
      print('Error checking registration status: $error');
      setState(() {
        registrationStatus[auctionId] = false;
        participantCounts[auctionId] = 0;
        capacities[auctionId] = null;
      });
    }
  }

  Future<void> _registerForAuction(String auctionId, String auctionName) async {
    if (widget.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please login to register for auctions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      registrationLoading[auctionId] = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$serverurl/auction/$auctionId/join'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': int.parse(widget.currentUserId!)}),
      );

      print(
        'Registration response: ${response.statusCode} - ${response.body}',
      ); // Debug log

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Immediately update registration status
        setState(() {
          registrationStatus[auctionId] = true;
          registrationLoading[auctionId] = false;
        });

        // Also refresh the registration status from server
        await _checkUserRegistration(auctionId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully registered for $auctionName!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Registration failed');
      }
    } catch (error) {
      setState(() {
        registrationLoading[auctionId] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  String getStartTimeText(DateTime startTime) {
    final now = DateTime.now();
    final difference = startTime.difference(now);

    if (difference.inMinutes < 0) {
      return 'Started ${timeago.format(startTime)}';
    } else if (difference.inMinutes < 60 * 6) {
      return '${timeago.format(startTime, allowFromNow: true)}';
    } else {
      final formatted = DateFormat.jm().format(startTime);
      return 'Starts at $formatted';
    }
  }

  @override
  void didUpdateWidget(AuctionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Refresh registration status when auctions list changes
    if (oldWidget.auctions != widget.auctions) {
      _checkRegistrationStatus();
    }
  }

  // Show rules dialog with auction details
  //   void _showRulesDialog(Map<String, dynamic> auction) {
  //     // Calculate total pool
  //     final entryAmount = auction['entryAmount'] ?? 0;
  //     final minPlayers = auction['minPlayers'] ?? 0;
  //     final totalPool = (entryAmount * minPlayers) * 0.8; // 20% reduction

  //     final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  //     showDialog(
  //       context: context,
  //       builder: (BuildContext context) {
  //         return AlertDialog(
  //           backgroundColor: Color(0xFF1E1E2D),
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(20),
  //           ),
  //           title: Text(
  //             'Auction Rules',
  //             style: TextStyle(
  //               color: Colors.white,
  //               fontWeight: FontWeight.bold,
  //               fontSize: 20,
  //             ),
  //           ),
  //           content: SingleChildScrollView(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 _buildInfoRow(
  //                   'Entry Amount:',
  //                   currencyFormat.format(entryAmount),
  //                 ),
  //                 _buildInfoRow('Min Players:', '$minPlayers'),
  //                 _buildInfoRow(
  //                   'Max Players Allowed:',
  //                   '${auction['maxPlayerAllowed'] ?? 'Unlimited'}',
  //                 ),
  //                 _buildInfoRow(
  //                   'Total Pool:',
  //                   '${currencyFormat.format(totalPool)} (after 20% reduction)',
  //                 ),
  //                 SizedBox(height: 16),
  //                 Text(
  //                   'Scoring:',
  //                   style: TextStyle(
  //                     color: Colors.white,
  //                     fontWeight: FontWeight.bold,
  //                     fontSize: 16,
  //                   ),
  //                 ),
  //                 _buildInfoRow(
  //                   '• Run:',
  //                   '${auction['runPoint'] ?? 1} point per run',
  //                 ),
  //                 _buildInfoRow(
  //                   '• Wicket:',
  //                   '${auction['wicketPoint'] ?? 10} points',
  //                 ),
  //                 _buildInfoRow(
  //                   '• Captain Points:',
  //                   '${auction['captainPoints'] ?? 'Not specified'}x points',
  //                 ),
  //                 _buildInfoRow(
  //                   '• Vice-Captain Points:',
  //                   '${auction['viceCaptainPoints'] ?? 'Not specified'}x points',
  //                 ),
  //               ],
  //             ),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.of(context).pop(),
  //               child: Text('Close', style: TextStyle(color: Colors.blue)),
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //   }
  // //
  // Widget _buildInfoRow(String label, String value) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 6.0),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         Text(
  //           label,
  //           style: TextStyle(
  //             color: Colors.white.withOpacity(0.8),
  //             fontSize: 14,
  //           ),
  //         ),
  //         Text(
  //           value,
  //           style: TextStyle(
  //             color: Colors.white,
  //             fontWeight: FontWeight.w500,
  //             fontSize: 14,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildAuctionsList();
  }

  Widget _buildAuctionsList() {
    if (widget.isLoading && widget.auctions.isEmpty) {
      return _buildLoadingState();
    }

    if (widget.auctions.isEmpty && !widget.isLoading) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.primaryColor,
      backgroundColor: AppColors.accentColor,
      strokeWidth: 3,
      displacement: 60,
      child: CustomScrollView(
        physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // Refresh indicator space
          if (widget.isLoading)
            SliverToBoxAdapter(child: _buildRefreshIndicator()),

          // Content
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      _buildLiveAuctions(),
                      SizedBox(height: 0),
                      _buildUpcomingAuctions(),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [AppColors.primaryColor.withOpacity(0.1), Colors.transparent],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: AppColors.primaryColor,
                      strokeWidth: 3,
                      backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading Auctions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Finding the best deals for you...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.primaryColor,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.sports_cricket,
                        size: 80,
                        color: AppColors.primaryColor.withOpacity(0.8),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'No Auctions Available',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'New auctions will appear here soon.\nPull down to refresh and check for updates.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value * 0.8,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.primaryColor.withOpacity(0.6),
                              size: 32,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AppColors.primaryColor,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Refreshing auctions...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveAuctions() {
    final liveAuctions =
        widget.auctions.where((a) => a['status'] == 'ongoing').toList();

    if (liveAuctions.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.withValues(alpha: 0.3),
                AppColors.accentColor,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(
                            _pulseAnimation.value * 0.5,
                          ),
                          blurRadius: _pulseAnimation.value * 8,
                          spreadRadius: _pulseAnimation.value * 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(width: 12),
              Text(
                'LIVE AUCTIONS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.2,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${liveAuctions.length}',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        ...liveAuctions.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> auction = entry.value;
          return AnimatedContainer(
            duration: Duration(milliseconds: 300 + (index * 100)),
            curve: Curves.easeOutBack,
            child: _buildLiveAuctionCard(auction),
          );
        }),
      ],
    );
  }

  Widget _buildLiveAuctionCard(Map<String, dynamic> auction) {
    final auctionId = auction['id'].toString();
    final isRegistered = registrationStatus[auctionId] ?? false;
    final isLoading = registrationLoading[auctionId] ?? false;
    final int booked = participantCounts[auctionId] ?? 0;
    final int? capacity = capacities[auctionId];
    final bool isFull = capacity != null && booked >= capacity;

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryColor.withOpacity(0.6),
                AppColors.secondaryaccentColor.withOpacity(0.4),
                AppColors.secondaryColor.withOpacity(0.9),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: Container(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auction['name'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Active ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 15),

                // Stats Row
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildStatItem(
                        Icons.currency_rupee_rounded,
                        // '300',
                        auction['entryAmount'].toString() ?? 'NA',
                        'Entry fee',
                      ),
                      _buildDivider(),

                      _buildStatItem(
                        Icons.group_rounded,
                        capacities[auctionId] != null
                            ? '${participantCounts[auctionId] ?? 0}/${capacities[auctionId]}'
                            : '${participantCounts[auctionId] ?? 0}',
                        'Slots booked',
                      ),
                      // _buildDivider(),
                      // _buildStatItem(
                      //   Icons.people_outline_rounded,
                      //   '${auction['maxPlayers']}',
                      //   'Max',
                      // ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Action Button
                Container(
                  width: double.infinity,
                  height: 40,
                  child: Builder(
                    builder: (context) {
                      // Check if user is logged in
                      if (widget.currentUserId == null) {
                        return ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please login to participate in auctions',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Login Required'),
                        );
                      }

                      // Check registration status
                      final isRegistered =
                          registrationStatus[auctionId] ?? false;
                      final isLoading = registrationLoading[auctionId] ?? false;

                      if (isRegistered) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                          children: [
                            Flexible(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  _showRulesDialog(auction);

                                  // your logic here
                                },

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.rule, size: 18),
                                    SizedBox(width: 8),
                                    Text('Rules'),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              flex: 3,

                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => Auctiondetailscreen(
                                            auctionId: auction['id'],
                                            auctionName: auction['name'],
                                          ),
                                    ),
                                  ).then(
                                    (_) => widget.onRefresh(),
                                  ); // Refresh after returning
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primaryColor,
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  '   Join Now   ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.secondaryaccentColor,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Flexible(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  _showRulesDialog(auction);
                                  // your logic here
                                },

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.rule, size: 18),
                                    SizedBox(width: 8),
                                    Text('Rules'),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              flex: 3,
                              child: ElevatedButton(
                                onPressed:
                                    (isLoading || isFull)
                                        ? null
                                        : () => _registerForAuction(
                                          auctionId,
                                          auction['name'],
                                        ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child:
                                    isLoading
                                        ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text('Registering...'),
                                          ],
                                        )
                                        : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isFull
                                                  ? Icons.lock
                                                  : Icons.person_add,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              isFull
                                                  ? (capacity != null
                                                      ? 'Slots Full (${booked}/${capacity})'
                                                      : 'Slots Full')
                                                  : 'Register',
                                            ),
                                          ],
                                        ),

                                // ),
                                // Flexible(
                                //   flex: 2,
                                //   child: ElevatedButton(
                                //     onPressed: () {
                                //       _showRulesDialog(auction);
                                //       // your logic here
                                //     },

                                //     style: ElevatedButton.styleFrom(
                                //       backgroundColor: Colors.blue,
                                //       foregroundColor: Colors.white,
                                //       elevation: 8,
                                //       shadowColor: Colors.black
                                //           .withOpacity(0.3),
                                //       shape: RoundedRectangleBorder(
                                //         borderRadius:
                                //             BorderRadius.circular(
                                //               10,
                                //             ),
                                //       ),
                                //     ),
                                //     child: Row(
                                //       mainAxisAlignment:
                                //           MainAxisAlignment.center,
                                //       children: [
                                //         Icon(Icons.rule, size: 18),
                                //         SizedBox(width: 8),
                                //         Text('Rules'),
                                //       ],
                                //     ),
                                //   ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      margin: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildUpcomingAuctions() {
    final upcomingAuctions =
        widget.auctions.where((a) => a['status'] == 'upcoming').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: AppColors.primaryColor.withOpacity(0.8),
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'UPCOMING AUCTIONS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.2,
                ),
              ),
              Spacer(),
              if (upcomingAuctions.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${upcomingAuctions.length}',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 20),
        ...(upcomingAuctions.isNotEmpty
            ? upcomingAuctions.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> auction = entry.value;
              return AnimatedContainer(
                duration: Duration(milliseconds: 400 + (index * 100)),
                curve: Curves.easeOutBack,
                child: _buildUpcomingAuctionCard(auction),
              );
            }).toList()
            : [_buildNoUpcomingAuctions()]),
      ],
    );
  }

  Widget _buildUpcomingAuctionCard(Map<String, dynamic> auction) {
    final auctionId = auction['id'].toString();
    final isRegistered = registrationStatus[auctionId] ?? false;
    final isLoading = registrationLoading[auctionId] ?? false;
    final int booked = participantCounts[auctionId] ?? 0;
    final int? capacity = capacities[auctionId];
    final bool isFull = capacity != null && booked >= capacity;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auction['name'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      // Text(
                      //   auction['type'],
                      //   style: TextStyle(
                      //     color: Colors.white.withOpacity(0.6),
                      //     fontSize: 13,
                      //     fontWeight: FontWeight.w500,
                      //   ),
                      // ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'UPCOMING',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: AppColors.primaryColor.withOpacity(0.8),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    getStartTimeText(DateTime.parse(auction['startTime'])),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Action Button for Upcoming Auctions
            SizedBox(
              width: double.infinity,
              height: 44,
              child: Builder(
                builder: (context) {
                  // Check if user is logged in
                  if (widget.currentUserId == null) {
                    return ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please login to register for auctions',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Login Required'),
                    );
                  }

                  // Check registration status
                  if (isRegistered) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () => _showRulesDialog(auction),
                          child: Container(
                            padding: EdgeInsets.all(12),

                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.rule_outlined,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Rules',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'REGISTERED',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ✅ REGISTER button (green)
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                (isLoading || isFull)
                                    ? null
                                    : () => _registerForAuction(
                                      auctionId,
                                      auction['name'],
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            child:
                                isLoading
                                    ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('REGISTERING...'),
                                      ],
                                    )
                                    : isFull
                                    ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.lock, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          capacity != null
                                              ? 'SLOTS FULL (${booked}/${capacity})'
                                              : 'SLOTS FULL',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    )
                                    : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_add_outlined,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'REGISTER',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),

                        SizedBox(width: 12),

                        // ✅ Rules button (blue outlined)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () => _showRulesDialog(auction),

                            child: Row(
                              children: [
                                Icon(
                                  Icons.rule_outlined,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Rules',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoUpcomingAuctions() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.schedule_rounded,
            color: Colors.white.withOpacity(0.4),
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'No Upcoming Auctions',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'New auctions will be scheduled soon.\nStay tuned for exciting opportunities!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
