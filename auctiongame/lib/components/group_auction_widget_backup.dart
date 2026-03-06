import 'package:auctiongame/constants.dart';
import 'package:auctiongame/screens/auctions/AuctionDetailScreen.dart';
import 'package:auctiongame/screens/auctions/AuctionListScreen.dart';
import 'package:auctiongame/theme/appcolor.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GroupAuctionWidget extends StatefulWidget {
  final String? currentUserId;
  final Future<void> Function() onRefresh;

  const GroupAuctionWidget({
    super.key,
    this.currentUserId,
    required this.onRefresh,
  });

  @override
  State<GroupAuctionWidget> createState() => _GroupAuctionWidgetState();
}

class _GroupAuctionWidgetState extends State<GroupAuctionWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  List<Map<String, dynamic>> playerGroups = [];
  Map<String, List<Map<String, dynamic>>> groupsByCategory = {};
  Map<String, List<Map<String, dynamic>>> groupAuctions = {};
  Map<String, bool> registrationStatus = {};
  Map<String, bool> registrationLoading = {};
  bool isLoading = true;
  String? error;

  // Static tabs as requested
  final List<String> categories = ['Cricket', 'Football', 'Baseball'];
  String? selectedGroup;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeTabController();
    _fetchPlayerGroups();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _initializeTabController() {
    _tabController = TabController(length: categories.length, vsync: this);
  }

  Future<void> _fetchPlayerGroups() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      print('🔄 Fetching player groups from: $serverurl/player/groups');

      final response = await http.get(
        Uri.parse('$serverurl/player/groups'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📡 Parsed data: $data');

        if (data['success'] == true) {
          final groups = List<Map<String, dynamic>>.from(data['data']);

          print('✅ Fetched ${groups.length} player groups');

          if (groups.isEmpty) {
            print('⚠️ No groups found! This might be why nothing is showing.');
            print(
              '⚠️ Check if there are players with playerGroup field set in the database.',
            );
          }

          for (var group in groups) {
            print('📋 Full group data: $group');
            print(
              '📋 Group: ${group['groupName']} - Category: ${group['category']} - Players: ${group['playerCount']}',
            );
          }

          setState(() {
            playerGroups = groups;
          });

          // Process groups by category
          await _processGroupsByCategory(groups);

          // Fetch auctions for each group
          await _fetchAuctionsForAllGroups(groups);

          // Check registration status for all auctions
          await _checkAllRegistrationStatus();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch player groups');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
      print('❌ Error fetching player groups: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _processGroupsByCategory(
    List<Map<String, dynamic>> groups,
  ) async {
    Map<String, List<Map<String, dynamic>>> tempGroupsByCategory = {};

    // Initialize all static categories
    for (String category in categories) {
      tempGroupsByCategory[category] = [];
    }

    for (var group in groups) {
      final category = group['category'] ?? 'Unknown';
      print(
        '🔍 Processing group: ${group['groupName']} with category: $category',
      );

      // Check if category matches our static categories (case insensitive)
      String? matchedCategory;
      for (String staticCategory in categories) {
        if (staticCategory.toLowerCase() == category.toLowerCase()) {
          matchedCategory = staticCategory;
          break;
        }
      }

      if (matchedCategory != null) {
        tempGroupsByCategory[matchedCategory]!.add(group);
        print(
          '✅ Added group ${group['groupName']} to category $matchedCategory',
        );
      } else {
        print(
          '⚠️ Category $category not found in static categories: $categories',
        );
      }
    }

    print(
      '📊 Groups by category: ${tempGroupsByCategory.map((k, v) => MapEntry(k, v.length))}',
    );

    setState(() {
      groupsByCategory = tempGroupsByCategory;
    });
  }

  Future<void> _fetchAuctionsForAllGroups(
    List<Map<String, dynamic>> groups,
  ) async {
    Map<String, List<Map<String, dynamic>>> tempGroupAuctions = {};

    for (var group in groups) {
      final groupName = group['groupName'];
      print('🎯 Fetching auctions for group: $groupName');

      try {
        // Fetch all auctions
        final auctionsResponse = await http.get(
          Uri.parse('$serverurl/auction'),
          headers: {'Content-Type': 'application/json'},
        );

        if (auctionsResponse.statusCode == 200) {
          final auctionsData = json.decode(auctionsResponse.body);
          if (auctionsData['success'] == true) {
            final allAuctions = List<Map<String, dynamic>>.from(
              auctionsData['data'],
            );

            // For now, show all auctions for each group
            List<Map<String, dynamic>> groupAuctionsList = [];
            for (var auction in allAuctions) {
              groupAuctionsList.add({
                'id': auction['id'],
                'name': auction['name'],
                'status': auction['status'],
                'category': auction['category'],
                'type': auction['type'],
                'startTime': auction['startTime'],
              });
            }

            tempGroupAuctions[groupName] = groupAuctionsList;
            print(
              '  📋 Found ${groupAuctionsList.length} auctions for $groupName',
            );
          }
        }
      } catch (e) {
        print('❌ Error fetching auctions for group $groupName: $e');
        tempGroupAuctions[groupName] = [];
      }
    }

    setState(() {
      groupAuctions = tempGroupAuctions;
    });
  }

  Future<void> _checkAllRegistrationStatus() async {
    if (widget.currentUserId == null) return;

    for (var auctions in groupAuctions.values) {
      for (var auction in auctions) {
        await _checkUserRegistration(auction['id'].toString());
      }
    }
  }

  Future<void> _checkUserRegistration(String auctionId) async {
    if (widget.currentUserId == null) return;

    try {
      final response = await http.get(
        Uri.parse('$serverurl/auction/$auctionId/participants'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final participants = data['data']['participants'] as List? ?? [];
          final isRegistered = participants.any((participant) {
            final participantUserId = participant['user']['id'].toString();
            final currentUserId = widget.currentUserId.toString();
            return participantUserId == currentUserId;
          });

          setState(() {
            registrationStatus[auctionId] = isRegistered;
          });
        }
      }
    } catch (error) {
      print('Error checking registration status: $error');
      setState(() {
        registrationStatus[auctionId] = false;
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

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          registrationStatus[auctionId] = true;
          registrationLoading[auctionId] = false;
        });

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
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchPlayerGroups();
        await widget.onRefresh();
      },
      color: AppColors.primaryColor,
      backgroundColor: AppColors.accentColor,
      strokeWidth: 3,
      displacement: 60,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (error != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        // Static Sport Tabs
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(width: 3.0, color: AppColors.primaryColor),
              insets: EdgeInsets.symmetric(horizontal: 16.0),
            ),
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_cricket, size: 16),
                    SizedBox(width: 6),
                    Text('Cricket'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_soccer, size: 16),
                    SizedBox(width: 6),
                    Text('Football'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_baseball, size: 16),
                    SizedBox(width: 6),
                    Text('Baseball'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Debug Info
        if (playerGroups.isNotEmpty)
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children:
                  categories.map((category) {
                    return _buildCategoryContent(category);
                  }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryContent(String category) {
    final groups = groupsByCategory[category] ?? [];

    if (selectedGroup != null) {
      // Show auctions for selected group
      return _buildGroupAuctions(selectedGroup!);
    }

    // Show groups for this category
    return CustomScrollView(
      physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildCategoryHeader(category, groups.length),
              SizedBox(height: 20),
              if (groups.isEmpty)
                _buildNoGroupsForCategory(category)
              else
                ...groups.map((group) => _buildGroupCard(group)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryHeader(String category, int groupCount) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withOpacity(0.8),
            AppColors.secondaryaccentColor.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(_getCategoryIcon(category), color: Colors.white, size: 24),
          SizedBox(width: 12),
          Text(
            '${category.toUpperCase()} GROUPS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$groupCount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoGroupsForCategory(String category) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          Icon(
            _getCategoryIcon(category),
            color: Colors.white.withOpacity(0.4),
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'No ${category} Groups Found',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Player groups for ${category} will appear here when available.\n\n'
            'Make sure players have been uploaded with playerGroup field set.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'cricket':
        return Icons.sports_cricket;
      case 'football':
        return Icons.sports_soccer;
      case 'baseball':
        return Icons.sports_baseball;
      default:
        return Icons.sports;
    }
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final groupName = group['groupName'];
    final playerCount = group['playerCount'];
    final auctions = groupAuctions[groupName] ?? [];
    final auctionCount = auctions.length;
    final liveAuctions = auctions.where((a) => a['status'] == 'ongoing').length;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              selectedGroup = groupName;
            });
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                            groupName ?? 'Unknown Group',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '$playerCount players',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.primaryColor,
                      size: 16,
                    ),
                  ],
                ),

                SizedBox(height: 16),

                Row(
                  children: [
                    _buildStatChip(
                      '$auctionCount Auctions',
                      Icons.sports_cricket,
                    ),
                    SizedBox(width: 12),
                    if (liveAuctions > 0)
                      _buildStatChip(
                        '$liveAuctions Live',
                        Icons.circle,
                        Colors.red,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String text, IconData icon, [Color? color]) {
    final chipColor = color ?? AppColors.primaryColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: chipColor, size: 14),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupAuctions(String groupName) {
    final auctions = groupAuctions[groupName] ?? [];
    final liveAuctions =
        auctions.where((a) => a['status'] == 'ongoing').toList();
    final upcomingAuctions =
        auctions.where((a) => a['status'] == 'upcoming').toList();

    return CustomScrollView(
      physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              setState(() {
                selectedGroup = null;
              });
            },
          ),
          title: Text(
            groupName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          floating: true,
          snap: true,
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (liveAuctions.isNotEmpty) ...[
                _buildSectionHeader(
                  'LIVE AUCTIONS',
                  liveAuctions.length,
                  Colors.red,
                ),
                SizedBox(height: 12),
                ...liveAuctions.map(
                  (auction) => _buildAuctionCard(auction, true),
                ),
                SizedBox(height: 20),
              ],
              if (upcomingAuctions.isNotEmpty) ...[
                _buildSectionHeader(
                  'UPCOMING AUCTIONS',
                  upcomingAuctions.length,
                  AppColors.primaryColor,
                ),
                SizedBox(height: 12),
                ...upcomingAuctions.map(
                  (auction) => _buildAuctionCard(auction, false),
                ),
              ],
              if (auctions.isEmpty) _buildNoAuctionsMessage(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        if (title.contains('LIVE'))
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(_pulseAnimation.value * 0.5),
                      blurRadius: _pulseAnimation.value * 6,
                      spreadRadius: _pulseAnimation.value * 1,
                    ),
                  ],
                ),
              );
            },
          )
        else
          Icon(Icons.schedule_rounded, color: color, size: 16),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuctionCard(Map<String, dynamic> auction, bool isLive) {
    final auctionId = auction['id'].toString();
    final isRegistered = registrationStatus[auctionId] ?? false;
    final isLoading = registrationLoading[auctionId] ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient:
            isLive
                ? LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.1),
                    AppColors.primaryColor.withOpacity(0.05),
                  ],
                )
                : null,
        color: isLive ? null : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isLive
                  ? Colors.red.withOpacity(0.3)
                  : AppColors.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
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
                        auction['name'] ?? 'Unknown Auction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        auction['type'] ?? 'Auction',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLive)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            if (!isLive && auction['startTime'] != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: AppColors.primaryColor.withOpacity(0.8),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      getStartTimeText(DateTime.parse(auction['startTime'])),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 16),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: _buildActionButton(
                auction,
                isRegistered,
                isLoading,
                isLive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    Map<String, dynamic> auction,
    bool isRegistered,
    bool isLoading,
    bool isLive,
  ) {
    final auctionId = auction['id'].toString();

    if (widget.currentUserId == null) {
      return ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please login to participate in auctions'),
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

    if (isRegistered) {
      if (isLive) {
        return ElevatedButton(
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
            ).then((_) => widget.onRefresh());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Join Auction',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );
      } else {
        return Container(
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
                Icon(Icons.check_circle, color: Colors.green, size: 20),
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
        );
      }
    } else {
      return ElevatedButton(
        onPressed:
            isLoading
                ? null
                : () => _registerForAuction(auctionId, auction['name']),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            isLoading
                ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add_outlined, size: 18),
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
      );
    }
  }

  Widget _buildNoAuctionsMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.sports_cricket,
            color: Colors.white.withOpacity(0.4),
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'No Auctions Available',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Auctions for this group will appear here soon.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
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
                    'Loading Player Groups',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Fetching groups and auctions...',
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

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Error Loading Groups',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPlayerGroups,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
