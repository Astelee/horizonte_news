import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Cabeçalho com Degradê
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, AppColors.primaryBlue], // Ou use Colors.orange.shade900 se preferir
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
                  child: Icon(Icons.newspaper, color: AppColors.primaryBlue, size: 40),
                ),
                SizedBox(height: 10),
                Text('Horizonte News', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Jornalismo independente local', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Início'),
            onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: const Text('Notícias Salvas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.favorites);
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Vídeos / Reportagens'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.videos);
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_mail),
            title: const Text('Fale Conosco / Denúncias'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.contact);
            },
          ),
          const Divider(),
          // Novo botão de Configurações
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurações'),
            onTap: () {
              Navigator.pop(context);
              // Aqui chamamos a nova tela de configurações
              Navigator.pushNamed(context, '/settings'); 
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Versão 1.0.0 © 2026', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}