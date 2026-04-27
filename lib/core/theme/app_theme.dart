import 'package:flutter/material.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const brandTeal = Color(0xFF1B7EA6);
const brandDark = Color(0xFF0D2B3E);
const brandGrey = Color(0xFF8A9BAE);
const brandBackground = Color(0xFFF5F7FA);
const brandError = Color(0xFFC62828);
const brandGreen = Color(0xFF2E7D32);

// ── Theme ─────────────────────────────────────────────────────────────────────
final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: brandTeal,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD0EAF5),
    onPrimaryContainer: brandDark,
    secondary: brandGrey,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFDDE3EA),
    onSecondaryContainer: brandDark,
    surface: brandBackground,
    onSurface: brandDark,
    onSurfaceVariant: brandGrey,
    error: brandError,
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF8C0009),
    outline: Color(0xFFDDE3EA),
    outlineVariant: Color(0xFFDDE3EA),
  ),
  scaffoldBackgroundColor: brandBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: brandDark,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: brandTeal, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: brandError),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: brandError, width: 2),
    ),
    labelStyle: const TextStyle(color: brandGrey),
    prefixIconColor: brandGrey,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: brandTeal,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: brandTeal,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: brandTeal,
      side: const BorderSide(color: brandTeal),
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: brandTeal,
    foregroundColor: Colors.white,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFDDE3EA)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFFDDE3EA)),
  iconTheme: const IconThemeData(color: brandGrey),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
        color: brandDark, fontWeight: FontWeight.w700, fontSize: 22),
    titleLarge: TextStyle(
        color: brandDark, fontWeight: FontWeight.w600, fontSize: 18),
    titleMedium: TextStyle(
        color: brandDark, fontWeight: FontWeight.w600, fontSize: 16),
    bodyLarge: TextStyle(color: brandDark, fontSize: 16),
    bodyMedium: TextStyle(color: brandDark, fontSize: 14),
    bodySmall: TextStyle(color: brandGrey, fontSize: 12),
    labelLarge: TextStyle(
        color: brandTeal, fontWeight: FontWeight.w600, fontSize: 14),
    titleSmall: TextStyle(
        color: brandDark, fontWeight: FontWeight.w500, fontSize: 14),
  ),
);
