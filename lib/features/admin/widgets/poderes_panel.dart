import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/badge_config.dart';
import '../../../services/xp_service.dart';
import '../../../widgets/avatar_frame.dart';
import '../services/admin_user_service.dart';

/// Painel de "poderes" reutilizável: aplica/reseta NÍVEL e TAG/TÍTULO
/// de forma independente para o [uid] informado.
class PoderesPanel extends StatefulWidget {
  final String uid;
  final AdminUserService userService;
  final String displayName;

  const PoderesPanel({
    required this.uid,
    required this.userService,
    required this.displayName,
    Key? key,
  }) : super(key: key);

  @override
  State<PoderesPanel> createState() => _PoderesPanelState();
}

class _PoderesPanelState extends State<PoderesPanel> {
  int _previewLevel = 1;
  int _currentRealLevel = 1;
  int _currentOverrideLevel = 1;
  bool _isLevelOverrideActive = false;

  int _previewTitleLevel = 1;
  int _currentTitleOverrideLevel = 1;
  bool _isTitleOverrideActive = false;

  bool _loading = true;
  bool _savingLevel = false;
  bool _savingTitle = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    setState(() => _loading = true);
    try {
      final d = await widget.userService.getUserData(widget.uid);
      if (d != null) {
        final xp = (d['totalXp'] as num?)?.toInt() ?? 0;
        final realLevel = XpService.levelFromXp(xp);

        final overrideLevel = (d['adminOverrideLevel'] as num?)?.toInt();
        final hasLevelOverride = d['adminOverrideActive'] == true;

        final titleLevel =
            (d['adminOverrideTitleLevel'] as num?)?.toInt();
        final hasTitleOverride = d['adminOverrideTitleActive'] == true;

        setState(() {
          _currentRealLevel = realLevel;
          _currentOverrideLevel = overrideLevel ?? realLevel;
          _isLevelOverrideActive = hasLevelOverride;
          _previewLevel =
              hasLevelOverride ? (overrideLevel ?? realLevel) : realLevel;

          _currentTitleOverrideLevel = titleLevel ?? _previewLevel;
          _isTitleOverrideActive = hasTitleOverride;
          _previewTitleLevel =
              hasTitleOverride ? (titleLevel ?? _previewLevel) : _previewLevel;
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _aplicarNivel() async {
    setState(() => _savingLevel = true);
    try {
      await widget.userService.applyLevelOverride(widget.uid, _previewLevel);
      setState(() {
        _currentOverrideLevel = _previewLevel;
        _isLevelOverrideActive = true;
      });
      _snack('✅ Nível $_previewLevel aplicado!', const Color(0xFF66BB6A));
    } catch (e) {
      _snack('Erro ao aplicar nível: $e', AppColors.emergencyRed);
    }
    setState(() => _savingLevel = false);
  }

  Future<void> _resetarNivel() async {
    setState(() => _savingLevel = true);
    try {
      await widget.userService
          .resetLevelOverride(widget.uid, _currentRealLevel);
      setState(() {
        _previewLevel = _currentRealLevel;
        _currentOverrideLevel = _currentRealLevel;
        _isLevelOverrideActive = false;
      });
      _snack('🔄 Nível resetado para o real ($_currentRealLevel)',
          AppColors.primaryOrange);
    } catch (e) {
      _snack('Erro ao resetar: $e', AppColors.emergencyRed);
    }
    setState(() => _savingLevel = false);
  }

  Future<void> _aplicarTag() async {
    setState(() => _savingTitle = true);
    try {
      await widget.userService
          .applyTitleOverride(widget.uid, _previewTitleLevel);
      setState(() {
        _currentTitleOverrideLevel = _previewTitleLevel;
        _isTitleOverrideActive = true;
      });
      _snack(
          '✅ Tag "${BadgeConfig.levelTitle(_previewTitleLevel)}" aplicada!',
          const Color(0xFF66BB6A));
    } catch (e) {
      _snack('Erro ao aplicar tag: $e', AppColors.emergencyRed);
    }
    setState(() => _savingTitle = false);
  }

  Future<void> _resetarTag() async {
    setState(() => _savingTitle = true);
    try {
      await widget.userService.resetTitleOverride(widget.uid);
      setState(() {
        _previewTitleLevel = _previewLevel;
        _currentTitleOverrideLevel = _previewLevel;
        _isTitleOverrideActive = false;
      });
      _snack('🔄 Tag resetada para o nível oficial', AppColors.primaryOrange);
    } catch (e) {
      _snack('Erro ao resetar tag: $e', AppColors.emergencyRed);
    }
    setState(() => _savingTitle = false);
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );
    }

    final levelColor = BadgeConfig.levelColor(_previewLevel);
    final levelGradient = BadgeConfig.levelGradient(_previewLevel);
    final titleColor = BadgeConfig.levelColor(_previewTitleLevel);
    final titleGradient = BadgeConfig.levelGradient(_previewTitleLevel);
    final titleText = BadgeConfig.levelTitle(_previewTitleLevel);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primaryOrange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Poderes — ${widget.displayName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Preview combinado ────────────────────────────────
          Center(
            child: Column(
              children: [
                AvatarFrame(
                  level: _previewLevel,
                  size: 84,
                  enableEntryAnimation: false,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: levelGradient),
                    ),
                    child: Center(
                      child: Text(
                        widget.displayName.isNotEmpty
                            ? widget.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(colors: titleGradient),
                    boxShadow: [
                      BoxShadow(
                          color: titleColor.withOpacity(0.5), blurRadius: 14),
                    ],
                  ),
                  child: Text(
                    'Nível $_previewLevel · $titleText',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ═══════════════════════════════════════════════════
          // BLOCO 1 — NÍVEL (moldura, XP, cor)
          // ═══════════════════════════════════════════════════
          _BlocoLabel(
            icon: Icons.military_tech_rounded,
            label: 'NÍVEL (moldura, XP, cor)',
          ),
          const SizedBox(height: 10),
          _AvisoStatus(
            ativo: _isLevelOverrideActive,
            textoAtivo:
                'Override ativo: Nível $_currentOverrideLevel. Real: $_currentRealLevel',
            textoInativo: 'Sem override. Nível oficial: $_currentRealLevel',
          ),
          const SizedBox(height: 14),
          _SeletorNivel(
            value: _previewLevel,
            color: levelColor,
            title: BadgeConfig.levelTitle(_previewLevel),
            onChanged: (v) => setState(() => _previewLevel = v),
          ),
          const SizedBox(height: 14),
          _BotaoAplicar(
            label: 'APLICAR NÍVEL $_previewLevel',
            gradient: levelGradient,
            color: levelColor,
            saving: _savingLevel,
            onTap: _aplicarNivel,
          ),
          if (_isLevelOverrideActive) ...[
            const SizedBox(height: 10),
            _BotaoResetar(
              label: 'RESETAR PARA NÍVEL REAL ($_currentRealLevel)',
              onTap: _resetarNivel,
              saving: _savingLevel,
            ),
          ],

          const SizedBox(height: 32),

          // ═══════════════════════════════════════════════════
          // BLOCO 2 — TAG / TÍTULO (independente do nível)
          // ═══════════════════════════════════════════════════
          _BlocoLabel(
            icon: Icons.local_offer_rounded,
            label: 'TAG / TÍTULO EXIBIDO',
          ),
          const SizedBox(height: 10),
          _AvisoStatus(
            ativo: _isTitleOverrideActive,
            textoAtivo:
                'Tag customizada ativa: "${BadgeConfig.levelTitle(_currentTitleOverrideLevel)}"',
            textoInativo: 'Sem tag customizada. Usando a tag do nível atual.',
          ),
          const SizedBox(height: 14),
          _SeletorNivel(
            value: _previewTitleLevel,
            color: titleColor,
            title: titleText,
            onChanged: (v) => setState(() => _previewTitleLevel = v),
          ),
          const SizedBox(height: 14),
          _BotaoAplicar(
            label: 'APLICAR TAG "$titleText"',
            gradient: titleGradient,
            color: titleColor,
            saving: _savingTitle,
            onTap: _aplicarTag,
          ),
          if (_isTitleOverrideActive) ...[
            const SizedBox(height: 10),
            _BotaoResetar(
              label: 'USAR TAG DO NÍVEL OFICIAL',
              onTap: _resetarTag,
              saving: _savingTitle,
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════

class _BlocoLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BlocoLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryOrange, size: 14),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryOrange,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primaryOrange.withOpacity(0.4),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvisoStatus extends StatelessWidget {
  final bool ativo;
  final String textoAtivo;
  final String textoInativo;

  const _AvisoStatus({
    required this.ativo,
    required this.textoAtivo,
    required this.textoInativo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: ativo
            ? const Color(0xFFFFD700).withOpacity(0.08)
            : AppColors.primaryOrange.withOpacity(0.06),
        border: Border.all(
          color: ativo
              ? const Color(0xFFFFD700).withOpacity(0.5)
              : AppColors.primaryOrange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ativo ? Icons.auto_awesome_rounded : Icons.info_outline_rounded,
            color: ativo ? const Color(0xFFFFD700) : AppColors.primaryOrange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ativo ? textoAtivo : textoInativo,
              style: TextStyle(
                color: ativo ? const Color(0xFFFFD700) : AppColors.primaryOrange,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeletorNivel extends StatelessWidget {
  final int value;
  final Color color;
  final String title;
  final ValueChanged<int> onChanged;

  const _SeletorNivel({
    required this.value,
    required this.color,
    required this.title,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nível $value',
                  style: TextStyle(
                      color: color, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.15),
              thumbColor: color,
              overlayColor: color.withOpacity(0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 99,
              divisions: 98,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [1, 5, 7, 10, 15, 18, 22, 27, 50, 99].map((lvl) {
              final selected = value == lvl;
              final c = BadgeConfig.levelColor(lvl);
              return GestureDetector(
                onTap: () => onChanged(lvl),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: selected ? c.withOpacity(0.2) : Colors.transparent,
                    border: Border.all(
                      color: selected ? c : const Color(0xFF2A2A2A),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    'Nv.$lvl',
                    style: TextStyle(
                      color: selected ? c : const Color(0xFF666666),
                      fontSize: 10,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BotaoAplicar extends StatelessWidget {
  final String label;
  final List<Color> gradient;
  final Color color;
  final bool saving;
  final VoidCallback onTap;

  const _BotaoAplicar({
    required this.label,
    required this.gradient,
    required this.color,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: saving ? null : LinearGradient(colors: gradient),
          color: saving ? const Color(0xFF1A1A1A) : null,
          boxShadow: saving
              ? null
              : [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
        ),
      ),
    );
  }
}

class _BotaoResetar extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback onTap;

  const _BotaoResetar({
    required this.label,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF0A0A0A),
          border: Border.all(color: AppColors.primaryOrange.withOpacity(0.35)),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.refresh_rounded,
                  color: AppColors.primaryOrange, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
