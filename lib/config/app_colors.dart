import 'package:flutter/material.dart';

class AppColors {
  // --- IDENTIDADE VISUAL PRINCIPAL ---
  static const Color primaryOrange = Color(0xFFE65100); 
  static const Color accentOrange = Color(0xFFF57C00);

  // --- COMPATIBILIDADE (Para evitar erros de 'Member not found') ---
  static const Color primaryBlue = primaryOrange; 
  static const Color accentBlue = accentOrange;

  // --- CORES DE LEITURA E FUNDOS ---
  static const Color backgroundLight = Color(0xFFF8F9FA); 
  static const Color surfaceLight = Color(0xFFFFFFFF);    
  static const Color textPrimaryLight = Color(0xFF121212);  
  static const Color textSecondaryLight = Color(0xFF575757); 

  static const Color backgroundDark = Color(0xFF000000);  // Preto AMOLED
  static const Color surfaceDark = Color(0xFF121212);     
  static const Color textPrimaryDark = Color(0xFFFFFFFF);   
  static const Color textSecondaryDark = Color(0xFFB0B0B0);  

  // --- ALERTAS E FEEDBACK ---
  static const Color emergencyRed = Color(0xFFD90429);    
  static const Color borderLight = Color(0xFFD1D1D1);
  static const Color borderDark = Color(0xFF333333);

  // --- AUXILIARES ---
  static const Color whiteFaded = Colors.white70;
}