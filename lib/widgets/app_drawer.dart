import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../providers/theme_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Drawer(
      child: Column(
        children: [
          // Cabeçalho institucional do Menu Lateral
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.primaryBlue,
            ),
            accountName: const Text(
              'Horizonte News',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: const Text('Jornalismo independente local'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.newspaper, color: AppColors.primaryBlue, size: 40),
            ),
          ),
          // Itens de Navegação
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Início'),
            onTap: () {
              Navigator.pushReplacementNamed(context, AppRoutes.home);
            },
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
          // Seção de Configuração do Tema Reativo
          SwitchListTile(
            title: const Text('Modo Escuro'),
            subtitle: const Text('Economize bateria no AMOLED'),
            secondary: Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            value: themeProvider.isDarkMode,
            onChanged: (bool value) {
              themeProvider.toggleTheme();
            },
          ),
          const Spacer(),
          // Rodapé informativo
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Versão 1.0.0 © 2026',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
