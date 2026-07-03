// amigos_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/badge_config.dart';
import '../widgets/avatar_frame.dart';
import '../widgets/app_avatar.dart';
import 'amigos_modelos.dart';
import 'amigos_perfil.dart';
import 'chat_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// AVATAR DO AMIGO COM PULSE ANIMADO
// ═══════════════════════════════════════════════════════════════════
class AmigoAvatar extends StatefulWidget {
  final FriendModel friend;
  final double size;

  const AmigoAvatar({Key? key, required this.friend, this.size = 50})
      : super(key: key);

  @override
  State<AmigoAvatar> createState() => _AmigoAvatarState();
}

class _AmigoAvatarState extends State<AmigoAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.friend.status == FriendStatus.online) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AmigoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.friend.status == FriendStatus.online) {
      if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final frameEdgeInset = s * 0.28;
    final borderColor = widget.friend.isFavorite
        ? const Color(0xFFFAA61A)
        : widget.friend.status.color;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AvatarFrame(
          level: widget.friend.level,
          size: s,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: AppAvatar(
              avatarId: widget.friend.avatarId,
              size: s - 4,
            ),
          ),
        ),
        // Indicador de status
        Positioned(
          right: frameEdgeInset,
          bottom: frameEdgeInset,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.friend.status == FriendStatus.online)
                    Container(
                      width: 16 * _pulseAnim.value,
                      height: 16 * _pulseAnim.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.friend.status.color.withOpacity(0.3),
                      ),
                    ),
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.friend.status.color,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: widget.friend.status == FriendStatus.offline
                        ? null
                        : Center(
                            child: Icon(
                              widget.friend.status.icon,
                              size: 6,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BADGE DE NÍVEL
// ═══════════════════════════════════════════════════════════════════
class NivelBadge extends StatelessWidget {
  final int level;
  const NivelBadge({Key? key, required this.level}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cor = BadgeConfig.levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: cor.withOpacity(0.12),
        border: Border.all(color: cor.withOpacity(0.4)),
      ),
      child: Text(
        'Nv.$level',
        style: TextStyle(
          color: cor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BARRA DE XP
// ═══════════════════════════════════════════════════════════════════
class BarraXp extends StatelessWidget {
  final FriendModel friend;
  const BarraXp({Key? key, required this.friend}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cor = friend.isFavorite
        ? const Color(0xFFFAA61A)
        : const Color(0xFFFF6B00);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${friend.totalXp} XP',
                style:
                    const TextStyle(color: Color(0xFF444444), fontSize: 9)),
            const Expanded(child: SizedBox()),
            Text('${friend.xpForNextLevel} XP',
                style:
                    const TextStyle(color: Color(0xFF444444), fontSize: 9)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: friend.xpProgress,
            backgroundColor: const Color(0xFF1A1A1A),
            valueColor: AlwaysStoppedAnimation<Color>(cor),
            minHeight: 3,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FILA DE BADGES DE CONQUISTAS
// ═══════════════════════════════════════════════════════════════════
class FileiraBadges extends StatelessWidget {
  final List<String> achievementIds;
  final int maxVisible;

  const FileiraBadges({
    Key? key,
    required this.achievementIds,
    this.maxVisible = 3,
  }) : super(key: key);

  static const _rarityOrder = [
    'first_login', '1h_online', 'first_comment', 'first_share',
    '100_articles', '10h_online', 'level_5', 'level_10',
  ];

  List<String> get _topByRarity {
    final sorted = List<String>.from(achievementIds);
    sorted.sort((a, b) {
      final ra = _rarityOrder.indexOf(a);
      final rb = _rarityOrder.indexOf(b);
      return (rb == -1 ? 0 : rb).compareTo(ra == -1 ? 0 : ra);
    });
    return sorted.take(maxVisible).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ids = _topByRarity;
    if (ids.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ids.map((id) {
        final color = BadgeConfig.achievementColor(id);
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Tooltip(
            message: id,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.4), width: 0.8),
              ),
              child: Center(
                child: FaIcon(
                  BadgeConfig.achievementIcon(id),
                  size: 8,
                  color: color,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// INDICADOR DE DIGITANDO
// ═══════════════════════════════════════════════════════════════════
class IndicadorDigitando extends StatefulWidget {
  const IndicadorDigitando({Key? key}) : super(key: key);

  @override
  State<IndicadorDigitando> createState() => _IndicadorDigitandoState();
}

class _IndicadorDigitandoState extends State<IndicadorDigitando>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'digitando',
          style: TextStyle(
            color: const Color(0xFF43B581).withOpacity(0.8),
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 4),
        ...List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
              final opacity =
                  (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
              return Container(
                margin: const EdgeInsets.only(right: 2),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF43B581).withOpacity(opacity),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CABEÇALHO DE SEÇÃO
// ═══════════════════════════════════════════════════════════════════
class CabecalhoSecao extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int count;

  const CabecalhoSecao({
    Key? key,
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Expanded(child: SizedBox()),
          Container(
            height: 1,
            width: 60,
            color: color.withOpacity(0.12),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MENU DE CONTEXTO DO AMIGO
// ═══════════════════════════════════════════════════════════════════
class MenuContextoAmigo extends StatelessWidget {
  final FriendModel friend;
  final String myUid;
  final FirebaseFirestore db;
  final String chatId;
  final VoidCallback? onChanged;

  const MenuContextoAmigo({
    Key? key,
    required this.friend,
    required this.myUid,
    required this.db,
    required this.chatId,
    this.onChanged,
  }) : super(key: key);

  String get _chatIdResolvido {
    if (chatId.isNotEmpty) return chatId;
    final ids = [myUid, friend.uid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<String?> _buscarRequestId() async {
    final snap = await db
        .collection('friend_requests')
        .where('participants', arrayContains: myUid)
        .get();
    for (final doc in snap.docs) {
      final d = doc.data();
      final parts = List<String>.from(d['participants'] ?? []);
      if (parts.contains(friend.uid)) return doc.id;
    }
    return null;
  }

  Future<void> _alternarFavorito(BuildContext context) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    rootNav.pop();
    HapticFeedback.lightImpact();
    try {
      final snap = await db
          .collection('users_xp')
          .doc(friend.uid)
          .get();
      final atual = (snap.data()?['isFavorite'] as bool?) ?? false;
      await db.collection('users_xp').doc(friend.uid).update({
        'isFavorite': !atual,
      });
    } catch (_) {}
  }

  Future<void> _excluirConversa(BuildContext context) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    final rootContext = rootNav.context;
    rootNav.pop();
    await Future.delayed(const Duration(milliseconds: 150));

    final confirma = await showDialog<bool>(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0C0C0C),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Excluir conversa?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'O histórico será apagado apenas para você.',
          style: TextStyle(color: Color(0xFF666666), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF999999))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir',
                style: TextStyle(
                    color: Color(0xFFED4245),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirma != true) return;

    await db.collection('chats').doc(_chatIdResolvido).set({
      'hiddenFor': FieldValue.arrayUnion([myUid]),
      'unreadCount_$myUid': 0,
    }, SetOptions(merge: true));

    HapticFeedback.mediumImpact();
    onChanged?.call();
  }

  Future<void> _excluirAmigo(BuildContext context) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    final rootContext = rootNav.context;
    rootNav.pop();
    await Future.delayed(const Duration(milliseconds: 150));

    final idEncontrado = await _buscarRequestId();
    if (idEncontrado == null) return;

    final confirma = await showDialog<bool>(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0C0C0C),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Remover amigo?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'Tem certeza que quer remover @${friend.username}?\nAs conversas serão mantidas.',
          style: const TextStyle(
              color: Color(0xFF666666), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover',
                style: TextStyle(
                    color: Color(0xFFED4245),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirma != true) return;

    await db.collection('friend_requests').doc(idEncontrado).delete();
    HapticFeedback.mediumImpact();
    onChanged?.call();
  }

  Future<void> _verPerfil(BuildContext context) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    rootNav.pop();
    await Future.delayed(const Duration(milliseconds: 200));
    rootNav.push(
      MaterialPageRoute(
        builder: (_) => TelaPerfilAmigo(friend: friend),
      ),
    );
  }

  Future<void> _compartilharPerfil(BuildContext context) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    rootNav.pop();
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    if (rootNav.context.mounted) {
      ScaffoldMessenger.of(rootNav.context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.share_rounded,
                  color: Color(0xFFFF6B00), size: 16),
              const SizedBox(width: 10),
              Text(
                'Perfil de @${friend.username} copiado!',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF111111),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Mini perfil
          Row(
            children: [
              AmigoAvatar(friend: friend, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            friend.displayName.isNotEmpty
                                ? friend.displayName
                                : friend.username,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (friend.achievements.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          FileiraBadges(
                              achievementIds: friend.achievements),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '@${friend.username}',
                          style: TextStyle(
                            color:
                                const Color(0xFFFF6B00).withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: friend.status.color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          friend.status.label,
                          style: TextStyle(
                            color: friend.status.color,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF1A1A1A), height: 1),
          const SizedBox(height: 16),

          // Itens do menu
          _ItemMenu(
            icon: Icons.person_rounded,
            label: 'Ver Perfil',
            color: Colors.white,
            onTap: () => _verPerfil(context),
          ),
          const SizedBox(height: 8),
          _ItemMenu(
            icon: Icons.chat_bubble_rounded,
            label: 'Conversar',
            color: const Color(0xFFFF6B00),
            onTap: () {
              final rootNav =
                  Navigator.of(context, rootNavigator: true);
              rootNav.pop();
              rootNav.push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(friend: friend),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _ItemMenu(
            icon: friend.isFavorite
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            label: friend.isFavorite
                ? 'Remover dos Favoritos'
                : 'Adicionar aos Favoritos',
            color: const Color(0xFFFAA61A),
            onTap: () => _alternarFavorito(context),
          ),
          const SizedBox(height: 8),
          _ItemMenu(
            icon: Icons.share_rounded,
            label: 'Compartilhar Perfil',
            color: const Color(0xFF4FC3F7),
            onTap: () => _compartilharPerfil(context),
          ),
          const SizedBox(height: 8),
          _ItemMenu(
            icon: Icons.delete_outline_rounded,
            label: 'Excluir Conversa',
            color: const Color(0xFF747F8D),
            onTap: () => _excluirConversa(context),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1A1A1A), height: 1),
          const SizedBox(height: 12),
          _ItemMenu(
            icon: Icons.person_remove_rounded,
            label: 'Remover Amigo',
            color: const Color(0xFFED4245),
            onTap: () => _excluirAmigo(context),
          ),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withOpacity(0.08),
        highlightColor: color.withOpacity(0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Expanded(child: SizedBox()),
              Icon(Icons.chevron_right_rounded,
                  color: color.withOpacity(0.3), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ESTADOS VAZIOS
// ═══════════════════════════════════════════════════════════════════
class EstadoCarregando extends StatefulWidget {
  const EstadoCarregando({Key? key}) : super(key: key);

  @override
  State<EstadoCarregando> createState() => _EstadoCarregandoState();
}

class _EstadoCarregandoState extends State<EstadoCarregando>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          itemCount: 5,
          itemBuilder: (_, i) => _SkeletonCard(opacity: _anim.value),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double opacity;
  const _SkeletonCard({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(opacity * 0.08),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity * 0.6,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(opacity * 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(opacity * 0.05),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(opacity * 0.04),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity * 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }
}

class EstadoVazio extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final Widget? botao;

  const EstadoVazio({
    Key? key,
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    this.botao,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6B00).withOpacity(0.06),
                border: Border.all(
                    color: const Color(0xFFFF6B00).withOpacity(0.12)),
              ),
              child: Icon(icon,
                  size: 34, color: const Color(0xFFFF6B00).withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (botao != null) ...[
              const SizedBox(height: 24),
              botao!,
            ],
          ],
        ),
      ),
    );
  }
}

class EstadoSemAmigos extends StatelessWidget {
  const EstadoSemAmigos({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const EstadoVazio(
      icon: Icons.people_outline_rounded,
      titulo: 'Nenhum amigo ainda',
      subtitulo: 'Adicione amigos pelo botão\n+ AMIGOS abaixo',
    );
  }
}
