import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class CategoryBar extends StatefulWidget {
  const CategoryBar({Key? key}) : super(key: key);

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<CategoryBar> {
  static const List<Map<String, dynamic>> _categories = [
    {
      'label': 'Horizonte',
      'icon': FontAwesomeIcons.buildingColumns,
      'emoji': '🏛️',
      'color': Color(0xFFFF6B00),
    },
    {
      'label': 'Pacajus',
      'icon': FontAwesomeIcons.tree,
      'emoji': '🌳',
      'color': Color(0xFF43A047),
    },
    {
      'label': 'Itaitinga',
      'icon': FontAwesomeIcons.water,
      'emoji': '💧',
      'color': Color(0xFF1E88E5),
    },
    {
      'label': 'Chorozinho',
      'icon': FontAwesomeIcons.wheatAwn,
      'emoji': '🌾',
      'color': Color(0xFFFFB300),
    },
    {
      'label': 'Ceará',
      'icon': FontAwesomeIcons.mapLocationDot,
      'emoji': '📍',
      'color': Color(0xFF00ACC1),
    },
    {
      'label': 'Brasil',
      'icon': FontAwesomeIcons.flag,
      'emoji': '🇧🇷',
      'color': Color(0xFF43A047),
    },
    {
      'label': 'Mundo',
      'icon': FontAwesomeIcons.earthAmericas,
      'emoji': '🌎',
      'color': Color(0xFF5C6BC0),
    },
    {
      'label': 'Esportes',
      'icon': FontAwesomeIcons.futbol,
      'emoji': '⚽',
      'color': Color(0xFF26C6DA),
    },
    {
      'label': 'Saúde',
      'icon': FontAwesomeIcons.heartPulse,
      'emoji': '❤️',
      'color': Color(0xFFEF5350),
    },
    {
      'label': 'Entretenimento',
      'icon': FontAwesomeIcons.film,
      'emoji': '🎬',
      'color': Color(0xFFAB47BC),
    },
  ];

  String? _selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selected == cat['label'];

          return _ModernChip(
            label: cat['label'] as String,
            icon: cat['icon'] as IconData,
            accentColor: cat['color'] as Color,
            isSelected: isSelected,
            delay: index * 40,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() =>
                  _selected = isSelected ? null : cat['label'] as String);
              Navigator.pushNamed(
                context,
                AppRoutes.category,
                arguments: cat['label'],
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CHIP MODERNO — visual premium por categoria
// ═══════════════════════════════════════════════════════════════════
class _ModernChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final int delay;
  final VoidCallback onTap;

  const _ModernChip({
    Key? key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.delay,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_ModernChip> createState() => _ModernChipState();
}

class _ModernChipState extends State<_ModernChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity =
        Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSelected
        ? widget.accentColor
        : const Color(0xFF888888);

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              // Fundo: selecionado = cor da categoria, não selecionado = dark
              color: widget.isSelected
                  ? widget.accentColor.withOpacity(0.15)
                  : _pressed
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFF111111),
              border: Border.all(
                color: widget.isSelected
                    ? widget.accentColor.withOpacity(0.7)
                    : _pressed
                        ? const Color(0xFF333333)
                        : const Color(0xFF1E1E1E),
                width: widget.isSelected ? 1.5 : 1,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Ícone com fundo circular colorido ──────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isSelected
                        ? widget.accentColor.withOpacity(0.25)
                        : const Color(0xFF1A1A1A),
                    border: Border.all(
                      color: widget.isSelected
                          ? widget.accentColor.withOpacity(0.5)
                          : const Color(0xFF2A2A2A),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: FaIcon(
                      widget.icon,
                      size: 9,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                // ── Label ──────────────────────────────────────────
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    color: widget.isSelected
                        ? widget.accentColor
                        : const Color(0xFF777777),
                    fontSize: 12,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    letterSpacing: widget.isSelected ? 0.3 : 0,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
