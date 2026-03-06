import 'package:auctiongame/screens/auctions/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:auctiongame/api/user_auction_service.dart';
import 'package:auctiongame/theme/appcolor.dart';
import 'package:collection/collection.dart';
import 'package:auctiongame/constants.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MyTeamsWidget extends StatefulWidget {
  final String userId;

  const MyTeamsWidget({super.key, required this.userId});

  @override
  State<MyTeamsWidget> createState() => _MyTeamsWidgetState();
}

class _MyTeamsWidgetState extends State<MyTeamsWidget> {
  List<Map<String, dynamic>> userAuctions = [];
  Map<String, List<Map<String, dynamic>>> otherTeams = {};
  Map<String, bool> expandedAuctions = {};
  Map<String, bool> loadingOtherTeams = {};
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserAuctions();
  }

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
                      'Pool:',
                      '${currencyFormat.format(totalPool)} (after 20% reduction)',
                    ),
                    _buildInfoRow(
                      'Counted Players:',
                      '${details['countedPlayers']}',
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

  Future<void> _fetchUserAuctions() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      print('Fetching enriched auctions for user: ${widget.userId}');
      final response = await UserAuctionService.getUserEnrichedAuctions(
        widget.userId,
      );

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          userAuctions = List<Map<String, dynamic>>.from(response['data']);
          isLoading = false;
        });
        print('Fetched enriched auctions: ${userAuctions.length}');
      } else {
        setState(() {
          errorMessage = "Failed to fetch auctions";
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _fetchUserAuctions: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadOtherTeams(String auctionId) async {
    if (otherTeams[auctionId] != null) return; // Already loaded

    setState(() {
      loadingOtherTeams[auctionId] = true;
    });

    try {
      final participants =
          await UserAuctionService.getAuctionParticipantsWithPlayers(auctionId);

      setState(() {
        otherTeams[auctionId] = List<Map<String, dynamic>>.from(participants);
      });
    } catch (e) {
      print('Error loading other teams: $e');
      // Optionally show error to user
    } finally {
      setState(() {
        loadingOtherTeams[auctionId] = false;
      });
    }

    try {
      final teams = await UserAuctionService.getAllAuctionTeams(auctionId);
      // Filter out current user's team
      final otherTeamsList =
          teams
              .where(
                (team) =>
                    team['userId'] != widget.userId &&
                    (team['team']?.isNotEmpty == true),
              )
              .toList();

      setState(() {
        otherTeams[auctionId] = otherTeamsList;
        expandedAuctions[auctionId] = false;
      });
    } catch (e) {
      print('Error loading other teams: $e');
      // Don't show error to user for this non-critical feature
    } finally {
      setState(() {
        loadingOtherTeams[auctionId] = false;
      });
    }
  }

  Widget _buildTeamPlayers(List<dynamic>? players) {
    if (players == null || players.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No players in this team yet',
          style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          players.map<Widget>((player) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Icon(
                    Icons.sports_soccer,
                    size: 16,
                    color: AppColors.primaryColor,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${player['name']} (${player['position']})',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Text(
                    '₹${player['soldPrice']?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildOtherTeams(String auctionId) {
    final teams = otherTeams[auctionId] ?? [];
    final isLoading = loadingOtherTeams[auctionId] ?? false;
    final isExpanded = expandedAuctions[auctionId] ?? false;

    if (isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            strokeWidth: 2.0,
          ),
        ),
      );
    }

    if (teams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
        child: Text(
          'No other teams to show',
          style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(
            'Other Teams (${teams.length})",',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.white,
          ),
          onTap: () {
            setState(() {
              expandedAuctions[auctionId] = !isExpanded;
            });
          },
        ),
        if (isExpanded) ...{
          ...teams
              .map<Widget>(
                (team) => Card(
                  margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  color: Colors.grey[900],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryColor
                                  .withOpacity(0.2),
                              child: Icon(
                                Icons.person,
                                color: AppColors.primaryColor,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    team['userName'] ?? 'Unknown User',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Remaining: ₹${(team['remainingBudget'] ?? 0).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        _buildTeamPlayers(team['team']),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Loading your teams...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Error loading your teams',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              errorMessage!,
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchUserAuctions,
              child: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    if (userAuctions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups, size: 80, color: AppColors.primaryColor),
            SizedBox(height: 20),
            Text(
              'No Teams Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'You haven\'t participated in any auctions yet',
              style: TextStyle(color: Color(0xFF95D5B2), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate back to home tab
                DefaultTabController.of(context)?.animateTo(0);
              },
              child: Text('Browse Auctions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchUserAuctions,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: userAuctions.length,
        itemBuilder: (context, index) {
          final auction = userAuctions[index];
          return _buildAuctionCard(auction);
        },
      ),
    );
  }

  Widget _buildAuctionCard(Map<String, dynamic> auction) {
    final auctionId = auction['id'].toString();
    final userTeam = auction['userTeam'];
    final userBudget = auction['userBudget'] ?? {};

    // Ensure safe default structure
    List<dynamic> teamPlayers = [];
    Map<String, dynamic> budgetInfo = {};

    if (userTeam is Map<String, dynamic>) {
      // case: backend returns { team: [...], budgetInfo: {...} }
      teamPlayers = (userTeam['team'] is List) ? userTeam['team'] : [];
      budgetInfo =
          (userTeam['budgetInfo'] is Map) ? userTeam['budgetInfo'] : userBudget;
    } else if (userTeam is List) {
      // case: backend accidentally sends a list instead of object
      teamPlayers = userTeam;
      budgetInfo = userBudget;
    } else {
      // case: null or unexpected
      teamPlayers = [];
      budgetInfo = userBudget;
    }

    final remainingBudget = budgetInfo['remainingBudget'] ?? 0;
    final totalSpent =
        budgetInfo['spentAmount'] ?? budgetInfo['totalSpent'] ?? 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (otherTeams[auctionId] == null) {
        _loadOtherTeams(auctionId);
      }
    });

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () => _navigateToLeaderboard(auction),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Auction Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(auction['status']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      auction['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _showRulesDialog(auction),
                        icon: Icon(
                          Icons.rule_folder,
                          color: AppColors.primaryColor,
                        ),
                        label: Text(
                          'Show Rules',
                          style: TextStyle(color: AppColors.primaryColor),
                        ),
                      ),
                    ],
                  ),
                  // Spacer(),
                  // Icon(
                  //   Icons.leaderboard,
                  //   color: AppColors.primaryColor,
                  //   size: 20,
                  // ),
                  // SizedBox(width: 4),
                ],
              ),
              SizedBox(height: 12),

              // Auction Name
              Text(
                auction['name'] ?? 'Unknown Auction',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),

              // Category and Type
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.category,
                    label: auction['category'] ?? 'N/A',
                  ),
                  SizedBox(width: 8),
                ],
              ),
              SizedBox(height: 16),
              // Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'View LeaderBoard',
                        style: TextStyle(
                          color: AppColors.accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.leaderboard,
                        color: AppColors.secondaryaccentColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 6),
              // Actions

              // Budget Information
              // Container(
              //   padding: EdgeInsets.all(12),
              //   decoration: BoxDecoration(
              //     color: Colors.white.withOpacity(0.05),
              //     borderRadius: BorderRadius.circular(8),
              //   ),
              //   child: Row(
              //     children: [
              //       Expanded(
              //         child: Column(
              //           crossAxisAlignment: CrossAxisAlignment.start,
              //           children: [
              //             Text(
              //               'Remaining Budget',
              //               style: TextStyle(
              //                 color: Colors.white70,
              //                 fontSize: 12,
              //               ),
              //             ),
              //             Text(
              //               '₹${remainingBudget.toString()}',
              //               style: TextStyle(
              //                 color: AppColors.primaryColor,
              //                 fontSize: 16,
              //                 fontWeight: FontWeight.bold,
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //       Expanded(
              //         child: Column(
              //           crossAxisAlignment: CrossAxisAlignment.start,
              //           children: [
              //             Text(
              //               'Total Spent',
              //               style: TextStyle(
              //                 color: Colors.white70,
              //                 fontSize: 12,
              //               ),
              //             ),
              //             Text(
              //               '₹${totalSpent.toString()}',
              //               style: TextStyle(
              //                 color: Colors.orange,
              //                 fontSize: 16,
              //                 fontWeight: FontWeight.bold,
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              // SizedBox(height: 16),

              // Team Information - Make it clickable
              // InkWell(
              //   onTap: () => _showTeamDetails(auction),
              //   child: Container(
              //     padding: EdgeInsets.all(12),
              //     decoration: BoxDecoration(
              //       color: AppColors.primaryColor.withOpacity(0.1),
              //       borderRadius: BorderRadius.circular(8),
              //       border: Border.all(
              //         color: AppColors.primaryColor.withOpacity(0.3),
              //       ),
              //     ),
              //     child: Row(
              //       children: [
              //         Icon(
              //           Icons.group,
              //           color: AppColors.primaryColor,
              //           size: 20,
              //         ),
              //         SizedBox(width: 8),
              //         Text(
              //           'Team Size: ${teamPlayers.length} players',
              //           style: TextStyle(
              //             color: AppColors.primaryColor,
              //             fontSize: 16,
              //             fontWeight: FontWeight.w500,
              //           ),
              //         ),
              //         Spacer(),
              //         Text(
              //           'View Team',
              //           style: TextStyle(
              //             color: AppColors.primaryColor,
              //             fontSize: 12,
              //           ),
              //         ),
              //         SizedBox(width: 4),
              //         Icon(
              //           Icons.arrow_forward_ios,
              //           color: AppColors.primaryColor,
              //           size: 16,
              //         ),
              //       ],
              //     ),
              //   ),
              // ),

              // Show some team players if available
              // if (teamPlayers.isNotEmpty) ...[
              //   SizedBox(height: 12),
              //   Text(
              //     'Your Players:',
              //     style: TextStyle(
              //       color: Colors.white,
              //       fontSize: 14,
              //       fontWeight: FontWeight.w500,
              //     ),
              //   ),
              //   SizedBox(height: 8),
              //   Wrap(
              //     spacing: 8,
              //     runSpacing: 4,
              //     children:
              //         teamPlayers.take(3).map<Widget>((player) {
              //           return Container(
              //             padding: EdgeInsets.symmetric(
              //               horizontal: 8,
              //               vertical: 4,
              //             ),
              //             decoration: BoxDecoration(
              //               color: AppColors.primaryColor.withOpacity(0.2),
              //               borderRadius: BorderRadius.circular(12),
              //             ),
              //             child: Text(
              //               player['name'] ?? 'Unknown Player',
              //               style: TextStyle(
              //                 color: Color(0xFF95D5B2),
              //                 fontSize: 12,
              //               ),
              //             ),
              //           );
              //         }).toList(),
              //   ),
              //   if (teamPlayers.length > 3)
              //     Padding(
              //       padding: EdgeInsets.only(top: 4, bottom: 12),
              //       child: Text(
              //         '+${teamPlayers.length - 3} more players',
              //         style: TextStyle(color: Colors.white54, fontSize: 12),
              //       ),
              //     ),
              // ],

              // Other Teams Section
              // Container(
              //   margin: EdgeInsets.only(top: 12),
              //   padding: EdgeInsets.symmetric(vertical: 8),
              //   decoration: BoxDecoration(
              //     border: Border(
              //       top: BorderSide(color: Colors.white.withOpacity(0.1)),
              //       bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              //     ),
              //   ),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       InkWell(
              //         onTap: () {
              //           setState(() {
              //             expandedAuctions[auctionId] =
              //                 !(expandedAuctions[auctionId] ?? false);
              //           });
              //         },
              //         child: Padding(
              //           padding: const EdgeInsets.symmetric(vertical: 8.0),
              //           child: Row(
              //             children: [
              //               Text(
              //                 'Other Teams',
              //                 style: TextStyle(
              //                   color: Colors.white,
              //                   fontSize: 16,
              //                   fontWeight: FontWeight.bold,
              //                 ),
              //               ),
              //               Spacer(),
              //               Text(
              //                 '${otherTeams[auctionId]?.length ?? 0} teams',
              //                 style: TextStyle(
              //                   color: Colors.white70,
              //                   fontSize: 14,
              //                 ),
              //               ),
              //               SizedBox(width: 8),
              //               Icon(
              //                 (expandedAuctions[auctionId] ?? false)
              //                     ? Icons.keyboard_arrow_up
              //                     : Icons.keyboard_arrow_down,
              //                 color: Colors.white70,
              //               ),
              //             ],
              //           ),
              //         ),
              //       ),
              //       if (expandedAuctions[auctionId] ?? false) ...[
              //         if (loadingOtherTeams[auctionId] ?? false)
              //           Center(
              //             child: Padding(
              //               padding: const EdgeInsets.all(16.0),
              //               child: CircularProgressIndicator(
              //                 valueColor: AlwaysStoppedAnimation<Color>(
              //                   AppColors.primaryColor,
              //                 ),
              //                 strokeWidth: 2.0,
              //               ),
              //             ),
              //           )
              //         else if ((otherTeams[auctionId]?.length ?? 0) == 0)
              //           Padding(
              //             padding: const EdgeInsets.only(
              //               top: 8.0,
              //               bottom: 16.0,
              //             ),
              //             child: Text(
              //               'No other teams in this auction yet',
              //               style: TextStyle(
              //                 color: Colors.white70,
              //                 fontStyle: FontStyle.italic,
              //               ),
              //             ),
              //           )
              //         else
              //           ...(otherTeams[auctionId] ?? []).map<Widget>((team) {
              //             final teamPlayers = team['team'] ?? [];
              //             return Container(
              //               margin: EdgeInsets.only(top: 12),
              //               padding: EdgeInsets.all(12),
              //               decoration: BoxDecoration(
              //                 color: Colors.white.withOpacity(0.05),
              //                 borderRadius: BorderRadius.circular(8),
              //               ),
              //               child: Column(
              //                 crossAxisAlignment: CrossAxisAlignment.start,
              //                 children: [
              //                   Row(
              //                     children: [
              //                       CircleAvatar(
              //                         backgroundColor: AppColors.primaryColor
              //                             .withOpacity(0.2),
              //                         radius: 16,
              //                         child: Text(
              //                           team['userName']
              //                                   ?.substring(0, 1)
              //                                   .toUpperCase() ??
              //                               '?',
              //                           style: TextStyle(
              //                             color: AppColors.primaryColor,
              //                             fontWeight: FontWeight.bold,
              //                           ),
              //                         ),
              //                       ),
              //                       SizedBox(width: 12),
              //                       Expanded(
              //                         child: Text(
              //                           team['userName'] ?? 'Unknown User',
              //                           style: TextStyle(
              //                             color: Colors.white,
              //                             fontWeight: FontWeight.w500,
              //                           ),
              //                         ),
              //                       ),
              //                       Text(
              //                         '${teamPlayers.length} players',
              //                         style: TextStyle(
              //                           color: Colors.white70,
              //                           fontSize: 12,
              //                         ),
              //                       ),
              //                     ],
              //                   ),
              //                   if (teamPlayers.isNotEmpty) ...[
              //                     SizedBox(height: 8),
              //                     Wrap(
              //                       spacing: 6,
              //                       runSpacing: 6,
              //                       children:
              //                           teamPlayers.take(4).map<Widget>((
              //                             player,
              //                           ) {
              //                             return Container(
              //                               padding: EdgeInsets.symmetric(
              //                                 horizontal: 8,
              //                                 vertical: 4,
              //                               ),
              //                               decoration: BoxDecoration(
              //                                 color: Colors.white.withOpacity(
              //                                   0.1,
              //                                 ),
              //                                 borderRadius:
              //                                     BorderRadius.circular(12),
              //                               ),
              //                               child: Text(
              //                                 player['name'] ?? 'Player',
              //                                 style: TextStyle(
              //                                   color: Colors.white70,
              //                                   fontSize: 12,
              //                                 ),
              //                               ),
              //                             );
              //                           }).toList(),
              //                     ),
              //                     if (teamPlayers.length > 4)
              //                       Padding(
              //                         padding: const EdgeInsets.only(top: 4),
              //                         child: Text(
              //                           '+${teamPlayers.length - 4} more',
              //                           style: TextStyle(
              //                             color: Colors.white54,
              //                             fontSize: 12,
              //                           ),
              //                         ),
              //                       ),
              //                   ],
              //                 ],
              //               ),
              //             );
              //           }).toList(),
              //       ],
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Color(0xFF95D5B2)),
          SizedBox(width: 4),
          Text(label, style: TextStyle(color: Color(0xFF95D5B2), fontSize: 12)),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'ongoing':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'upcoming':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _navigateToLeaderboard(Map<String, dynamic> auction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => LeaderboardScreen(
              auctionId: auction['id'].toString(),
              auctionName: auction['name'] ?? 'Auction',
            ),
      ),
    );
  }

  void _showTeamDetails(Map<String, dynamic> auction) {
    final userTeam = auction['userTeam'] ?? {};
    final teamPlayers = userTeam['team'] ?? [];
    final budgetInfo = userTeam['budgetInfo'] ?? auction['userBudget'] ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder:
                (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text(
                              '${auction['name']} - My Team',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                      ),

                      // Budget Summary
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Players',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${teamPlayers.length}',
                                    style: TextStyle(
                                      color: AppColors.primaryColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Spent',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '₹${budgetInfo['spentAmount'] ?? 0}',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Remaining',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '₹${budgetInfo['remainingBudget'] ?? 0}',
                                    style: TextStyle(
                                      color: AppColors.primaryColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Players List
                      Expanded(
                        child:
                            teamPlayers.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sports_cricket,
                                        size: 64,
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'No Players Yet',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'You haven\'t bought any players in this auction',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                                : ListView.builder(
                                  controller: scrollController,
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: teamPlayers.length,
                                  itemBuilder: (context, index) {
                                    final player = teamPlayers[index];
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 12),
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Player Image
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryColor
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                            child:
                                                player['image'] != null
                                                    ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            25,
                                                          ),
                                                      child: Image.network(
                                                        player['image'],
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) => Icon(
                                                              Icons.person,
                                                              color:
                                                                  AppColors
                                                                      .primaryColor,
                                                            ),
                                                      ),
                                                    )
                                                    : Icon(
                                                      Icons.person,
                                                      color:
                                                          AppColors
                                                              .primaryColor,
                                                    ),
                                          ),
                                          SizedBox(width: 12),

                                          // Player Details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  player['name'] ??
                                                      'Unknown Player',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .primaryColor
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        player['role'] ??
                                                            'Player',
                                                        style: TextStyle(
                                                          color:
                                                              AppColors
                                                                  .primaryColor,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ),
                                                    if (player['team'] !=
                                                        null) ...[
                                                      SizedBox(width: 8),
                                                      Text(
                                                        player['team'],
                                                        style: TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Price
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '₹${player['price'] ?? 0}',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (player['purchaseDate'] !=
                                                  null)
                                                Text(
                                                  _formatDate(
                                                    player['purchaseDate'],
                                                  ),
                                                  style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                            ],
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
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}
