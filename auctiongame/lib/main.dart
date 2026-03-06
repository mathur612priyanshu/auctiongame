import 'dart:async';
import 'dart:convert';

import 'package:auctiongame/constants.dart';
import 'package:auctiongame/helpers/tokenmanager.dart';
import 'package:auctiongame/models/usermodel.dart';
import 'package:auctiongame/providers/themeprovider.dart';
import 'package:auctiongame/providers/userprovider.dart';
import 'package:auctiongame/screens/auth/loginscreen.dart';
import 'package:auctiongame/screens/editProfile/EditPorfileScreen.dart';
import 'package:auctiongame/screens/home/homescreen.dart';
import 'package:auctiongame/screens/home/widgets/loader.dart';
import 'package:auctiongame/splashScreen.dart';
import 'package:auctiongame/theme/appcolor.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Capture Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    debugPrint('STACK TRACE (Flutter framework error):');
    debugPrintStack(stackTrace: details.stack);
  };

  // Capture Dart (async/future/isolates) errors
  return runZonedGuarded(
    () {
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => Themeprovider()),
            // ChangeNotifierProvider(create: (_) => DutyProvider()),
          ],
          child: MainApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('ERROR: $error');
      debugPrint('STACK TRACE:');
      debugPrintStack(stackTrace: stack);
    },
  );
}
// return runApp(
//   MultiProvider(
//     providers: [
//       ChangeNotifierProvider(create: (_) => UserProvider()),
//       ChangeNotifierProvider(create: (_) => Themeprovider()),
//       // ChangeNotifierProvider(create: (_) => DutyProvider()),
//     ],
//     child: MainApp(),
//   ),
// );
// }

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add this line

      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      // darkTheme: ThemeData.dark().copyWith(
      //   colorScheme: ColorScheme.dark(
      //     primary: Colors.deepPurple,
      //     secondary: Colors.deepPurpleAccent,
      //   ),
      //   useMaterial3: true,
      // ),
      theme: ThemeData(
        scaffoldBackgroundColor:
            Provider.of<Themeprovider>(context)
                .themeData
                .scaffoldBackgroundColor, // Set background for all screens

        primarySwatch: Colors.orange, // Set the primary color to Orange

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor, // Change button color
            foregroundColor: Colors.white, // Text color
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(AppColors.primaryColor),
          trackColor: WidgetStateProperty.all(Colors.grey.shade200),
        ),

        colorScheme: Provider.of<Themeprovider>(context).themeData.colorScheme,
        primaryColor: AppColors.primaryColor,
        buttonTheme: ButtonThemeData(
          buttonColor: AppColors.primaryColor, // Button color
          textTheme: ButtonTextTheme.primary,
        ),
        cardColor: Colors.black,
        dividerColor: Colors.orangeAccent,
        iconTheme: IconThemeData(color: Colors.orangeAccent),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: SplashScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    String? token = await TokenManager.getToken();

    if (token == null || token.isEmpty) {
      _redirectToLogin();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$serverurl/auth/userdetail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.body}');
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        final userdata = User.fromJson(data['user']);

        Provider.of<UserProvider>(context, listen: false).setUser(userdata);

        if (userdata.profilecompleted == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showCompleteProfileDialog(context);
          });
        }

        setState(() {
          _isAuthenticated = true;
        });
      } else {
        await TokenManager.removeToken();
        _redirectToLogin();
      }
    } catch (e) {
      print('Error fetching user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCompleteProfileDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false, // disable drag-down dismiss
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false, // disable Android back
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 45,
                    color: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Complete Your Profile",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Add a profile picture to personalize your account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text("Add Profile Picture"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        );
      },
    );
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // if (_isLoading) {
    //   return Scaffold(
    //     body: Center(child: CircularProgressIndicator()),
    //   );
    // }
    return Scaffold(
      body: LoaderWidget(
        isLoading: _isLoading, // Dynamically set loading state
        imageAssetPath: 'assets/loader.gif',
        text: 'Please wait...',
        child: _isAuthenticated ? HomeScreen() : LoginScreen(),
      ),
    );
    // return _isAuthenticated ? Home() : LoginScreen();
  }
}
