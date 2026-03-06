import 'package:auctiongame/helpers/tokenmanager.dart';
import 'package:auctiongame/models/usermodel.dart';
import 'package:auctiongame/screens/auth/loginscreen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  String? token;
  User? get user => _user; // Define a getter for _user

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  void setToken(newtoken) {
    token = newtoken;
    // notifyListeners();
  }

  void setPoins(int points) {
    _user?.points = (_user?.points ?? 0) + points;
    notifyListeners();
  }

  void logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await TokenManager.removeToken();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(),
        // builder: (context) => MyApp(),
      ),
      (Route<dynamic> route) => false, // Remove all previous routes
    );
    token = null;
    _user = null;
    notifyListeners();
  }
}
