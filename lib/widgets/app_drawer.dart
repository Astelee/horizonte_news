import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import necessário
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      // Fundo escuro igual ao do Login
      backgroundColor: AppColors.backgroundDark,
      child: Column(
        children: [
          // Cabeçalho com o gradiente laranja do Login
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFBF360C), Color(0xFFE65100)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Icon(Icons.public, color: Color(0xFFE65100), size: 40),
                ),
                SizedBox(height: 10),
                Text('HORIZONTE NEWS', 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
                Text('Jornalismo independente local', 
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),

          const SizedBox(height: 10),
          
          // Estilizando os itens para ficarem com texto branco
          _buildDrawerItem(Icons.home_rounded, 'Início', () => Navigator.pushReplacementNamed(context, AppRoutes.home)),
          _buildDrawerItem(Icons.bookmark_rounded, 'Notícias Salvas', () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.favorites);
          }),
          _buildDrawerItem(Icons.settings_rounded, 'Configurações', () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/settings');
          }),
          
          const Divider(color: Color(0xFF212121)),
          
          // Botão de Sair com cor de destaque (emergencyRed)
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.emergencyRed),
            title: const Text('Sair da conta', style: TextStyle(color: AppColors.emergencyRed)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              // O AuthGate no main.dart redirecionará automaticamente
            },
          ),
          
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Versão 1.0.0 © 2026', style: TextStyle(fontSize: 12, color: Color(0xFF424242))),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para não repetir código
  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryOrange),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}