import 'package:auctiongame/components/auction_widget.dart';
import 'package:auctiongame/theme/appcolor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'create_auction_screen.dart';
import 'package:http/http.dart' as http;
import 'package:auctiongame/constants.dart';
import 'dart:convert';

class AuctionListScreen extends StatefulWidget {
  final String groupName;
  final String? category;
  final String? currentUserId;
  final List<Map<String, dynamic>>? initialAuctions;

  const AuctionListScreen({
    super.key,
    required this.groupName,
    this.category,
    this.currentUserId,
    this.initialAuctions,
  });

  @override
  State<AuctionListScreen> createState() => _AuctionListScreenState();
}

class _AuctionListScreenState extends State<AuctionListScreen> {
  List<Map<String, dynamic>> auctions = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    // Use initial auctions if provided, otherwise fetch from server
    if (widget.initialAuctions != null && widget.initialAuctions!.isNotEmpty) {
      auctions = widget.initialAuctions!;
      isLoading = false;
    } else {
      _fetchAuctions();
    }
  }

  Future<void> _fetchAuctions() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      print('🔄 Fetching auctions for group: ${widget.groupName}');

      // Fetch auctions specific to this group using the optimized endpoint
      String url = '$serverurl/player/groups-with-auctions';
      if (widget.category != null) {
        url += '?category=${widget.category}';
      }
      if (widget.currentUserId != null) {
        url +=
            (widget.category != null ? '&' : '?') +
            'userId=${widget.currentUserId}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📡 Parsed data: $data');

        if (data['success'] == true) {
          final groups = List<Map<String, dynamic>>.from(data['data']);

          // Find the specific group and get its auctions
          final targetGroup = groups.firstWhere(
            (group) => group['groupName'] == widget.groupName,
            orElse: () => <String, dynamic>{},
          );

          if (targetGroup.isNotEmpty) {
            final groupAuctions = List<Map<String, dynamic>>.from(
              targetGroup['auctions'] ?? [],
            );
            print(
              '✅ Fetched ${groupAuctions.length} auctions for group ${widget.groupName}',
            );

            setState(() {
              auctions = groupAuctions;
            });
          } else {
            print('⚠️ Group ${widget.groupName} not found in response');
            setState(() {
              auctions = [];
            });
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch auctions');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
      print('❌ Error fetching auctions: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.accentColor, Color(0xFF1B4332)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.groupName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.category != null)
                            Text(
                              '${widget.category} Auctions',
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

              // Auction Widget
              Expanded(
                child: AuctionWidget(
                  auctions: auctions,
                  isLoading: isLoading,
                  currentUserId: widget.currentUserId,
                  onRefresh: _fetchAuctions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
