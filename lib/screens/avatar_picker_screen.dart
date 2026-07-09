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

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── AppBar ──────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 12,
              left: 8,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF080808),
              border:
                  Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white),
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
                const SizedBox(width: 48),
              ],
            ),
          ),

          // ── Preview do avatar selecionado ───────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF080808),
              border: Border(
                  bottom: BorderSide(color: Color(0xFF1A1A1A))),
            ),
            child: Center(
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
                  borderColor: const Color(0xFFFF6B00),
                ),
              ),
            ),
          ),

          // ── Grade de avatares ───────────────────────────────────
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1,
              ),
              itemCount: AvatarCatalog.all.length,
              itemBuilder: (context, i) {
                final avatar = AvatarCatalog.all[i];
                final selecionado = avatar.id == _selectedId;

                return _AvatarTile(
                  avatar: avatar,
                  isSelected: selecionado,
                  index: i,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedId = avatar.id);
                  },
                );
              },
            ),
          ),

          // ── Botão Salvar ─────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: Color(0xFF080808),
              border:
                  Border(top: BorderSide(color: Color(0xFF1A1A1A))),
            ),
            child: GestureDetector(
              onTap: _salvar,
              child: Container(
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
// TILE INDIVIDUAL
// ═══════════════════════════════════════════════════════════════════
class _AvatarTile extends StatefulWidget {
  final AvatarData avatar;
  final bool isSelected;
  final int index;
  final VoidCallback onTap;

  const _AvatarTile({
    required this.avatar,
    required this.isSelected,
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
        vsync: this,
        duration: const Duration(milliseconds: 350));
    _fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    Future.delayed(
      Duration(milliseconds: 20 * (widget.index % 8)),
      () { if (mounted) _ctrl.forward(); },
    );
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
                        color: const Color(0xFFFF6B00).withOpacity(0.6),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AppAvatar(
                  avatarId: widget.avatar.id,
                  size: 64,
                  showBorder: false,
                ),
                // Checkmark se selecionado
                if (widget.isSelected)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF6B00),
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
