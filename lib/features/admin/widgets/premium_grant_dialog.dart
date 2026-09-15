import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/premium_config.dart';

// ═══════════════════════════════════════════════════════════════════
// DIALOG ADMIN — CONCEDER PREMIUM
// ═══════════════════════════════════════════════════════════════════
// Segue o mesmo padrão de BanUserDialog: retorna um Map via
// Navigator.pop(context, result) para quem chamou processar, em vez
// de escrever no Firestore diretamente aqui.
//
// result:
//   { 'tier': PremiumTier.pro, 'days': 30 }   → conceder/renovar
//   null                                       → cancelado
// ═══════════════════════════════════════════════════════════════════

class PremiumGrantDialog extends StatefulWidget {
  final String userName;
  final PremiumTier currentTier;

  const PremiumGrantDialog({
    required this.userName,
    this.currentTier = PremiumTier.none,
    Key? key,
  }) : super(key: key);

  @override
  State<PremiumGrantDialog> createState() => _PremiumGrantDialogState();
}

class _PremiumGrantDialogState extends State<PremiumGrantDialog> {
  late PremiumTier _selectedTier;
  int _selectedDays = 30;

  static const _durationOptions = [
    {'label': '7 dias', 'days': 7},
    {'label': '30 dias', 'days': 30},
    {'label': '90 dias', 'days': 90},
    {'label': '365 dias', 'days': 365},
  ];

  @override
  void initState() {
    super.initState();
    _selectedTier = widget.currentTier.isPremium
        ? widget.currentTier
        : PremiumTier.pro;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _selectedTier.accentColor;

    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Color(0xFFF2B705), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Premium — ${widget.userName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.currentTier.isPremium)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.currentTier.accentColor
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          widget.currentTier.accentColor.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    'Já é ${widget.currentTier.label} atualmente. '
                    'Conceder de novo substitui o plano e a validade.',
                    style: TextStyle(
                      color: widget.currentTier.accentColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const Text(
              'Plano',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _tierOption(PremiumTier.pro)),
                const SizedBox(width: 8),
                Expanded(child: _tierOption(PremiumTier.ultra)),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Duração',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _durationOptions.map((opt) {
                final days = opt['days'] as int;
                final selected = _selectedDays == days;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDays = days),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? accent : AppColors.borderDark,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      opt['label'] as String,
                      style: TextStyle(
                        color:
                            selected ? accent : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.currentTier.isPremium)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const {'revoke': true}),
            child: const Text(
              'Revogar',
              style: TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, {
              'tier': _selectedTier,
              'days': _selectedDays,
            });
          },
          child: Text(
            'Conceder',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tierOption(PremiumTier tier) {
    final selected = _selectedTier == tier;
    final color = tier.accentColor;
    return GestureDetector(
      onTap: () => setState(() => _selectedTier = tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppColors.borderDark,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(tier.icon, color: selected ? color : Colors.white54,
                size: 18),
            const SizedBox(height: 6),
            Text(
              tier.label,
              style: TextStyle(
                color: selected ? color : Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${tier.xpMultiplier}x XP',
              style: TextStyle(
                color: selected
                    ? color.withOpacity(0.8)
                    : Colors.white38,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}