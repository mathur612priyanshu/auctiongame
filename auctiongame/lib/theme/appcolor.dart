import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
  // scaffoldBackgroundColor:
  //     Colors.grey.shade100, // Set background for all screens
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(surface: Colors.grey.shade100),
);

ThemeData darkMode = ThemeData(
  // scaffoldBackgroundColor:
  //     Colors.grey.shade800, // Set background for all screens
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(surface: Colors.grey.shade900),
);

class AppColors {
  static const Color primaryColor = Color.fromARGB(206, 105, 253, 0);
  static const Color secondaryColor = Color.fromARGB(206, 100, 142, 70);

  static const Color accentColor = Colors.black;
  static const Color secondaryaccentColor = Color(0xFF1B4332);
}
