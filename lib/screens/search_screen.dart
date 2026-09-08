import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/posts_provider.dart';
import '../widgets/news_card.dart';

/// Tela de busca de notícias. Segue a mesma identidade visual do
/// resto do app (fundo preto, partículas de fogo animadas, glow
/// laranja, cards translúcidos com blur) — o mesmo padrão usado no
/// editor de notícias do painel ADM.
///
/// ATENÇÃO: só o visual foi refeito. Toda a lógica de busca (chamada
/// a PostsProvider.search, tratamento de loading/erro/resultado
/// vazio) continua idêntica.
class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  late final AnimationController _particleCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isNotEmpty) {
      Provider.of<PostsProvider>(context, listen: false).search(query.trim());
      setState(() {}); // atualiza os estados vazios/placeholder abaixo do campo
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _particleCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.black)),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) => CustomPaint(
                painter: _SearchParticlePainter(_particleCtrl.value),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: Consumer<PostsProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading) {
                        return _buildLoadingState();
                      }

                      if (provider.errorMessage.isNotEmpty &&
                          _searchController.text.isNotEmpty) {
                        return _buildMessageState(
                          icon: Icons.error_outline_rounded,
                          iconColor: Colors.redAccent,
                          message: 'Erro ao buscar: ${provider.errorMessage}',
                        );
                      }

                      if (provider.searchResults.isEmpty &&
                          _searchController.text.isNotEmpty) {
                        return _buildMessageState(
                          icon: Icons.search_off_rounded,
                          iconColor: AppColors.textSecondary,
                          message:
                              'Nenhum resultado encontrado para "${_searchController.text}"',
                        );
                      }

                      if (_searchController.text.isEmpty) {
                        return _buildMessageState(
                          icon: Icons.search_rounded,
                          iconColor: AppColors.primaryOrange,
                          message: 'Digite um termo para pesquisar no portal',
                          glow: true,
                        );
                      }

                      return ListView.builder(
                        itemCount: provider.searchResults.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          final post = provider.searchResults[index];
                          return NewsCard(post: post);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF161616).withOpacity(0.82),
                        const Color(0xFF0D0D0D).withOpacity(0.82),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: const Color(0xFF262626)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: AppColors.primaryOrange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Buscar notícias...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                                color: Color(0xFF666666), fontSize: 14),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                          cursorColor: AppColors.primaryOrange,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _onSearchSubmitted,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded,
                              color: Color(0xFF888888), size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (_, __) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.orangeGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.5 * _glowAnim.value),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required Color iconColor,
    required String message,
    bool glow = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            glow
                ? AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryOrange.withOpacity(0.08),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryOrange
                                .withOpacity(0.35 * _glowAnim.value),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 48, color: iconColor),
                    ),
                  )
                : Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PARTÍCULAS DE FOGO DE FUNDO (mesmo padrão visual do editor/ranking)
// ═══════════════════════════════════════════════════════════════════
class _SearchParticlePainter extends CustomPainter {
  final double t;
  _SearchParticlePainter(this.t);

  static final _rng = math.Random(7);
  static final _particles = List.generate(
    36,
    (i) => _SPData(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: 1.2 + _rng.nextDouble() * 2.6,
      speed: 0.02 + _rng.nextDouble() * 0.05,
      opacity: 0.25 + _rng.nextDouble() * 0.45,
      phase: _rng.nextDouble(),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6B00).withOpacity(0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.88, size.height * 0.06),
        radius: size.width * 0.85,
      ));
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.06),
      size.width * 0.85,
      orbPaint,
    );

    final orbPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF2200).withOpacity(0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.08, size.height * 0.9),
        radius: size.width * 0.75,
      ));
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.9),
      size.width * 0.75,
      orbPaint2,
    );

    for (final p in _particles) {
      final dy = 1.0 - ((p.y + t * p.speed + p.phase) % 1.0);
      final dx = p.x + 0.025 * math.sin((t * 2 * math.pi * 0.6) + p.phase * 6.28);
      final fireRatio = 1.0 - dy;
      final color = Color.lerp(
        const Color(0xFFFFA040),
        const Color(0xFFFF2200),
        fireRatio,
      )!;
      final opacity = p.opacity *
          (0.5 + 0.5 * math.sin(t * 2 * math.pi * p.speed * 10 + p.phase));

      final center = Offset(dx * size.width, dy * size.height);
      final finalOpacity = opacity.clamp(0.0, 0.7);

      canvas.drawCircle(
        center,
        p.size * 3,
        Paint()..color = color.withOpacity(finalOpacity * 0.15),
      );
      canvas.drawCircle(
        center,
        p.size,
        Paint()..color = color.withOpacity(finalOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(_SearchParticlePainter old) => old.t != t;
}

class _SPData {
  final double x, y, size, speed, opacity, phase;
  const _SPData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}