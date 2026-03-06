import 'package:flutter/material.dart';
import 'package:auctiongame/theme/appcolor.dart';
import 'package:auctiongame/sockets/socket_service.dart';

class UserBudgetDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> budget;
  final int auctionId;

  const UserBudgetDetailScreen({
    super.key,
    required this.user,
    required this.budget,
    required this.auctionId,
  });

  @override
  State<UserBudgetDetailScreen> createState() => _UserBudgetDetailScreenState();
}

class _UserBudgetDetailScreenState extends State<UserBudgetDetailScreen> {
  final SocketService _socketService = SocketService.instance;
  Map<String, dynamic>? _userTeamData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupSocketListener();
    _requestUserTeam();
  }

  void _setupSocketListener() {
    _socketService.onSpecificUserTeam((data) {
      print('🎯 Received user team data: $data');
      if (mounted && data['userId'] == widget.user['userId']) {
        setState(() {
          _userTeamData = data;
          _isLoading = false;
        });
        print(
          '💾 Updated user team data: ${data['team']?.length ?? 0} players',
        );
      }
    });
  }

  void _requestUserTeam() {
    _socketService.requestUserTeam(widget.user['userId'], widget.auctionId);
  }

  String _formatCurrency(int amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }

  Widget _buildTeamStatCard(String title, String value) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Colors.white70, fontSize: 12)),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1B4332),
      appBar: AppBar(
        backgroundColor: Color(0xFF2D5A3E),
        title: Text(
          '${widget.user['userName']}\'s Team',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // User Info Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: Color(0xFF2D5A3E)),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color:
                        widget.budget['isActive']
                            ? AppColors.primaryColor
                            : Colors.grey,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child:
                      widget.user['profilepic'] == null ||
                              widget.user['profilepic'].toString().isEmpty
                          ? Center(
                            child: Text(
                              widget.user['userName']
                                  .toString()
                                  .split(' ')
                                  .map((n) => n[0])
                                  .join('')
                                  .toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          )
                          : ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Image.network(
                              widget.user['profilepic'],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    widget.user['userName']
                                        .toString()
                                        .split(' ')
                                        .map((n) => n[0])
                                        .join('')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user['userName'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              widget.budget['isActive']
                                  ? Colors.green
                                  : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.budget['isActive'] ? 'ACTIVE' : 'INACTIVE',
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
              ],
            ),
          ),

          // Budget Stats
          Container(
            margin: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTeamStatCard(
                        'Total Budget',
                        '₹${_formatCurrency(widget.budget['totalBudget'] ?? 0)}',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildTeamStatCard(
                        'Spent',
                        '₹${_formatCurrency(widget.budget['spentAmount'] ?? 0)}',
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
                        '₹${_formatCurrency(widget.budget['remainingBudget'] ?? 0)}',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildTeamStatCard(
                        'Players',
                        '${_userTeamData?['team']?.length ?? widget.budget['playersCount'] ?? 0}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Team Players Header
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
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '${_userTeamData?['team']?.length ?? widget.budget['playersCount'] ?? 0} Players',
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

          // Team Players List
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
                      ),
                    )
                    : _userTeamData == null ||
                        _userTeamData!['team'] == null ||
                        _userTeamData!['team'].isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_off,
                            color: Color(0xFF95D5B2),
                            size: 80,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No players yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${widget.user['userName']} hasn\'t bought any players',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _userTeamData!['team'].length,
                      itemBuilder: (context, index) {
                        final player = _userTeamData!['team'][index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(16),
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
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  color: Color(0xFF40916C),
                                ),
                                child:
                                    player['image'] != null &&
                                            player['image']
                                                .toString()
                                                .isNotEmpty
                                        ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            25,
                                          ),
                                          child: Image.network(
                                            player['image'],
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return Center(
                                                child: Text(
                                                  player['name'][0]
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                        : Center(
                                          child: Text(
                                            player['name'][0].toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                              ),
                              SizedBox(width: 16),

                              // Player Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      player['name'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      player['role'] ?? 'Player',
                                      style: TextStyle(
                                        color: Color(0xFF95D5B2),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Price
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.yellow.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.yellow.withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  '₹${_formatCurrency(player['price'] ?? 0)}',
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
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

  @override
  void dispose() {
    // Clean up socket listener if needed
    super.dispose();
  }
}
