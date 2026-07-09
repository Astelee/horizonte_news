import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  late String _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedId = context.read<UserXpProvider>().data.avatarId;
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
        SnackBar(
          content: const Text('Não foi possível salvar. Tente novamente.'),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userLevel = context.watch<UserXpProvider>().data.level;
    final selecionado = AvatarCatalog.byId(_selectedId);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── AppBar customizada ──────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 12,
              left: 8,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF080808),
              border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Escolha um Avatar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // balanceia o botão de fechar
              ],
            ),
          ),

          // ── Preview do avatar selecionado ───────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF080808),
              border: const Border(
                  bottom: BorderSide(color: Color(0xFF1A1A1A))),
              boxShadow: [
                BoxShadow(
                  color: selecionado.rarity.accentColor.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                // Glow atrás do avatar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: selecionado.rarity.accentColor
                            .withOpacity(0.45),
                        blurRadius: 36,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_selectedId),
                    tween: Tween(begin: 0.7, end: 1.0),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.elasticOut,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: AppAvatar(
                      avatarId: _selectedId,
                      size: 110,
                      showBorder: true,
                      borderColor: selecionado.rarity.accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Badge de raridade
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(_selectedId),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: selecionado.rarity.badgeBg,
                      border: Border.all(
                          color: selecionado.rarity.accentColor
                              .withOpacity(0.5)),
                    ),
                    child: Text(
                      selecionado.rarity.label.toUpperCase(),
                      style: TextStyle(
                        color: selecionado.rarity.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista de avatares por seção de raridade ─────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              children: AvatarRarity.values.map((rarity) {
                final lista = AvatarCatalog.byRarity(rarity);
                return _SecaoRaridade(
                  rarity: rarity,
                  avatares: lista,
                  selectedId: _selectedId,
                  userLevel: userLevel,
                  onSelect: (id) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedId = id);
                  },
                );
              }).toList(),
            ),
          ),

          // ── Botão Salvar ─────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: Color(0xFF080808),
              border:
                  Border(top: BorderSide(color: Color(0xFF1A1A1A))),
            ),
            child: GestureDetector(
              onTap: _salvar,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withOpacity(0.4),
                      blurRadius: 20,
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
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'SALVAR AVATAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
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
}

// ═══════════════════════════════════════════════════════════════════
// SEÇÃO POR RARIDADE
// ═══════════════════════════════════════════════════════════════════
class _SecaoRaridade extends StatelessWidget {
  final AvatarRarity rarity;
  final List<AvatarData> avatares;
  final String selectedId;
  final int userLevel;
  final ValueChanged<String> onSelect;

  const _SecaoRaridade({
    required this.rarity,
    required this.avatares,
    required this.selectedId,
    required this.userLevel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da seção
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rarity.accentColor,
                  boxShadow: [
                    BoxShadow(
                        color: rarity.accentColor.withOpacity(0.6),
                        blurRadius: 8)
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rarity.label.toUpperCase(),
                style: TextStyle(
                  color: rarity.accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        rarity.accentColor.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              if (rarity != AvatarRarity.comum) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: rarity.badgeBg,
                    border: Border.all(
                        color: rarity.accentColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    'Nv. ${avatares.first.requiredLevel}+',
                    style: TextStyle(
                      color: rarity.accentColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Grid de avatares
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: avatares.length,
          itemBuilder: (context, i) {
            final avatar = avatares[i];
            final desbloqueado = avatar.isUnlockedFor(userLevel);
            final selecionado = avatar.id == selectedId;

            return _AvatarTile(
              avatar: avatar,
              isSelected: selecionado,
              isUnlocked: desbloqueado,
              index: i,
              onTap: () {
                if (!desbloqueado) {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.lock_rounded,
                              color: rarity.accentColor, size: 16),
                          const SizedBox(width: 10),
                          Text(
                            'Desbloqueia no nível ${avatar.requiredLevel}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF1A1A1A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                onSelect(avatar.id);
              },
            );
          },
        ),
        const SizedBox(height: 28),
      ],
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
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    Future.delayed(
        Duration(milliseconds: 20 * (widget.index % 8)),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rarity = widget.avatar.rarity;

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
                    ? rarity.accentColor
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: rarity.accentColor.withOpacity(0.6),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Avatar com opacidade reduzida se bloqueado
                Opacity(
                  opacity: widget.isUnlocked ? 1.0 : 0.3,
                  child: AppAvatar(
                    avatarId: widget.avatar.id,
                    size: 64,
                    showBorder: false,
                  ),
                ),

                // Cadeado se bloqueado
                if (!widget.isUnlocked)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.lock_rounded,
                        size: 22,
                        color: rarity.accentColor.withOpacity(0.8),
                      ),
                    ),
                  ),

                // Checkmark se selecionado
                if (widget.isSelected && widget.isUnlocked)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rarity.accentColor,
                        border: Border.all(
                            color: Colors.black, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 12, color: Colors.white),
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
