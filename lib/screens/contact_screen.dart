import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({Key? key}) : super(key: key);

  Future<void> _launchIntent(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o aplicativo correspondente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FALE CONOSCO'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Envie sua Denúncia ou Sugestão',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 10),
            const Text(
              'Você faz o jornalismo junto com a gente. Flagrou algo na cidade ou tem uma reclamação? Entre em contato pelos nossos canais oficiais.',
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Botão WhatsApp (Denúncias urgentes)
            Card(
              color: const Color(0xFF25D366),
              child: ListTile(
                leading: const Icon(Icons.chat, color: Colors.white, size: 28),
                title: const Text(
                  'WhatsApp Geral / Plantão',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                // CORREÇÃO: Usando AppColors.whiteFaded
                subtitle: const Text('Envie fotos e vídeos de flagrantes', style: TextStyle(color: AppColors.whiteFaded)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white),
                onTap: () => _launchIntent(context, 'https://wa.me/549111111111'),
              ),
            ),
            const SizedBox(height: 12),

            // Botão Instagram
            Card(
              color: const Color(0xFFE1306C),
              child: ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                title: const Text(
                  'Instagram Oficial',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                // CORREÇÃO: Usando AppColors.whiteFaded
                subtitle: const Text('@horizontenews', style: TextStyle(color: AppColors.whiteFaded)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white),
                onTap: () => _launchIntent(context, 'https://instagram.com'),
              ),
            ),
            const SizedBox(height: 12),

            // Botão E-mail Comercial
            Card(
              child: ListTile(
                leading: const Icon(Icons.email, color: AppColors.primaryBlue, size: 28),
                title: const Text(
                  'E-mail de Contato',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('contato@horizontenews.com'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _launchIntent(context, 'mailto:contato@horizontenews.com'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}