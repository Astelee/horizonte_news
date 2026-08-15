import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../services/sound_service.dart';

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
      'color': Color(0xFFFF6B00),
    },
    {
      'label': 'Pacajus',
      'icon': FontAwesomeIcons.tree,
      'color': Color(0xFF43A047),
    },
    {
      'label': 'Itaitinga',
      'icon': FontAwesomeIcons.water,
      'color': Color(0xFF1E88E5),
    },
    {
      'label': 'Chorozinho',
      'icon': FontAwesomeIcons.wheatAwn,
      'color': Color(0xFFFFB300),
    },
    {
      'label': 'Ceará',
      'icon': FontAwesomeIcons.mapLocationDot,
      'color': Color(0xFF00ACC1),
    },
    {
      'label': 'Brasil',
      'icon': FontAwesomeIcons.flag,
      'color': Color(0xFF43A047),
    },
    {
      'label': 'Mundo',
      'icon': FontAwesomeIcons.earthAmericas,
      'color': Color(0xFF5C6BC0),
    },
    {
      'label': 'Esportes',
      'icon': FontAwesomeIcons.futbol,
      'color': Color(0xFF26C6DA),
    },
    {
      'label': 'Saúde',
      'icon': FontAwesomeIcons.heartPulse,
      'color': Color(0xFFEF5350),
    },
    {
      'label': 'Entretenimento',
      'icon': FontAwesomeIcons.film,
      'color': Color(0xFFAB47BC),
    },
  ];

  String? _selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selected == cat['label'];

          return _CategoryChip(
            label: cat['label'] as String,
            icon: cat['icon'] as IconData,
            accentColor: cat['color'] as Color,
            isSelected: isSelected,
            entryDelay: index * 40,
            onTap: () {
              HapticFeedback.selectionClick();
              SoundService.instance.playSystemClick();
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

// ── Chip individual ───────────────────────────────────────────────────────────

class _CategoryChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final int entryDelay;
  final VoidCallback onTap;

  const _CategoryChip({
    Key? key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.entryDelay,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _selectCtrl;
  late Animation<double> _entryOpacity;
  late Animation<Offset> _entrySlide;
  late Animation<double> _selectGlow;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _entryOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.entryDelay), () {
      if (mounted) _entryCtrl.forward();
    });

    _selectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _selectGlow = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _selectCtrl, curve: Curves.easeInOut),
    );

    if (widget.isSelected) _selectCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_CategoryChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _selectCtrl.repeat(reverse: true);
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _selectCtrl.stop();
      _selectCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _selectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entryOpacity,
      child: SlideTransition(
        position: _entrySlide,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedBuilder(
            animation: _selectCtrl,
            builder: (_, child) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.isSelected
                    ? widget.accentColor.withOpacity(0.14)
                    : _pressed
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFF111111),
                border: Border.all(
                  color: widget.isSelected
                      ? widget.accentColor
                          .withOpacity(0.5 + _selectGlow.value * 0.35)
                      : _pressed
                          ? const Color(0xFF333333)
                          : const Color(0xFF1E1E1E),
                  width: widget.isSelected ? 1.5 : 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: widget.accentColor
                              .withOpacity(0.15 + _selectGlow.value * 0.20),
                          blurRadius: 12 + _selectGlow.value * 6,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isSelected
                        ? widget.accentColor.withOpacity(0.22)
                        : const Color(0xFF1A1A1A),
                    border: Border.all(
                      color: widget.isSelected
                          ? widget.accentColor.withOpacity(0.55)
                          : const Color(0xFF2A2A2A),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: FaIcon(
                      widget.icon,
                      size: 9,
                      color: widget.isSelected
                          ? widget.accentColor
                          : const Color(0xFF777777),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    color: widget.isSelected
                        ? widget.accentColor
                        : const Color(0xFF666666),
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
