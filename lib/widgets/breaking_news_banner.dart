import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/post_model.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class BreakingNewsBanner extends StatefulWidget {
  final PostModel? urgentPost;
  const BreakingNewsBanner({Key? key, this.urgentPost}) : super(key: key);

  @override
  State<BreakingNewsBanner> createState() => _BreakingNewsBannerState();
}

class _BreakingNewsBannerState extends State<BreakingNewsBanner>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _pulseAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Pulso do ícone/borda
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Entrada deslizando de cima
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urgentPost == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pushNamed(
              context,
              AppRoutes.postDetail,
              arguments: widget.urgentPost,
            );
          },
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF1A0000),
                border: Border.all(
                  color: AppColors.emergencyRed
                      .withOpacity(0.4 + _pulseAnim.value * 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emergencyRed
                        .withOpacity(0.15 + _pulseAnim.value * 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Barra vermelha pulsante ────────────────────
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Container(
                        width: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.emergencyRed
                                  .withOpacity(_pulseAnim.value),
                              const Color(0xFFFF5252)
                                  .withOpacity(_pulseAnim.value * 0.5),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emergencyRed
                                  .withOpacity(0.6 * _pulseAnim.value),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Ícone de alerta ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.emergencyRed
                                .withOpacity(0.10 + _pulseAnim.value * 0.10),
                            border: Border.all(
                              color: AppColors.emergencyRed
                                  .withOpacity(0.3 + _pulseAnim.value * 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.emergencyRed
                                    .withOpacity(0.3 * _pulseAnim.value),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: AppColors.emergencyRed,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    // ── Texto ──────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                // Bolinha pulsante ao lado do label
                                AnimatedBuilder(
                                  animation: _pulseAnim,
                                  builder: (_, __) => Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.emergencyRed,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.emergencyRed
                                              .withOpacity(
                                                  _pulseAnim.value),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Text(
                                  'PLANTÃO · URGENTE',
                                  style: TextStyle(
                                    color: AppColors.emergencyRed,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.urgentPost!.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Seta ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.emergencyRed.withOpacity(0.7),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
