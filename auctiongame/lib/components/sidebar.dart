import 'package:auctiongame/providers/themeprovider.dart';
import 'package:auctiongame/providers/userprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Sidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          return SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                // UserAccountsDrawerHeader(
                //   accountName: Text(userProvider.user?.Name ?? 'User'),
                //   accountEmail:
                //       Text(userProvider.user?.Phone ?? 'user@example.com'),
                //   currentAccountPicture: CircleAvatar(
                //     backgroundColor: Colors.white,
                //     backgroundImage: userProvider.user?.ProfilePic != null &&
                //             userProvider.user!.ProfilePic!.isNotEmpty
                //         ? NetworkImage(userProvider.user!.ProfilePic!)
                //         : null, // Handle null case
                //     child: userProvider.user?.ProfilePic == null ||
                //             userProvider.user!.ProfilePic!.isEmpty
                //         ? Icon(Icons.person,
                //             size: 50, color: Colors.grey) // Default icon
                //         : null,
                //   ),
                //   decoration: BoxDecoration(color: AppColors.primaryColor),
                // ),
                // ListTile(
                //   leading: Icon(Icons.home),
                //   title: Text('Home'),
                //   onTap: () {
                //     Navigator.pop(context);
                //   },
                // ),
                Container(
                  height: MediaQuery.of(context).size.height * 0.14,
                  child: Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/dark_logo_splash.png'
                        : 'assets/logo1.png',
                  ),
                ),
                Divider(),

                ListTile(
                  leading: Icon(Icons.add_circle),
                  title: Text('Edit profile'),
                  onTap: () {
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => UserProfileScreen(),
                    //   ),
                    // );
                    // Add navigation logic for settings
                  },
                ),
                ListTile(
                  leading: Icon(Icons.person),
                  title: Text('My Auctions'),
                  onTap: () {
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder:
                    //         (context) => Viewprofilescreen(
                    //           userId: userProvider.user!.Id,
                    //         ),
                    //   ),
                    // );
                    // Add navigation logic for settings
                  },
                ),
                // Consumer<Themeprovider>(
                //   builder: (context, themeProvider, child) {
                //     bool isLightMode = themeProvider.themeData == lightMode;
                //     return ListTile(
                //       leading: Icon(
                //         isLightMode ? Icons.dark_mode : Icons.light_mode,
                //       ),
                //       title: Text(isLightMode ? 'Dark Mode' : 'Light Mode'),
                //       onTap: () => themeProvider.toggleTheme(),
                //     );
                //   },
                // ),
                ListTile(
                  leading: Icon(Icons.support_agent_outlined),
                  title: Text('Query and Support'),
                  // onTap: () {
                  //   Navigator.push(
                  //     context,
                  //     MaterialPageRoute(builder: (context) => ContactUsForm()),
                  //   );
                  //   // userProvider.logout();
                  //   // Add navigation logic to login screen
                  // },
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.exit_to_app),
                  title: Text('Logout'),
                  onTap: () {
                    userProvider.logout(context);
                    // Add navigation logic to login screen
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
