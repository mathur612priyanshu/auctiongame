import 'package:flutter/material.dart';
import 'package:auctiongame/api/leaderboard_service.dart';
import 'package:auctiongame/theme/appcolor.dart';

class LeaderboardScreen extends StatefulWidget {
  final String auctionId;
  final String auctionName;

  const LeaderboardScreen({
    super.key,
    required this.auctionId,
    required this.auctionName,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> leaderboard = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? selectedUserDetails;
  bool showPlayerDetails = false;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final data = await LeaderboardService.getAuctionLeaderboard(
        widget.auctionId,
      );
      print('data---> leaderboard $data');
      setState(() {
        leaderboard = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _showPlayerDetails(Map<String, dynamic> entry) {
    setState(() {
      selectedUserDetails = entry;
      showPlayerDetails = true;
    });
  }

  void _hidePlayerDetails() {
    setState(() {
      showPlayerDetails = false;
      selectedUserDetails = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      appBar: AppBar(
        title: Text(
          '${widget.auctionName}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.secondaryaccentColor,
                  AppColors.primaryColor,
                ],
              ),
            ),
            child: _buildBody(),
          ),
          if (showPlayerDetails && selectedUserDetails != null)
            _buildPlayerDetailsDialog(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error loading leaderboard',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchLeaderboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (leaderboard.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'No leaderboard data available',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLeaderboard,
      backgroundColor: const Color(0xFF16213E),
      color: const Color(0xFFFFD700),
      child: Column(
        children: [
          // Top 3 podium
          if (leaderboard.isNotEmpty) _buildPodium(),
          // Rest of the leaderboard
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: leaderboard.length,
              itemBuilder: (context, index) {
                final entry = leaderboard[index];
                return GestureDetector(
                  onTap: () => _showPlayerDetails(entry),
                  child:
                      index < 3
                          ? _buildPodiumLeaderboardItem(entry, index + 1)
                          : _buildLeaderboardItem(entry, index + 1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    List<Map<String, dynamic>> top3 = leaderboard.take(3).toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (top3.length > 1)
            GestureDetector(
              onTap: () => _showPlayerDetails(top3[1]),
              child: _buildPodiumItem(top3[1], 2, 120),
            ),
          // 1st place
          if (top3.isNotEmpty)
            GestureDetector(
              onTap: () => _showPlayerDetails(top3[0]),
              child: _buildPodiumItem(top3[0], 1, 140),
            ),
          // 3rd place
          if (top3.length > 2)
            GestureDetector(
              onTap: () => _showPlayerDetails(top3[2]),
              child: _buildPodiumItem(top3[2], 3, 100),
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumLeaderboardItem(Map<String, dynamic> entry, int position) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getPositionColor(position).withOpacity(0.5),
          width: 2,
        ),
      ),
      child: _buildLeaderboardContent(entry, position),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> entry, int position) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: _buildLeaderboardContent(entry, position),
    );
  }

  Widget _buildLeaderboardContent(Map<String, dynamic> entry, int position) {
    const int initialBudget = 1000000;
    final int totalSpent = entry['totalSpent'] ?? 0;
    final int remainingBudget = initialBudget - totalSpent;

    // Safely extract and process player details
    List<Map<String, dynamic>> topPlayers = [];
    if (entry['playerDetails'] != null && entry['playerDetails'] is List) {
      final playerDetails = List<dynamic>.from(entry['playerDetails'] as List);
      if (playerDetails.isNotEmpty) {
        // Convert to List<Map<String, dynamic>> and sort by points
        final convertedPlayers =
            playerDetails
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();

        convertedPlayers.sort(
          (a, b) => (b['points'] ?? 0).compareTo(a['points'] ?? 0),
        );

        topPlayers = convertedPlayers.take(3).toList();
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Position
              Container(
                width: 40,
                alignment: Alignment.center,
                child: _getPositionIcon(position),
              ),
              const SizedBox(width: 12),
              // Profile picture
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF0F3460),
                  child: Text(
                    entry['User']?['name']?.substring(0, 1).toUpperCase() ??
                        entry['userId']?.toString().substring(0, 1) ??
                        '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name and username
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['User']?['name'] ??
                          'User ${entry['userId'] ?? 'Unknown'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // const SizedBox(height: 2),
                    // Text(
                    //   'Group: ${entry['playerGroup'] ?? 'N/A'}',
                    //   style: TextStyle(
                    //     color: Colors.white.withOpacity(0.6),
                    //     fontSize: 12,
                    //   ),
                    // ),
                  ],
                ),
              ),
              // Points and budget
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry['totalPoints'] ?? 0} pts',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${totalSpent}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Top players section
          if (topPlayers.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                const Text(
                  'Top Players:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...topPlayers
                    .map(
                      (player) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Player name and breakdown
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player['playerName'] ?? 'Unknown Player',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // if (_formatPointsBreakdown(player).isNotEmpty)
                                  //   Text(
                                  //     _formatPointsBreakdown(player),
                                  //     style: const TextStyle(
                                  //       color: Colors.white70,
                                  //       fontSize: 12,
                                  //     ),
                                  //   ),
                                ],
                              ),
                            ),
                            // Total points
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '${player['points'] ?? 0} pts',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerDetailsDialog() {
    final entry = selectedUserDetails!;

    // Safely extract and process player details
    List<Map<String, dynamic>> sortedPlayers = [];
    if (entry['playerDetails'] != null && entry['playerDetails'] is List) {
      final playerDetails = List<dynamic>.from(entry['playerDetails'] as List);
      if (playerDetails.isNotEmpty) {
        // Convert to List<Map<String, dynamic>> and sort by points
        sortedPlayers =
            playerDetails
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();

        sortedPlayers.sort(
          (a, b) => (b['points'] ?? 0).compareTo(a['points'] ?? 0),
        );
      }
    }

    return Dialog(
      backgroundColor: AppColors.secondaryaccentColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Profile picture
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Text(
                      entry['User']?['name']?.substring(0, 1).toUpperCase() ??
                          entry['userId']?.toString().substring(0, 1) ??
                          '?',
                      style: const TextStyle(
                        color: Color(0xFF0F3460),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry['User']?['name'] ??
                              'User ${entry['userId'] ?? 'Unknown'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Text(
                        //   'Group: ${entry['playerGroup'] ?? 'N/A'}',
                        //   style: const TextStyle(
                        //     color: Colors.white70,
                        //     fontSize: 14,
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _hidePlayerDetails,
                  ),
                ],
              ),
            ),
            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1A1A2E),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Total Points',
                    '${entry['totalPoints'] ?? 0}',
                  ),
                  _buildStatItem(
                    'Players Count',
                    '${entry['playersCount'] ?? 0}',
                  ),
                  _buildStatItem(
                    'Total Spent',
                    '₹${(entry['totalSpent'] ?? 0) ~/ 1000}k',
                  ),
                ],
              ),
            ),
            // Player list
            Expanded(
              child:
                  sortedPlayers.isEmpty
                      ? const Center(
                        child: Text(
                          'No players data available',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedPlayers.length,
                        itemBuilder: (context, index) {
                          final player = sortedPlayers[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F3460).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left: Name and breakdown lines
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        player['playerName'] ??
                                            'Unknown Player',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (_formatPointsBreakdown(
                                        player,
                                      ).isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children:
                                              _formatPointsBreakdown(player)
                                                  .map(
                                                    (line) => Text(
                                                      line.toString(),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Right: Total points
                                Text(
                                  '${player['points'] ?? 0} pts',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 16,
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
    );
  }

  Widget _buildStatItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Builds a formatted breakdown string like:
  // Runs: 200 x 1 = 200 | Wickets: 50 x 2 = 100 | Total: 300
  List<String> _formatPointsBreakdown(Map<String, dynamic> player) {
    try {
      final pb = player['pointsBreakdown'];
      if (pb == null || pb is! Map<String, dynamic>) return [];

      final raw = pb['raw'] as Map<String, dynamic>? ?? {};
      final runsRaw = num.tryParse(raw['runs']?.toString() ?? '') ?? 0;
      final wicketsRaw = num.tryParse(raw['wickets']?.toString() ?? '') ?? 0;

      final runPoint = num.tryParse(pb['runPoint']?.toString() ?? '') ?? 0;
      final wicketPoint =
          num.tryParse(pb['wicketPoint']?.toString() ?? '') ?? 0;

      final runsPts = runsRaw * runPoint;
      final wicketsPts = wicketsRaw * wicketPoint;

      final breakdown = <String>[];

      if (runsRaw > 0 && runPoint > 0) {
        breakdown.add(
          'Runs: $runsRaw × ${_fmtNum(runPoint)} = ${_fmtNum(runsPts)}',
        );
      }

      if (wicketsRaw > 0 && wicketPoint > 0) {
        breakdown.add(
          'Wickets: $wicketsRaw × ${_fmtNum(wicketPoint)} = ${_fmtNum(wicketsPts)}',
        );
      }

      final total =
          num.tryParse(pb['total']?.toString() ?? '') ??
          (player['points'] is num
              ? player['points'] as num
              : (runsPts + wicketsPts));

      if (breakdown.isNotEmpty) {
        breakdown.add('Total: ${_fmtNum(total)}');
      }

      return breakdown;
    } catch (_) {
      return [];
    }
  }

  String _fmtNum(num n) {
    if (n % 1 == 0) return n.toInt().toString();
    return n.toStringAsFixed(1);
  }

  Widget _buildPodiumItem(
    Map<String, dynamic> entry,
    int position,
    double height,
  ) {
    Color borderColor;
    Color crownColor;

    switch (position) {
      case 1:
        borderColor = const Color(0xFFFFD700); // Gold
        crownColor = const Color(0xFFFFD700);
        break;
      case 2:
        borderColor = const Color(0xFFC0C0C0); // Silver
        crownColor = const Color(0xFFC0C0C0);
        break;
      case 3:
        borderColor = const Color(0xFFCD7F32); // Bronze
        crownColor = const Color(0xFFCD7F32);
        break;
      default:
        borderColor = Colors.white;
        crownColor = Colors.white;
    }

    const int initialBudget = 1000000;
    final int totalSpent = entry['totalSpent'] ?? 0;
    final int remainingBudget = initialBudget - totalSpent;

    return Column(
      children: [
        // Crown for 1st place
        if (position == 1)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Icon(Icons.emoji_events, color: crownColor, size: 30),
          ),
        // Profile picture with border
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child:
                entry?['User']?['profilepic'] != null &&
                        entry['User']['profilepic'].toString().isNotEmpty
                    ? Image.network(
                      entry['User']['profilepic'],
                      fit: BoxFit.cover,
                      width: position == 1 ? 70 : 60,
                      height: position == 1 ? 70 : 60,
                    )
                    : Container(
                      color: const Color(0xFF16213E),
                      alignment: Alignment.center,
                      width: position == 1 ? 70 : 60,
                      height: position == 1 ? 70 : 60,
                      child: Text(
                        entry['User']?['name']?.substring(0, 1).toUpperCase() ??
                            entry['userId']?.toString().substring(0, 1) ??
                            '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: position == 1 ? 24 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 12),
        // Name
        Text(
          entry['User']?['name'] ?? 'User ${entry['userId'] ?? 'Unknown'}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        // Points
        Text(
          '${entry['totalPoints'] ?? 0}',
          style: TextStyle(
            color: borderColor,
            fontSize: position == 1 ? 24 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        // const SizedBox(height: 4),
        // // Budget
        // Text(
        //   '₹${remainingBudget ~/ 1000}k',
        //   style: const TextStyle(color: Colors.white70, fontSize: 12),
        // ),
      ],
    );
  }

  Widget _getPositionIcon(int position) {
    switch (position) {
      case 1:
        return const Icon(
          Icons.emoji_events,
          color: Color(0xFFFFD700),
          size: 28,
        );
      case 2:
        return const Icon(
          Icons.emoji_events,
          color: Color(0xFFC0C0C0),
          size: 24,
        );
      case 3:
        return const Icon(
          Icons.emoji_events,
          color: Color(0xFFCD7F32),
          size: 20,
        );
      default:
        return Text(
          '$position',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        );
    }
  }

  Color _getPositionColor(int position) {
    switch (position) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white;
    }
  }
}
