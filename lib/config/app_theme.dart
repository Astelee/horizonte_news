import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Configuração do Tema Claro
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.surfaceLight,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardTheme(
        color: AppColors.surfaceLight,
        elevation: 2,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondaryLight,
          fontSize: 14,
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentBlue,
        surface: AppColors.surfaceLight,
        error: AppColors.emergencyRed,
      ),
    );
  }

  // Configuração do Tema Escuro (AMOLED Friendly)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark, // Mantido escuro para o AMOLED
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        // Adicionando uma borda sutil na AppBar para destacar no modo escuro
        shape: Border(
          bottom: BorderSide(color: AppColors.surfaceDark, width: 1),
        ),
      ),
      cardTheme: const CardTheme(
        color: AppColors.surfaceDark,
        elevation: 1,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 14,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentBlue,
        surface: AppColors.surfaceDark,
        error: AppColors.emergencyRed,
      ),
    );
  }
}