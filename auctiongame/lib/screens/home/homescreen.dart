import 'package:auctiongame/api/auctionsservice.dart';
import 'package:auctiongame/components/auction_widget.dart';
import 'package:auctiongame/components/group_auction_widget.dart';
import 'package:auctiongame/components/homeheader.dart';
import 'package:auctiongame/components/my_teams_widget.dart';
import 'package:auctiongame/providers/userprovider.dart';
import 'package:auctiongame/screens/auctions/create_auction_screen.dart';
import 'package:auctiongame/screens/editProfile/EditPorfileScreen.dart';
import 'package:auctiongame/screens/home/mainHomeScreen.dart';
import 'package:auctiongame/theme/appcolor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  int _selectedIndex = 0;

  // Sample data based on your API response
  List<Map<String, dynamic>> auctions = [];
  bool isLoading = true;
  String? errorMessage;

  // Add this method to get current user ID
  String? getCurrentUserId() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return userProvider.user?.id?.toString();
  }

  Future<void> _fetchAuctions() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      print('Fetching auctions...');
      final fetchedAuctions = await AuctionService.fetchAuctions();

      setState(() {
        auctions = fetchedAuctions;
        isLoading = false;
      });
      print('Successfully loaded ${fetchedAuctions.length} auctions');
    } catch (e) {
      print('Error fetching auctions: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
        // Keep existing auctions if refresh fails
      });
    }
  }

  // Method to handle drawer navigation
  void _handleDrawerNavigation(int index) {
    Navigator.pop(context); // Close drawer first

    switch (index) {
      case 0: // Home
        setState(() {
          _selectedIndex = 0;
        });
        break;
      case 1: // Profile
        setState(() {
          _selectedIndex = 2; // Profile is at index 2 in bottom nav
        });
        break;
      case 2: // Create Auction
        _navigateToCreateAuction();
        break;
      case 3: // My Auctions/Teams
        setState(() {
          _selectedIndex = 1; // My Teams is at index 1 in bottom nav
        });
        break;
      case 4: // Logout
        _handleLogout();
        break;
    }
  }

  void _navigateToCreateAuction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateAuctionScreen()),
    );
    // Handle result if needed
  }

  void _handleLogout() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _showLogoutDialog(context, userProvider);
  }

  @override
  void initState() {
    super.initState();
    _fetchAuctions();

    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateAuction,
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add),
        tooltip: 'Create Auction',
      ),
      drawer: Drawer(
        backgroundColor: AppColors.secondaryaccentColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: AppColors.accentColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'CORE',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  Text(
                    'Play Real. Rise Beyond',
                    style: TextStyle(color: Colors.white, fontSize: 17),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: AppColors.primaryColor),
              title: Text(
                'Home',
                style: TextStyle(color: AppColors.primaryColor),
              ),
              selected: _selectedIndex == 0,
              selectedTileColor: AppColors.primaryColor.withOpacity(0.1),
              onTap: () => _handleDrawerNavigation(0),
            ),
            ListTile(
              leading: Icon(Icons.person, color: AppColors.primaryColor),
              title: Text(
                'Profile',
                style: TextStyle(color: AppColors.primaryColor),
              ),
              selected: _selectedIndex == 2,
              selectedTileColor: AppColors.primaryColor.withOpacity(0.1),
              onTap: () => _handleDrawerNavigation(1),
            ),
            ListTile(
              leading: Icon(Icons.add_circle, color: AppColors.primaryColor),
              title: Text(
                'Create Auction',
                style: TextStyle(color: AppColors.primaryColor),
              ),
              onTap: () => _handleDrawerNavigation(2),
            ),
            ListTile(
              leading: Icon(Icons.groups, color: AppColors.primaryColor),
              title: Text(
                'My Teams',
                style: TextStyle(color: AppColors.primaryColor),
              ),
              selected: _selectedIndex == 1,
              selectedTileColor: AppColors.primaryColor.withOpacity(0.1),
              onTap: () => _handleDrawerNavigation(3),
            ),
            Divider(color: Colors.white.withOpacity(0.3)),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => _handleDrawerNavigation(4),
            ),
          ],
        ),
      ),
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
              Builder(builder: (context) => buildHeader(context)),
              Expanded(child: _buildCurrentScreen()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // Method to build the current screen based on selected index
  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            return GroupAuctionWidget(
              currentUserId: userProvider.user?.id?.toString(),
              onRefresh: _fetchAuctions,
            );
          },
        );
      case 1:
        return _buildMyTeams(context);
      case 2:
        return _buildProfile(context);
      default:
        return Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            return GroupAuctionWidget(
              currentUserId: userProvider.user?.id?.toString(),
              onRefresh: _fetchAuctions,
            );
          },
        );
    }
  }

  Widget _buildMyTeams(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Check if user is logged in
        if (userProvider.user == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 80, color: Colors.red),
                SizedBox(height: 20),
                Text(
                  'Please Login',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'You need to login to view your teams',
                  style: TextStyle(color: Color(0xFF95D5B2), fontSize: 16),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to login screen
                    Navigator.pushNamed(context, '/login');
                  },
                  child: Text('Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
          );
        }

        // User is logged in, show MyTeamsWidget with user ID
        return MyTeamsWidget(userId: userProvider.user!.id.toString());
      },
    );
  }

  Widget _buildProfile(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              // Profile Header Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryColor.withOpacity(0.1),
                      AppColors.primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar with status indicator
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryColor.withOpacity(0.3),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child:
                              (userProvider.user?.profilepic == null ||
                                      userProvider.user!.profilepic!.isEmpty)
                                  ? CircleAvatar(
                                    radius: 60,
                                    backgroundColor: AppColors.primaryColor,
                                    child: Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  )
                                  : CircleAvatar(
                                    radius: 60,
                                    backgroundImage: NetworkImage(
                                      userProvider.user!.profilepic!,
                                    ),
                                  ),
                        ),
                        if (userProvider.user != null)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color:
                                    userProvider.user!.profilecompleted == true
                                        ? Colors.green
                                        : Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                userProvider.user!.profilecompleted == true
                                    ? Icons.check
                                    : Icons.warning,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Name
                    Text(
                      userProvider.user?.name ?? 'Welcome!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 12),

                    // Subtitle
                    Text(
                      userProvider.user != null
                          ? 'Manage your account settings'
                          : 'Sign in to access your profile',
                      style: TextStyle(
                        color: Color(0xFF95D5B2),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // User Details Section (if logged in)
              if (userProvider.user != null) ...[
                // Contact Information Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Information',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Email
                      if (userProvider.user?.email != null)
                        _buildInfoRow(
                          Icons.email_outlined,
                          'Email',
                          userProvider.user!.email!,
                        ),

                      // Phone
                      if (userProvider.user?.phone != null) ...[
                        SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.phone_outlined,
                          'Phone',
                          userProvider.user!.phone.toString(),
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 16),

                SizedBox(height: 24),

                // Profile Completion Warning
                if (userProvider.user!.profilecompleted == false)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                          size: 32,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Complete Your Profile',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Complete your profile to participate in auctions and unlock all features',
                          style: TextStyle(
                            color: Colors.orange.withOpacity(0.8),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                // Action Buttons
                Column(
                  children: [
                    // Complete Profile Button
                    if (userProvider.user!.profilecompleted == false)
                      Container(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigator.pushNamed(context, '/complete-profile');
                          },
                          icon: Icon(Icons.edit, color: Colors.white),
                          label: Text(
                            'Complete Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    if (userProvider.user!.profilecompleted == false)
                      SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfileScreen(),
                            ),
                          );
                        },
                        icon: Icon(Icons.edit, color: Colors.white),
                        label: Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),

                    // Logout Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showLogoutDialog(context, userProvider);
                        },
                        icon: Icon(Icons.logout, color: Colors.white),
                        label: Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Login Section (if not logged in)
                Container(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    icon: Icon(Icons.login, color: Colors.white),
                    label: Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],

              SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // Helper widget for information rows
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Color(0xFF95D5B2), size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Color(0xFF95D5B2),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Logout confirmation dialog
  void _showLogoutDialog(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Confirm Logout', style: TextStyle(color: Colors.white)),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                userProvider.logout(context);
              },
              child: Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    return ClipRRect(
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: AppColors.secondaryaccentColor,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Color(0xFF95D5B2),
          unselectedItemColor: Colors.white54,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups),
              label: 'My Teams',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
