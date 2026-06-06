import 'package:flutter/material.dart';

class AppColors {
  // Cor Principal / Dominante
  static const Color primaryBlue = Color(0xFF0D1B3E); 
  static const Color accentBlue = Color(0xFF1A2E5A);
  
  // Nova cor para o Degradê Laranja (alinhado com o pedido do Menu)
  static const Color primaryOrange = Color(0xFFE65100); 

  // Cores de Leitura e Fundos (Modo Claro)
  static const Color backgroundLight = Color(0xFFF8F9FA); 
  static const Color surfaceLight = Color(0xFFFFFFFF);    
  static const Color textPrimaryLight = Color(0xFF121212);  // Escurecido para melhor leitura
  static const Color textSecondaryLight = Color(0xFF575757); // Escurecido para melhor leitura

  // Cores de Leitura e Fundos (Modo Escuro)
  static const Color backgroundDark = Color(0xFF000000);  // Preto absoluto (AMOLED)
  static const Color surfaceDark = Color(0xFF121212);     // Diferenciação de camada
  static const Color textPrimaryDark = Color(0xFFFFFFFF);   // Branco puro para contraste total
  static const Color textSecondaryDark = Color(0xFFB0B0B0);  // Cinza claro para contraste no escuro

  // Alertas URGENTES
  static const Color emergencyRed = Color(0xFFD90429);    

  // Cores de Feedback e Bordas
  static const Color borderLight = Color(0xFFD1D1D1);
  static const Color borderDark = Color(0xFF333333);

  static const Color whiteFaded = Colors.white70;
}