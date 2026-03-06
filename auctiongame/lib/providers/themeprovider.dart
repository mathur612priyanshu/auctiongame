import 'package:auctiongame/theme/appcolor.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Themeprovider with ChangeNotifier {
  ThemeData _themeData = lightMode;
  final String _themeKey = 'theme';

  Themeprovider() {
    _loadTheme();
  }

  ThemeData get themeData => _themeData;

  set setThemeData(ThemeData themeData) {
    _themeData = themeData;
    notifyListeners();
    _saveTheme();
  }

  void toggleTheme() {
    _themeData = _themeData == lightMode ? darkMode : lightMode;
    notifyListeners();
    _saveTheme();
  }

  Future<void> _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? themeName = prefs.getString(_themeKey);
    if (themeName == 'dark') {
      _themeData = darkMode;
    } else {
      _themeData = lightMode;
    }
    notifyListeners();
  }

  Future<void> _saveTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String themeName = _themeData == darkMode ? 'dark' : 'light';
    await prefs.setString(_themeKey, themeName);
  }
}
