import 'package:flutter/material.dart';

/// True OLED Pitch-Black Theme for Planly.
/// Provides pure black (#000000) background to turn off OLED pixels,
/// dark charcoal (#121212 / #161616) surfaces, and vibrant neon cyan/mint accents.
class OledTheme {
  OledTheme._();

  // True OLED Black & Charcoal Palette
  static const Color pureBlack = Color(0xFF000000);
  static const Color charcoalCard = Color(0xFF121212);
  static const Color charcoalCardElevated = Color(0xFF181818);
  static const Color charcoalInput = Color(0xFF161616);
  static const Color charcoalBorder = Color(0xFF262626);
  static const Color charcoalDivider = Color(0xFF1F1F1F);

  // Vibrant Accents
  static const Color neonMint = Color(0xFF00F5D4);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonElectricBlue = Color(0xFF00BBF9);
  static const Color neonPink = Color(0xFFF15BB5);
  static const Color neonAmber = Color(0xFFFEE440);

  /// Default accent for OLED theme (vibrant neon mint)
  static const Color defaultAccent = neonMint;

  /// Custom spring curve for fluid modal bottom sheet transitions
  static const Curve sheetSpringCurve = Curves.easeOutBack;
  static const Duration sheetAnimationDuration = Duration(milliseconds: 380);

  /// Builds the complete OLED pitch-black ThemeData.
  static ThemeData buildTheme({Color? accentColor}) {
    final primary = accentColor ?? defaultAccent;
    final onPrimary = primary.computeLuminance() > 0.4 ? Colors.black : Colors.white;

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      secondary: neonCyan,
      onSecondary: Colors.black,
      tertiary: neonElectricBlue,
      onTertiary: Colors.black,
      error: const Color(0xFFFF5252),
      onError: Colors.black,
      surface: charcoalCard,
      onSurface: Colors.white,
      surfaceContainerLowest: pureBlack,
      surfaceContainerLow: charcoalCard,
      surfaceContainer: charcoalCardElevated,
      surfaceContainerHigh: charcoalInput,
      surfaceContainerHighest: charcoalBorder,
      outline: charcoalBorder,
      outlineVariant: charcoalDivider,
      shadow: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pureBlack,
      canvasColor: pureBlack,
      cardColor: charcoalCard,
      dividerColor: charcoalDivider,
      
      appBarTheme: const AppBarTheme(
        backgroundColor: pureBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      cardTheme: CardThemeData(
        color: charcoalCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: charcoalBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: charcoalCard,
        modalBackgroundColor: charcoalCard,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: charcoalBorder, width: 1),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pureBlack,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary);
          }
          return const IconThemeData(color: Colors.white54);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
          );
        }),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: charcoalCardElevated,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: charcoalBorder, width: 1),
        ),
        elevation: 6,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: charcoalInput,
        hintStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: charcoalBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: charcoalBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: charcoalCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: charcoalBorder, width: 1),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return Colors.white38;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.35);
          }
          return charcoalInput;
        }),
        trackOutlineColor: WidgetStateProperty.all(charcoalBorder),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(onPrimary),
        side: const BorderSide(color: charcoalBorder, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: charcoalDivider,
        thickness: 1,
        space: 1,
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
        bodySmall: TextStyle(fontSize: 12, color: Colors.white54),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}
