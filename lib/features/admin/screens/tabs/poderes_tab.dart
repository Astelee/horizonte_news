import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/badge_config.dart';
import '../../../../widgets/avatar_frame.dart';
import '../../../../widgets/app_avatar.dart';
import '../../../../providers/user_xp_provider.dart';

/// Tela somente-visualização: mostra como cada nível/moldura fica,
/// sem aplicar nada em usuário nenhum. Útil como referência rápida
/// para decisões de design (cores, raridades, molduras) sem risco
/// de mexer em dados reais.
///
/// Antes esta aba aplicava overrides de nível diretamente no perfil
/// do admin logado (via AdminUserService.applyLevelOverride). Essa
/// escrita foi removida de propósito — a aba é só uma vitrine.
class PoderesTab extends StatefulWidget {
  const PoderesTab({Key? key}) : super(key: key);

  @override
  State<PoderesTab> createState() => _PoderesTabState();
}

class _PoderesTabState extends State<PoderesTab> {
  int _previewLevel = 1;

  @override
  Widget build(BuildContext context) {
    final color = BadgeConfig.levelColor(_previewLevel);
    final gradient = BadgeConfig.levelGradient(_previewLevel);
    final title = BadgeConfig.levelTitle(_previewLevel);
    final rarity = BadgeConfig.levelRarity(_previewLevel);

    // Foto/nome do admin logado, para o preview refletir o usuário
    // real em vez de um placeholder genérico ("P" de "Preview").
    final xpData = context.watch<UserXpProvider>().data;
    final displayName = (xpData.username != null &&
            xpData.username!.trim().isNotEmpty)
        ? xpData.username!
        : 'Você';
    final photoUrl = xpData.photoUrl;

    return Container(
      color: AppColors.backgroundDark,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Aviso: tela só de visualização ────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.primaryOrange.withOpacity(0.06),
                border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_rounded,
                    color: AppColors.primaryOrange,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Apenas visualização — nada aqui é aplicado a usuários.',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
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
                    child: AppAvatar(
                      name: displayName,
                      photoUrl: photoUrl,
                      size: 90,
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

            // ── Seletor de nível (só muda o preview acima) ────────
            _SectionLabel(
                label: 'SELECIONAR NÍVEL PARA VISUALIZAR',
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

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
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