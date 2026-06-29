import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/badge_config.dart';
import '../../../../services/xp_service.dart';
import '../../../../widgets/avatar_frame.dart';
import '../../services/admin_user_service.dart';

class PoderesTab extends StatefulWidget {
  final AdminUserService userService;
  const PoderesTab({required this.userService, Key? key})
      : super(key: key);

  @override
  State<PoderesTab> createState() => _PoderesTabState();
}

class _PoderesTabState extends State<PoderesTab> {
  final _auth = FirebaseAuth.instance;

  int _previewLevel = 1;
  int _currentRealLevel = 1;
  int _currentOverrideLevel = 1;
  bool _isOverrideActive = false;
  bool _loading = true;
  bool _saving = false;

  String get _myUid => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users_xp')
          .doc(_myUid)
          .get();
      if (doc.exists) {
        final d = doc.data()!;
        final xp = (d['totalXp'] as num?)?.toInt() ?? 0;
        final realLevel = XpService.levelFromXp(xp);
        final overrideLevel =
            (d['adminOverrideLevel'] as num?)?.toInt();
        final hasOverride = d['adminOverrideActive'] == true;
        setState(() {
          _currentRealLevel = realLevel;
          _currentOverrideLevel = overrideLevel ?? realLevel;
          _isOverrideActive = hasOverride;
          _previewLevel =
              hasOverride ? (overrideLevel ?? realLevel) : realLevel;
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _aplicarNivel() async {
    setState(() => _saving = true);
    try {
      await widget.userService.applyLevelOverride(
          _myUid, _previewLevel);
      setState(() {
        _currentOverrideLevel = _previewLevel;
        _isOverrideActive = true;
      });
      _snack('✅ Nível $_previewLevel aplicado com sucesso!',
          const Color(0xFF66BB6A));
    } catch (e) {
      _snack('Erro ao aplicar nível: $e', AppColors.emergencyRed);
    }
    setState(() => _saving = false);
  }

  Future<void> _resetarNivelReal() async {
    setState(() => _saving = true);
    try {
      await widget.userService.resetLevelOverride(
          _myUid, _currentRealLevel);
      setState(() {
        _previewLevel = _currentRealLevel;
        _currentOverrideLevel = _currentRealLevel;
        _isOverrideActive = false;
      });
      _snack('🔄 Nível resetado para o real ($_currentRealLevel)',
          AppColors.primaryOrange);
    } catch (e) {
      _snack('Erro ao resetar: $e', AppColors.emergencyRed);
    }
    setState(() => _saving = false);
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: AppColors.backgroundDark,
        child: const Center(
          child: CircularProgressIndicator(
              color: AppColors.primaryOrange),
        ),
      );
    }

    final color = BadgeConfig.levelColor(_previewLevel);
    final gradient = BadgeConfig.levelGradient(_previewLevel);
    final title = BadgeConfig.levelTitle(_previewLevel);
    final rarity = BadgeConfig.levelRarity(_previewLevel);
    final user = _auth.currentUser;
    final initials = _getInitials(
        user?.displayName ?? user?.email);

    return Container(
      color: AppColors.backgroundDark,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Aviso de status ──────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _isOverrideActive
                    ? const Color(0xFFFFD700).withOpacity(0.08)
                    : AppColors.primaryOrange.withOpacity(0.06),
                border: Border.all(
                  color: _isOverrideActive
                      ? const Color(0xFFFFD700).withOpacity(0.5)
                      : AppColors.primaryOrange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isOverrideActive
                        ? Icons.auto_awesome_rounded
                        : Icons.info_outline_rounded,
                    color: _isOverrideActive
                        ? const Color(0xFFFFD700)
                        : AppColors.primaryOrange,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isOverrideActive
                          ? 'Override ativo: Nível $_currentOverrideLevel aplicado. Nível real: $_currentRealLevel'
                          : 'Nenhum override ativo. Nível atual: $_currentRealLevel',
                      style: TextStyle(
                        color: _isOverrideActive
                            ? const Color(0xFFFFD700)
                            : AppColors.primaryOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Preview da moldura ───────────────────────────────
            _SectionLabel(
                label: 'PREVIEW DA MOLDURA',
                icon: Icons.preview_rounded),
            const SizedBox(height: 16),

            Center(
              child: Column(
                children: [
                  AvatarFrame(
                    level: _previewLevel,
                    size: 90,
                    enableEntryAnimation: false,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(colors: gradient),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Text(
                      'Nível $_previewLevel · $title',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: color.withOpacity(0.12),
                      border: Border.all(
                          color: color.withOpacity(0.4)),
                    ),
                    child: Text(
                      rarity,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Seletor de nível ─────────────────────────────────
            _SectionLabel(
                label: 'SELECIONAR NÍVEL',
                icon: Icons.tune_rounded),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nível $_previewLevel',
                        style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: color,
                      inactiveTrackColor:
                          color.withOpacity(0.15),
                      thumbColor: color,
                      overlayColor: color.withOpacity(0.15),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: _previewLevel.toDouble(),
                      min: 1,
                      max: 99,
                      divisions: 98,
                      onChanged: (v) => setState(
                          () => _previewLevel = v.round()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 5, 7, 10, 15, 18, 22, 27, 50, 99]
                        .map((lvl) {
                      final selected = _previewLevel == lvl;
                      final c = BadgeConfig.levelColor(lvl);
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _previewLevel = lvl),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(20),
                            color: selected
                                ? c.withOpacity(0.2)
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? c
                                  : const Color(0xFF2A2A2A),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            'Nv.$lvl',
                            style: TextStyle(
                              color: selected
                                  ? c
                                  : const Color(0xFF666666),
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Grade de molduras ────────────────────────────────
            _SectionLabel(
                label: 'TODAS AS MOLDURAS',
                icon: Icons.grid_view_rounded),
            const SizedBox(height: 12),

            _MoldurasGrid(
              selectedLevel: _previewLevel,
              onSelect: (lvl) =>
                  setState(() => _previewLevel = lvl),
            ),

            const SizedBox(height: 28),

            // ── Botões de ação ───────────────────────────────────
            _SectionLabel(
                label: 'APLICAR', icon: Icons.bolt_rounded),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: _saving ? null : _aplicarNivel,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: _saving
                      ? null
                      : LinearGradient(colors: gradient),
                  color: _saving
                      ? const Color(0xFF1A1A1A)
                      : null,
                  boxShadow: _saving
                      ? null
                      : [
                          BoxShadow(
                            color: color.withOpacity(0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'APLICAR NÍVEL $_previewLevel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_isOverrideActive)
              GestureDetector(
                onTap: _saving ? null : _resetarNivelReal,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF0A0A0A),
                    border: Border.all(
                        color: AppColors.primaryOrange
                            .withOpacity(0.35)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded,
                            color: AppColors.primaryOrange,
                            size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'RESETAR PARA NÍVEL REAL ($_currentRealLevel)',
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

// ── Grade de molduras ────────────────────────────────────────────
class _MoldurasGrid extends StatelessWidget {
  final int selectedLevel;
  final ValueChanged<int> onSelect;

  const _MoldurasGrid({
    required this.selectedLevel,
    required this.onSelect,
  });

  static const _raridades = [
    {'label': 'Comum', 'levels': [1, 2, 3, 4, 5]},
    {'label': 'Incomum', 'levels': [6, 7]},
    {'label': 'Raro', 'levels': [8, 9, 10]},
    {'label': 'Épico', 'levels': [11, 12, 15]},
    {'label': 'Lendário', 'levels': [16, 18, 22]},
    {'label': 'Mítico', 'levels': [23, 27, 40]},
    {'label': 'Supremo', 'levels': [41, 50, 60]},
    {'label': 'Elite', 'levels': [70, 85, 99]},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _raridades.map((r) {
        final label = r['label'] as String;
        final levels = r['levels'] as List<int>;
        final color = BadgeConfig.levelColor(levels.first);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                            color: color.withOpacity(0.6),
                            blurRadius: 6)
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: levels.map((lvl) {
                final selected = selectedLevel == lvl;
                final c = BadgeConfig.levelColor(lvl);
                final g = BadgeConfig.levelGradient(lvl);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(lvl),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(
                          right: 8, bottom: 8),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: selected
                            ? c.withOpacity(0.12)
                            : const Color(0xFF0A0A0A),
                        border: Border.all(
                          color: selected
                              ? c
                              : const Color(0xFF1A1A1A),
                          width: selected ? 1.5 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: c.withOpacity(0.3),
                                  blurRadius: 10,
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          AvatarFrame(
                            level: lvl,
                            size: 36,
                            enableEntryAnimation: false,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient:
                                    LinearGradient(colors: g),
                              ),
                              child: Center(
                                child: Text(
                                  '$lvl',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Nv.$lvl',
                            style: TextStyle(
                              color: selected
                                  ? c
                                  : const Color(0xFF666666),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (selected)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c,
                                boxShadow: [
                                  BoxShadow(
                                      color: c.withOpacity(0.8),
                                      blurRadius: 4)
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ── Label de seção ───────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionLabel({required this.label, required this.icon});

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
