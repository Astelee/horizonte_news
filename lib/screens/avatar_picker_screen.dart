// lib/screens/avatar_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/avatar_catalog.dart';
import '../providers/user_xp_provider.dart';
import '../widgets/app_avatar.dart';

class AvatarPickerScreen extends StatefulWidget {
  const AvatarPickerScreen({Key? key}) : super(key: key);

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late String _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: AvatarCategory.values.length, vsync: this);

    final current =
        context.read<UserXpProvider>().data.avatarId;
    _selectedId = current;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final success =
        await context.read<UserXpProvider>().updateAvatar(_selectedId);

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o avatar. Tente novamente.'),
          backgroundColor: Color(0xFF2A0000),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userLevel = context.watch<UserXpProvider>().data.level;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: const Text(
          'Escolher Avatar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: const Color(0xFFFF6B00),
          labelColor: const Color(0xFFFF6B00),
          unselectedLabelColor: const Color(0xFF666666),
          labelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          tabs: AvatarCategory.values
              .map((c) => Tab(
                    icon: Icon(c.tabIcon, size: 16),
                    text: c.label.toUpperCase(),
                  ))
              .toList(),
        ),
      ),
      body: Column(
        children: [
          // ── Preview do avatar selecionado ────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F0F),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1A1A1A)),
              ),
            ),
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey(_selectedId),
                  tween: Tween(begin: 0.7, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  builder: (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: AppAvatar(
                    avatarId: _selectedId,
                    size: 96,
                    showBorder: true,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AvatarCatalog.byId(_selectedId).rarity.label.toUpperCase(),
                  style: TextStyle(
                    color: AvatarCatalog.byId(_selectedId).rarity.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Grade de avatares por categoria ──────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: AvatarCategory.values.map((category) {
                final avatares = AvatarCatalog.byCategory(category);
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: avatares.length,
                  itemBuilder: (context, i) => _AvatarTile(
                    avatar: avatares[i],
                    isSelected: avatares[i].id == _selectedId,
                    isUnlocked: avatares[i].isUnlockedFor(userLevel),
                    index: i,
                    onTap: () {
                      if (!avatares[i].isUnlockedFor(userLevel)) {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Desbloqueia no nível ${avatares[i].requiredLevel}'),
                            backgroundColor: const Color(0xFF1A1A1A),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      HapticFeedback.selectionClick();
                      setState(() => _selectedId = avatares[i].id);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Botão Salvar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: GestureDetector(
              onTap: _salvar,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SALVAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE INDIVIDUAL DO AVATAR
// ═══════════════════════════════════════════════════════════════════
class _AvatarTile extends StatefulWidget {
  final AvatarData avatar;
  final bool isSelected;
  final bool isUnlocked;
  final int index;
  final VoidCallback onTap;

  const _AvatarTile({
    required this.avatar,
    required this.isSelected,
    required this.isUnlocked,
    required this.index,
    required this.onTap,
  });

  @override
  State<_AvatarTile> createState() => _AvatarTileState();
}

class _AvatarTileState extends State<_AvatarTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.8, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    Future.delayed(Duration(milliseconds: 15 * (widget.index % 12)), () {
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
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFFFF6B00)
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withOpacity(0.5),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: widget.isUnlocked ? 1.0 : 0.35,
                  child: AppAvatar(
                    avatarId: widget.avatar.id,
                    size: 56,
                  ),
                ),
                if (!widget.isUnlocked)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF000000),
                      ),
                      child: const Icon(Icons.lock_rounded,
                          size: 10, color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
