import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF61DAFB);
  static const backgroundColor = Color(0xFF282C34);
  static const darkBackgroundColor = Color(0xFF1A1C20);
  
  static ThemeData get theme => ThemeData(
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      background: backgroundColor,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Colors.white,
        fontSize: 35,
        fontWeight: FontWeight.w300,
        letterSpacing: 2,
      ),
      bodyLarge: TextStyle(
        color: Color(0xFFA0A0A0),
        fontSize: 16,
        fontWeight: FontWeight.w300,
        letterSpacing: 1,
      ),
    ),
  );
} 