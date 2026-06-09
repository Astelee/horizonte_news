import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../widgets/app_drawer.dart';

class MostReadScreen extends StatelessWidget {
  const MostReadScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: const Text(
          'Mais Lidas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text(
          'Em breve',
          style: TextStyle(color: Colors.white38),
        ),
      ),
    );
  }
}
