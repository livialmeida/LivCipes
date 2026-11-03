import 'package:flutter/material.dart';

abstract class AppColors {
  // Base surfaces (light and clean)
  static const Color background = Color(0xFFFDFBFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFF1E4E8);

  // Soft & Muted Rose accents
  static const Color primary = Color(0xFFBE185D);       // Deep berry rose
  static const Color primaryLight = Color(0xFFF472B6);  // Soft rose accent
  static const Color primaryTint = Color(0xFFFCE7F3);   // Pale blush (cards/chips)

  // Typography & contrast
  static const Color textPrimary = Color(0xFF2E1065);   // High-contrast muted slate/plum
  static const Color textSecondary = Color(0xFF705D68); // Muted rose slate

  // Feedback
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);

  // Equipment / Utensil Filter Tags
  static const Color equipmentTagBg = Color(0xFFF1F5F9);      // Slate neutro muito suave
  static const Color equipmentTagBorder = Color(0xFFE2E8F0);  // Borda sutil
  static const Color equipmentTagIcon = Color(0xFF475569);    // Ícone em cinza neutro escuro
  static const Color equipmentTagSelected = Color(0xFF9D174D);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        error: AppColors.error,
        onSurface: AppColors.textPrimary,
        onPrimary: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}