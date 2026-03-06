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
  bool isLoading = true;
  String? error;

  // Static tabs as requested
  final List<String> categories = ['Cricket', 'Football'];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeTabController();
    _fetchPlayerGroupsOptimized();
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

  Future<void> _handleRefresh() async {
    print('🔄 Manual refresh triggered');
    await _fetchPlayerGroupsOptimized();
    await widget.onRefresh();
  }

  Future<void> _fetchPlayerGroupsOptimized() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      print(
        '🔄 Fetching player groups with auctions from: $serverurl/player/groups-with-auctions',
      );

      // Build URL with userId parameter if available
      String url = '$serverurl/player/groups-with-auctions';
      if (widget.currentUserId != null) {
        url += '?userId=${widget.currentUserId}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📡 Parsed data keys: ${data.keys}');

        if (data['success'] == true) {
          final groups = List<Map<String, dynamic>>.from(data['data']);

          print('✅ Fetched ${groups.length} player groups with auctions');

          if (groups.isEmpty) {
            print('⚠️ No groups found! This might be why nothing is showing.');
            print(
              '⚠️ Check if there are players with playerGroup field set in the database.',
            );
          }

          // Process the optimized response
          Map<String, List<Map<String, dynamic>>> tempGroupsByCategory = {};
          Map<String, List<Map<String, dynamic>>> tempGroupAuctions = {};
          Map<String, bool> tempRegistrationStatus = {};

          // Initialize all static categories
          for (String category in categories) {
            tempGroupsByCategory[category] = [];
          }

          for (var group in groups) {
            final category = group['category'] ?? 'Unknown';
            final groupName = group['groupName'];
            final auctions = List<Map<String, dynamic>>.from(
              group['auctions'] ?? [],
            );

            print(
              '📋 Group: $groupName - Category: $category - Players: ${group['playerCount']} - Auctions: ${auctions.length}',
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
              tempGroupAuctions[groupName] = auctions;

              // Process registration status from the response
              for (var auction in auctions) {
                final auctionId = auction['id'].toString();
                tempRegistrationStatus[auctionId] =
                    auction['isRegistered'] ?? false;
              }

              print(
                '✅ Added group $groupName to category $matchedCategory with ${auctions.length} auctions',
              );
            } else {
              print(
                '⚠️ Category $category not found in static categories: $categories',
              );
            }
          }

          setState(() {
            playerGroups = groups;
            groupsByCategory = tempGroupsByCategory;
            groupAuctions = tempGroupAuctions;
            registrationStatus = tempRegistrationStatus;
          });

          print(
            '📊 Groups by category: ${tempGroupsByCategory.map((k, v) => MapEntry(k, v.length))}',
          );
          print(
            '📊 Total auctions loaded: ${tempGroupAuctions.values.fold(0, (sum, auctions) => sum + auctions.length)}',
          );
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
      onRefresh: _handleRefresh,
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
        // Header with refresh button
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Tournaments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              GestureDetector(
                onTap: isLoading ? null : _handleRefresh,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child:
                      isLoading
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.primaryColor,
                              strokeWidth: 2,
                            ),
                          )
                          : Icon(
                            Icons.refresh,
                            color: AppColors.primaryColor,
                            size: 20,
                          ),
                ),
              ),
            ],
          ),
        ),

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
              // Tab(
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     children: [
              //       Icon(Icons.sports_baseball, size: 16),
              //       SizedBox(width: 6),
              //       Text('Baseball'),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),

        // Content
        if (playerGroups.isNotEmpty)
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
            '${category.toUpperCase()}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          Spacer(),
          // Refresh button for this category
          GestureDetector(
            onTap: isLoading ? null : _handleRefresh,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(Icons.refresh, color: Colors.white, size: 16),
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
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
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isLoading ? null : _handleRefresh,
            icon: Icon(Icons.refresh, size: 16),
            label: Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      // case 'baseball':
      //   return Icons.sports_baseball;
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
            // Navigate to AuctionListScreen instead of inline display
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => AuctionListScreen(
                      groupName: groupName ?? 'Unknown Group',
                      category: group['category'],
                      currentUserId: widget.currentUserId,
                      initialAuctions: groupAuctions[groupName],
                    ),
              ),
            ).then((_) {
              // Refresh data when returning from auction screen
              _handleRefresh();
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
                          // SizedBox(height: 4),
                          // Text(
                          //   '$playerCount players',
                          //   style: TextStyle(
                          //     color: Colors.white.withOpacity(0.5),
                          //     fontSize: 14,
                          //     fontWeight: FontWeight.w500,
                          //   ),
                          // ),
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

                SizedBox(height: 8),
                Row(
                  children: [
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

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              AppColors.primaryColor.withOpacity(0.1),
              Colors.transparent,
            ],
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
                        backgroundColor: AppColors.primaryColor.withOpacity(
                          0.1,
                        ),
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
      ),
    );
  }

  Widget _buildErrorState() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
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
                ElevatedButton.icon(
                  onPressed: _handleRefresh,
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
