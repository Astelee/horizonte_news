import 'package:flutter/material.dart';

class AppColors {
  // --- IDENTIDADE VISUAL PRINCIPAL ---
  static const Color primary = Color(0xFFE65100); // Laranja Horizonte News
  static const Color accent = Color(0xFFF57C00);  // Laranja secundário (para degradês)

  // --- COMPATIBILIDADE (Para parar os erros de build) ---
  static const Color primaryBlue = primary; 
  static const Color accentBlue = accent;

  // --- FUNDOS E TEXTOS (Mantenha assim para o contraste perfeito) ---
  static const Color backgroundLight = Color(0xFFF8F9FA); 
  static const Color surfaceLight = Color(0xFFFFFFFF);    
  static const Color textPrimaryLight = Color(0xFF121212);  
  static const Color textSecondaryLight = Color(0xFF575757); 

  static const Color backgroundDark = Color(0xFF000000);  // Preto AMOLED
  static const Color surfaceDark = Color(0xFF121212);     
  static const Color textPrimaryDark = Color(0xFFFFFFFF);   
  static const Color textSecondaryDark = Color(0xFFB0B0B0);  

  static const Color emergencyRed = Color(0xFFD90429);    
  static const Color borderLight = Color(0xFFD1D1D1);
  static const Color borderDark = Color(0xFF333333);
}