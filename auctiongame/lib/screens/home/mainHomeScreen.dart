import 'package:auctiongame/theme/appcolor.dart';
import 'package:flutter/material.dart';

class HomeScreenMain extends StatefulWidget {
  const HomeScreenMain({Key? key}) : super(key: key);

  @override
  State<HomeScreenMain> createState() => _HomeScreenMainState();
}

class _HomeScreenMainState extends State<HomeScreenMain>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Tab Bar
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: AppColors.primaryColor,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[600],
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.sports_cricket, size: 20),
                    text: "Cricket",
                  ),
                  Tab(
                    icon: Icon(Icons.sports_soccer, size: 20),
                    text: "Football",
                  ),
                  Tab(
                    icon: Icon(Icons.sports_baseball, size: 20),
                    text: "Baseball",
                  ),
                ],
              ),
            ),

            // Tournament Chips
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildTournamentChip("ECS T10 Stockholm", true),
                  _buildTournamentChip("WCL T20", false),
                  _buildTournamentChip("Shpageeza T20", false),
                  _buildTournamentChip("BBL T20", false),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Filter Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterTab("Recommended", true),
                  _buildFilterTab("Starting Soon", false),
                  _buildFilterTab("Popular", false),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Match Cards
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Cricket Tab
                  _buildMatchList([
                    _buildMatchCard(
                      "T10 • ECS T10 Stockholm",
                      "RPHX",
                      "Rising Phoenix",
                      "JCC",
                      "Jinnah CC Stockholm",
                      "24m : 42s",
                      "Lineups Out",
                      "₹1.3 Crores+",
                      Colors.blue,
                      const Color(0xFF4CAF50),
                    ),
                    _buildMatchCard(
                      "T10 • ECS T10 Stockholm",
                      "HUD",
                      "Huddinge",
                      "ALZ",
                      "Alby Zalmi CF",
                      "2h : 24m",
                      "2:15 PM",
                      "₹75 Lakhs+",
                      Colors.red,
                      Colors.blue,
                    ),
                    _buildMatchCard(
                      "T20 • WCL T20",
                      "IND",
                      "India Warriors",
                      "PAK",
                      "Pakistan Lions",
                      "4h : 15m",
                      "4:30 PM",
                      "₹2.5 Crores+",
                      Colors.orange,
                      const Color(0xFF4CAF50),
                    ),
                  ]),
                  // Football Tab
                  _buildMatchList([
                    _buildMatchCard(
                      "Premier League",
                      "MUN",
                      "Manchester United",
                      "LIV",
                      "Liverpool FC",
                      "1h : 30m",
                      "3:00 PM",
                      "₹5 Crores+",
                      Colors.red,
                      Colors.red[900]!,
                    ),
                    _buildMatchCard(
                      "La Liga",
                      "BAR",
                      "Barcelona",
                      "MAD",
                      "Real Madrid",
                      "3h : 45m",
                      "5:15 PM",
                      "₹8 Crores+",
                      Colors.blue[900]!,
                      Colors.white,
                    ),
                  ]),
                  // Baseball Tab
                  _buildMatchList([
                    _buildMatchCard(
                      "MLB",
                      "NYY",
                      "New York Yankees",
                      "BOS",
                      "Boston Red Sox",
                      "2h : 10m",
                      "7:30 PM",
                      "₹3 Crores+",
                      Colors.purple,
                      Colors.red,
                    ),
                    _buildMatchCard(
                      "MLB",
                      "LAD",
                      "Los Angeles Dodgers",
                      "SFG",
                      "San Francisco Giants",
                      "5h : 20m",
                      "10:15 PM",
                      "₹4.5 Crores+",
                      Colors.blue,
                      Colors.orange,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentChip(String title, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Chip(
        label: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        backgroundColor: isSelected ? AppColors.primaryColor : Colors.white,
        side: BorderSide(
          color: isSelected ? AppColors.primaryColor : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildFilterTab(String title, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? AppColors.primaryColor : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              height: 2,
              width: 20,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMatchList(List<Widget> matches) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: matches,
    );
  }

  Widget _buildMatchCard(
    String tournament,
    String team1Code,
    String team1Name,
    String team2Code,
    String team2Name,
    String timeLeft,
    String matchTime,
    String prizePool,
    Color team1Color,
    Color team2Color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tournament header with arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tournament,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Teams row
            Row(
              children: [
                // Team 1
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: team1Color,
                        child: Text(
                          team1Code.substring(0, 2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          team1Name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Time/Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        timeLeft.contains(':')
                            ? Colors.red[50]
                            : AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        timeLeft,
                        style: TextStyle(
                          color:
                              timeLeft.contains(':')
                                  ? Colors.red
                                  : AppColors.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        matchTime,
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                    ],
                  ),
                ),

                // Team 2
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          team2Name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: team2Color,
                        child: Text(
                          team2Code.substring(0, 2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Prize pool
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.currency_rupee,
                    size: 16,
                    color: Colors.orange[600],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  prizePool,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(Icons.refresh, size: 16, color: Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Your existing color classes
