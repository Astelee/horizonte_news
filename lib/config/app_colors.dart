import 'package:flutter/material.dart';

class AppColors {
  // Cor Principal / Dominante
  static const Color primaryBlue = Color(0xFF0D1B3E); // Azul escuro corporativo e jornalístico
  static const Color accentBlue = Color(0xFF1A2E5A);  // Variação em azul para destaques secundários

  // Cores de Leitura e Fundos (Modo Claro)
  static const Color backgroundLight = Color(0xFFF8F9FA); // Fundo cinza claro muito suave
  static const Color surfaceLight = Color(0xFFFFFFFF);    // Superfície de cards e blocos em branco puro
  static const Color textPrimaryLight = Color(0xFF212529);  // Texto principal em grafite escuro
  static const Color textSecondaryLight = Color(0xFF6C757D); // Subtítulos e datas em cinza

  // Cores de Leitura e Fundos (Modo Escuro)
  static const Color backgroundDark = Color(0xFF121212);  // Fundo escuro absoluto padrão AMOLED
  static const Color surfaceDark = Color(0xFF1E1E1E);     // Superfície de cards no modo escuro
  static const Color textPrimaryDark = Color(0xFFE9ECEF);   // Texto principal em esbranquiçado
  static const Color textSecondaryDark = Color(0xFFADB5BD);  // Subtítulos no modo escuro

  // Alertas URGENTES e Notícias Policiais / Plantão
  static const Color emergencyRed = Color(0xFFD90429);    // Vermelho vivo de alta atenção

  // Cores de Feedback e Bordas
  static const Color borderLight = Color(0xFFDEE2E6);
  static const Color borderDark = Color(0xFF2D2D2D);
  
  // Adicionando esta cor que o compilador reclamou que faltava:
  static const Color whiteFaded = Colors.white70;
}