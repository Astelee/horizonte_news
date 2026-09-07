import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class HorizonNowScreen extends StatelessWidget {
  HorizonNowScreen({Key? key}) : super(key: key);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: const Text(
          'Horizonte Agora',
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
      drawer: AppDrawer(scaffoldKey: _scaffoldKey),
      body: const Center(
        child: Text(
          'Em breve',
          style: TextStyle(color: Colors.white38),
        ),
      ),
    );
  }
}