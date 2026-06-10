import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class CategoryBar extends StatefulWidget {
  const CategoryBar({Key? key}) : super(key: key);

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<CategoryBar> {
  // ── Categorias com ícones Font Awesome profissionais ──────────────
  static const List<Map<String, dynamic>> _categories = [
    {'label': 'Horizonte',      'icon': FontAwesomeIcons.buildingColumns},
    {'label': 'Pacajus',        'icon': FontAwesomeIcons.locationDot},
    {'label': 'Itaitinga',      'icon': FontAwesomeIcons.locationDot},
    {'label': 'Chorozinho',     'icon': FontAwesomeIcons.locationDot},
    {'label': 'Ceará',          'icon': FontAwesomeIcons.mapLocationDot},
    {'label': 'Brasil',         'icon': FontAwesomeIcons.flag},
    {'label': 'Mundo',          'icon': FontAwesomeIcons.earthAmericas},
    {'label': 'Esportes',       'icon': FontAwesomeIcons.futbol},
    {'label': 'Saúde',          'icon': FontAwesomeIcons.heartPulse},
    {'label': 'Entretenimento', 'icon': FontAwesomeIcons.film},
  ];

  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selected == cat['label'];

          return _AnimatedChip(
            label: cat['label'] as String,
            icon: cat['icon'] as IconData,
            isSelected: isSelected,
            delay: index * 45,
            onTap: () {
              setState(() =>
                  _selected = isSelected ? null : cat['label']);
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

class _AnimatedChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final int delay;
  final VoidCallback onTap;

  const _AnimatedChip({
    Key? key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.delay,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_AnimatedChip> createState() => _AnimatedChipState();
}

class _AnimatedChipState extends State<_AnimatedChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _opacity;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _opacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _fadeCtrl.forward(); });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          padding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: widget.isSelected ? AppColors.orangeGradient : null,
            color: widget.isSelected
                ? null
                : _pressed
                    ? AppColors.primaryOrange.withOpacity(0.10)
                    : AppColors.backgroundElevated,
            border: Border.all(
              color: widget.isSelected
                  ? Colors.transparent
                  : _pressed
                      ? AppColors.primaryOrange.withOpacity(0.45)
                      : AppColors.borderDark,
              width: 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.38),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── FaIcon no lugar do Icon ──────────────────────────
              FaIcon(
                widget.icon,
                size: 11,
                color: widget.isSelected
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: widget.isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
