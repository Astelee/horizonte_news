import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/premium_config.dart';
import '../providers/user_xp_provider.dart';
import '../features/admin/providers/admin_provider.dart';
import '../services/app_notification_service.dart';
import 'badge_widgets.dart';
import 'avatar_frame.dart';
import 'app_avatar.dart';
import 'subscriber_badge.dart';
import '../services/app_config_service.dart';

class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String? username;
  final String text;
  final DateTime createdAt;
  final int userLevel;
  final List<String> userAchievements;
  final String userAvatarId;
  final String? userPhotoUrl;
  final String? userEquippedPremiumAvatarId;
  final int likesCount;
  final int repliesCount;
  final String? replyToUsername;
  final bool edited;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.username,
    required this.text,
    required this.createdAt,
    this.userLevel = 1,
    this.userAchievements = const [],
    this.userAvatarId = 'animais_01',
    this.userPhotoUrl,
    this.userEquippedPremiumAvatarId,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.replyToUsername,
    this.edited = false,
  });

  factory CommentModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anônimo',
      username: data['username'] as String?,
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userLevel: (data['userLevel'] as num?)?.toInt() ?? 1,
      userAchievements: List<String>.from(data['userAchievements'] ?? []),
      userAvatarId: (data['userAvatarId'] as String?) ?? 'animais_01',
      userPhotoUrl: data['userPhotoUrl'] as String?,
      userEquippedPremiumAvatarId:
          data['userEquippedPremiumAvatarId'] as String?,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      repliesCount: (data['repliesCount'] as num?)?.toInt() ?? 0,
      replyToUsername: data['replyToUsername'] as String?,
      edited: data['edited'] as bool? ?? false,
    );
  }
}

/// Dados do autor de um comentário já resolvidos — ou os "ao vivo"
/// vindos do perfil atual (users_xp/{uid}), ou o fallback congelado
/// salvo no próprio comentário quando o perfil ainda não carregou ou
/// não existe mais (conta excluída, por exemplo). Ver _LiveAuthorData.
class LiveAuthorInfo {
  final int level;
  final List<String> achievements;
  final String? photoUrl;
  final String? equippedPremiumAvatarId;
  final String? equippedCheckinRewardId;
  final bool isPremium;

  const LiveAuthorInfo({
    required this.level,
    required this.achievements,
    required this.photoUrl,
    required this.equippedPremiumAvatarId,
    this.equippedCheckinRewardId,
    this.isPremium = false,
  });
}

/// Busca ao vivo o nível/título/cor/conquistas/foto/avatar premium
/// ATUAIS do autor de um comentário, em vez do snapshot congelado que
/// foi salvo no documento do comentário no momento do envio — assim
/// um comentário antigo passa a refletir o nível/foto de agora, não o
/// de quando foi escrito.
///
/// Recebe a stream já pronta (authorStream) em vez de montá-la
/// sozinho, porque quem chama (CommentsSectionState) mantém um cache
/// de UMA stream por userId compartilhada entre todos os tiles
/// daquele autor — evita abrir dezenas de listeners idênticos numa
/// notícia com muitos comentários da mesma pessoa.
class _LiveAuthorData extends StatelessWidget {
  final Stream<DocumentSnapshot> authorStream;
  final CommentModel fallback;
  final Widget Function(BuildContext context, LiveAuthorInfo info) builder;

  const _LiveAuthorData({
    required this.authorStream,
    required this.fallback,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: authorStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        // Sem dados ainda (carregando) ou perfil não existe mais:
        // cai no snapshot congelado do próprio comentário, que
        // continua sendo um valor razoável para não deixar a linha
        // do comentário em branco por um instante ou para sempre
        // (conta excluída).
        final info = data == null
            ? LiveAuthorInfo(
                level: fallback.userLevel,
                achievements: fallback.userAchievements,
                photoUrl: fallback.userPhotoUrl,
                equippedPremiumAvatarId:
                    fallback.userEquippedPremiumAvatarId,
                // Sem doc carregado ainda: recompensa de check-in não
                // é congelada no comentário, então fica ausente até o
                // stream trazer o dado real (melhor não mostrar por
                // um instante do que mostrar errado — mesmo critério
                // já usado para isPremium abaixo).
                equippedCheckinRewardId: null,
                // Sem doc carregado ainda: não há como saber se é
                // assinante a partir do comentário (esse dado nunca
                // foi congelado nele), então não exibe o selo até o
                // stream trazer o dado real — melhor não mostrar por
                // um instante do que mostrar errado.
                isPremium: false,
              )
            : LiveAuthorInfo(
                level: (data['level'] as num?)?.toInt() ??
                    fallback.userLevel,
                achievements: (data['achievements'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    fallback.userAchievements,
                photoUrl:
                    (data['photoUrl'] as String?) ?? fallback.userPhotoUrl,
                equippedPremiumAvatarId:
                    (data['equippedPremiumAvatarId'] as String?) ??
                        fallback.userEquippedPremiumAvatarId,
                equippedCheckinRewardId:
                    data['equippedCheckinRewardId'] as String?,
                isPremium: PremiumTierX.fromId(
                        data['premiumTier'] as String?)
                    .isPremium,
              );
        return builder(context, info);
      },
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// BOTTOM SHEET — PERFIL DO COMENTARISTA
// ═══════════════════════════════════════════════════════════════════
class _CommentUserProfileSheet extends StatefulWidget {
  final String userId;
  final String userName;
  final int userLevel;
  final List<String> userAchievements;

  const _CommentUserProfileSheet({
    Key? key,
    required this.userId,
    required this.userName,
    required this.userLevel,
    required this.userAchievements,
  }) : super(key: key);

  @override
  State<_CommentUserProfileSheet> createState() =>
      _CommentUserProfileSheetState();
}

class _CommentUserProfileSheetState extends State<_CommentUserProfileSheet> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  Map<String, dynamic>? _userData;

  String get _myUid => _auth.currentUser?.uid ?? '';
  bool get _isMe => widget.userId == _myUid;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _db.collection('users_xp').doc(widget.userId).get();
      if (doc.exists && mounted) {
        setState(() => _userData = doc.data());
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    final hasHadBirthdayThisYear = (today.month > birthDate.month) ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hasHadBirthdayThisYear) age--;
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final username = (_userData?['username'] as String?) ?? '';
    final totalXp = (_userData?['totalXp'] as num?)?.toInt() ?? 0;
    final photoUrl = _userData?['photoUrl'] as String?;
    final equippedPremiumAvatarId =
        _userData?['equippedPremiumAvatarId'] as String?;
    final equippedCheckinRewardId =
        _userData?['equippedCheckinRewardId'] as String?;
    final showAge = _userData?['showAge'] as bool? ?? false;
    final birthDate = (_userData?['birthDate'] as Timestamp?)?.toDate();
    final age = (showAge && birthDate != null) ? _calculateAge(birthDate) : null;
    // Nível e conquistas ATUAIS (não mais o snapshot congelado salvo
    // no comentário no momento em que foi escrito, ver
    // widget.userLevel/userAchievements): _userData já é buscado ao
    // vivo de users_xp/{uid} (ver _loadUserData), então lemos os
    // mesmos campos que o resto do perfil usa. Enquanto ainda está
    // carregando (ou se o perfil não existir mais), cai no valor que
    // veio junto com o comentário, para a folha não abrir em branco.
    final level =
        (_userData?['level'] as num?)?.toInt() ?? widget.userLevel;
    final achievements = (_userData?['achievements'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        widget.userAchievements;
    final isPremium =
        PremiumTierX.fromId(_userData?['premiumTier'] as String?).isPremium;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF080808),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF1A1A1A)),
          left: BorderSide(color: Color(0xFF111111)),
          right: BorderSide(color: Color(0xFF111111)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
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

          // Avatar com moldura + info
          Row(
            children: [
              AvatarFrame(
                level: level,
                size: 60,
                child: UserAvatarDisplay(
                  name: widget.userName,
                  seed: widget.userId,
                  photoUrl: photoUrl,
                  equippedPremiumAvatarId: equippedPremiumAvatarId,
                  equippedCheckinRewardId: equippedCheckinRewardId,
                  size: 60,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.userName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        // Selo de assinante: primeiro badge logo após
                        // o nome, igual à tela de perfil.
                        if (isPremium) ...[
                          const SizedBox(width: 6),
                          const SubscriberBadge(size: 16),
                        ],
                      ],
                    ),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: TextStyle(
                          color: AppColors.primaryOrange.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (age != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$age anos',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        LevelBadgeInline(level: level),
                        const SizedBox(width: 6),
                        FrameRarityTag(level: level, fontSize: 8),
                        if (totalXp > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '$totalXp XP',
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Conquistas
          if (achievements.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: UnlockedBadgesRow(
                unlockedAchievements: achievements,
                maxVisible: achievements.length,
                badgeSize: 13,
              ),
            ),
          ],

          const SizedBox(height: 20),

          if (_isMe)
            _InfoBanner(
              icon: Icons.person_rounded,
              text: 'Este é o seu perfil',
              color: AppColors.primaryOrange,
            )
          else if (_loading)
            const SizedBox(
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SEÇÃO PRINCIPAL DE COMENTÁRIOS
// ═══════════════════════════════════════════════════════════════════

class CommentsSection extends StatefulWidget {
  final String postId;
  final String postTitle;

  /// Quando vindos de uma notificação de resposta/curtida (ver
  /// PostDetailArgs), abrem a seção de comentários já expandida e
  /// destacam o comentário/resposta correspondente.
  final String? highlightCommentId;
  final String? highlightReplyId;

  /// Chamado toda vez que a seção abre/fecha (usuário tocando em
  /// "Comentários (N)", ou abertura automática vinda de notificação).
  /// PostDetailScreen usa isso para saber quando desenhar/esconder a
  /// barra fixa no rodapé da tela — sem esse aviso, o pai não tem
  /// como saber que `expanded` mudou, já que é só um getter.
  final ValueChanged<bool>? onExpandedChanged;

  const CommentsSection({
    Key? key,
    required this.postId,
    required this.postTitle,
    this.highlightCommentId,
    this.highlightReplyId,
    this.onExpandedChanged,
  }) : super(key: key);

  @override
  State<CommentsSection> createState() => CommentsSectionState();
}

/// Estado público (não `_CommentsSectionState`) de propósito: a barra
/// de comentário/resposta agora é desenhada FORA desta árvore, presa
/// ao rodapé da TELA (ver PostDetailScreen), não mais dentro do
/// CustomScrollView do artigo — é assim que o Instagram funciona: a
/// barra nunca rola junto com o conteúdo, fica sempre ancorada.
/// PostDetailScreen guarda um GlobalKey<CommentsSectionState> e chama
/// `buildFixedInputBar()` para pedir o widget da barra pronto, além
/// de observar `expanded`/`inputBarVisible` para saber se e quando
/// desenhar esse Positioned externo.
class CommentsSectionState extends State<CommentsSection>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  bool _xpAwarded = false;
  bool _expanded = false;
  late AnimationController _sendAnim;
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  /// True quando a seção de comentários está expandida — é o sinal
  /// que PostDetailScreen usa para saber se deve desenhar a barra
  /// fixa no rodapé da tela ou escondê-la por completo (comentários
  /// fechados = nenhuma barra, igual ao Instagram).
  bool get expanded => _expanded;

  /// Exposto para PostDetailScreen conseguir ouvir foco/desfoco do
  /// campo de comentário/resposta e recalcular o padding inferior da
  /// barra fixa (ver buildFixedInputBar) sempre que ele mudar — um
  /// setState daqui de dentro não alcança o Positioned que vive numa
  /// subtree irmã em PostDetailScreen, então quem precisa reagir a
  /// esse FocusNode escuta-o diretamente com um ListenableBuilder.
  FocusNode get inputFocusNode => _focusNode;

  // ── Estado de "respondendo a" ──────────────────────────────────────
  // Quando != null, o próximo envio vira uma resposta (subcoleção
  // "replies") do comentário-pai, igual ao fluxo do Instagram: tocar
  // em "Responder" já preenche o campo com @usernameDoAutor.
  String? _replyToCommentId;
  String? _replyToUsername;
  String? _replyToUserId;

  bool get _isReplying => _replyToCommentId != null;

  // ── Edição de comentário ───────────────────────────────────────────
  // Quando != null, identifica o comentário/resposta cujo texto está
  // sendo editado no momento — controla qual _CommentTile/_ReplyTile
  // troca o texto normal pelo campo de edição inline.
  String? _editingCommentId;
  String? _editingParentCommentId; // != null quando é uma resposta

  // ── Destaque vindo de notificação (ver highlightCommentId/ReplyId) ──
  String? _highlightedCommentId;
  String? _highlightedReplyId;

  // ── Dados "ao vivo" do autor de cada comentário/resposta ─────────
  // Antes, nível, título, cor, conquistas, foto e avatar premium
  // equipado exibidos num comentário vinham de um SNAPSHOT gravado no
  // documento do comentário no momento do envio (ver _sendComment) —
  // um comentário antigo continuava mostrando o nível/foto de quando
  // foi escrito, mesmo que o autor tivesse subido de nível ou trocado
  // de foto depois. Agora usamos os dados atuais do perfil
  // (users_xp/{uid}), buscados ao vivo.
  //
  // Para não abrir um listener do Firestore por comentário (uma
  // notícia com 50 comentários da mesma pessoa não deveria abrir 50
  // streams idênticas), este cache guarda UMA stream por userId único,
  // compartilhada entre todos os tiles que mostram aquele autor — veja
  // _liveAuthorStream, usada pelo widget _LiveAuthorData.
  final Map<String, Stream<DocumentSnapshot>> _authorStreamCache = {};

  Stream<DocumentSnapshot> _liveAuthorStream(String userId) {
    return _authorStreamCache.putIfAbsent(
      userId,
      () => FirebaseFirestore.instance
          .collection('users_xp')
          .doc(userId)
          .snapshots(),
    );
  }

  // ── Streams de comentários, criadas UMA VEZ ──────────────────────
  // Antes, `_commentsRef.orderBy(...).snapshots()` era chamado direto
  // dentro do build() de _buildCommentsList/_buildToggleButton. Isso
  // parece inofensivo, mas cria uma NOVA instância de Stream a cada
  // rebuild do widget pai — e todo setState() local (editar, abrir
  // reply, destacar notificação etc.) dispara um desses rebuilds.
  // O StreamBuilder, ao receber uma Stream diferente (mesmo que
  // logicamente idêntica), cancela a subscription antiga e recomeça
  // do zero em ConnectionState.waiting, reconstruindo toda a lista de
  // comentários do zero — o que resetava qualquer estado local que
  // dependesse do rebuild anterior (como o modo de edição recém-
  // ativado) quase instantaneamente. Guardar as Streams em campos,
  // criadas apenas no initState, resolve isso: o StreamBuilder passa
  // a reconectar na MESMA subscription entre rebuilds.
  //
  // São duas streams separadas (não uma reaproveitada): a lista
  // renderizada sempre teve limit(50) — carregar só os 50 comentários
  // mais recentes é intencional para não pesar a tela. Mas o
  // contador do topo ("Comentários (X)") precisa somar TODOS os
  // comentários-raiz + respostas, exato, mesmo que existam mais de
  // 50 — senão o contador subcontaria threads antigas que a lista
  // nem carrega. Por isso o contador usa a query SEM limite.
  late final Stream<QuerySnapshot> _commentsStream =
      _commentsRef.orderBy('createdAt', descending: true).snapshots();
  late final Stream<QuerySnapshot> _commentsListStream = _commentsRef
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _sendAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnim =
        CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic);

    // Diferente de antes, não é mais preciso rolar a tela ao focar o
    // campo: a barra agora é desenhada FORA do CustomScrollView do
    // artigo, presa ao rodapé da TELA (ver buildFixedInputBar() e
    // PostDetailScreen, que a posiciona com Positioned(bottom: 0)
    // dentro do body já redimensionado pelo teclado) — ela já nasce
    // sempre visível, acima do teclado, sem depender de nenhum scroll
    // reativo. Quem precisa reagir a foco/desfoco do campo (o padding
    // inferior calculado em buildFixedInputBar) escuta inputFocusNode
    // diretamente — ver o ListenableBuilder em PostDetailScreen.

    // Se a tela foi aberta a partir de uma notificação de resposta/
    // curtida, já abre os comentários expandidos e guarda o alvo a
    // destacar — o scroll até ele acontece assim que a lista
    // renderizar o item (cada _CommentTile/_ReplyTile tem sua
    // própria GlobalKey e chama Scrollable.ensureVisible sozinho).
    if (widget.highlightCommentId != null) {
      _highlightedCommentId = widget.highlightCommentId;
      _highlightedReplyId = widget.highlightReplyId;
      _expanded = true;
      _expandCtrl.value = 1.0;
      // Avisa o pai depois do primeiro frame (nunca dentro do
      // initState/build em si) de que já nasceu expandido, para ele
      // desenhar a barra fixa desde já — sem isso, quem chegou aqui
      // via notificação só veria a barra aparecer depois de tocar
      // manualmente em "Comentários".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onExpandedChanged?.call(true);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _sendAnim.dispose();
    _expandCtrl.dispose();
    super.dispose();
  }

  CollectionReference get _commentsRef => FirebaseFirestore.instance
      .collection('comments')
      .doc(widget.postId)
      .collection('postComments');

  CollectionReference _repliesRef(String parentCommentId) =>
      _commentsRef.doc(parentCommentId).collection('replies');

  void _startReply({
    required String commentId,
    required String userId,
    required String? username,
    required String userName,
  }) {
    HapticFeedback.selectionClick();
    final handle = (username != null && username.trim().isNotEmpty)
        ? username
        : userName;
    setState(() {
      _replyToCommentId = commentId;
      _replyToUserId = userId;
      _replyToUsername = handle;
      // Não inserimos "@handle" no texto do campo: o banner
      // "Respondendo a @handle" já indica isso visualmente, e o
      // valor é salvo à parte em replyToUsername. Se colocássemos
      // o "@handle" no próprio texto, ele seria salvo dentro de
      // `text` e o app mostraria a menção duas vezes (uma vinda do
      // texto, outra do replyToUsername exibido em destaque).
      _controller.clear();
    });
    if (!_expanded) _toggleExpanded();
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUserId = null;
      _replyToUsername = null;
      _controller.clear();
    });
  }

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandCtrl.forward();
    } else {
      _expandCtrl.reverse();
      // Fechar a seção com o teclado aberto (usuário estava digitando
      // e tocou em "Comentários (N)" de novo para recolher) precisa
      // também tirar o foco do campo — senão a barra fixa some da
      // árvore (ver PostDetailScreen, que só a desenha enquanto
      // expanded) mas o teclado continua aberto sem nada acima dele.
      _focusNode.unfocus();
    }
    widget.onExpandedChanged?.call(_expanded);
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _sendComment() async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _controller.text.trim();

    if (user == null) {
      _showLoginSnack();
      return;
    }

    final config = await AppConfigService().fetch();
    if (!config.commentsEnabled) {
      _showSnack('Os comentários estão temporariamente desativados.');
      return;
    }

    final suspension = await FirebaseFirestore.instance
        .collection('suspensions')
        .doc(user.uid)
        .get();

    if (suspension.exists) {
      final data = suspension.data()!;
      final until = (data['until'] as Timestamp?)?.toDate();
      final isPermanent = until == null;
      final isActive = isPermanent || DateTime.now().isBefore(until!);

      if (isActive) {
        final reason = (data['reason'] as String?)?.trim() ?? '';
        final reasonText = reason.isNotEmpty ? '\nMotivo: $reason' : '';
        if (isPermanent) {
          _showSnack('Você foi banido permanentemente.$reasonText');
        } else {
          final fmt = '${until.day}/${until.month}/${until.year}';
          _showSnack('Você está suspenso até $fmt.$reasonText');
        }
        setState(() => _isSending = false);
        return;
      }
    }

    if (text.isEmpty) return;
    if (text.length < 3) {
      _showSnack('Comentário muito curto.');
      return;
    }

    setState(() => _isSending = true);
    _sendAnim.reverse().then((_) => _sendAnim.forward());

    final replyingToCommentId = _replyToCommentId;
    final replyingToUsername = _replyToUsername;

    try {
      final userName =
          user.displayName ?? user.email?.split('@').first ?? 'Leitor';
      final xpProvider = Provider.of<UserXpProvider>(context, listen: false);
      final userLevel = xpProvider.data.level;
      final userAchievements = xpProvider.data.achievements;
      final userAvatarId = xpProvider.data.avatarId;
      final userPhotoUrl = xpProvider.data.photoUrl;
      final userEquippedPremiumAvatarId =
          xpProvider.data.equippedPremiumAvatarId;
      final username = xpProvider.data.username;

      final payload = {
        'userId': user.uid,
        'userName': userName,
        'username': username,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'userLevel': userLevel,
        'userAchievements': userAchievements,
        'userAvatarId': userAvatarId,
        'userPhotoUrl': userPhotoUrl,
        'userEquippedPremiumAvatarId': userEquippedPremiumAvatarId,
        'likesCount': 0,
      };

      if (replyingToCommentId != null) {
        final replyDoc = await _repliesRef(replyingToCommentId).add({
          ...payload,
          'replyToUsername': replyingToUsername,
        });
        await _commentsRef
            .doc(replyingToCommentId)
            .update({'repliesCount': FieldValue.increment(1)});

        // Notifica o autor do comentário-pai (a resposta pode ser a
        // uma resposta de outra pessoa dentro da mesma thread — o
        // destinatário é sempre quem escreveu o item ao qual esta
        // resposta está diretamente ligada, ou seja, _replyToUserId,
        // que _startReply já preenche corretamente tanto para
        // "Responder" no comentário raiz quanto numa resposta).
        final recipientUserId = _replyToUserId;
        if (recipientUserId != null && recipientUserId != user.uid) {
          unawaited(AppNotificationService.notifyCommentReply(
            recipientUserId: recipientUserId,
            actorUserId: user.uid,
            actorUserName: username?.trim().isNotEmpty == true
                ? username!
                : userName,
            actorPhotoUrl: userPhotoUrl,
            postId: widget.postId,
            postTitle: widget.postTitle,
            commentId: replyingToCommentId,
            replyId: replyDoc.id,
            previewText: text,
          ));
        }
      } else {
        await _commentsRef.add({
          ...payload,
          'repliesCount': 0,
        });
      }

      _controller.clear();
      _focusNode.unfocus();
      if (_isReplying) {
        setState(() {
          _replyToCommentId = null;
          _replyToUserId = null;
          _replyToUsername = null;
        });
      }

      if (!_xpAwarded && mounted) {
        await xpProvider.addXpForComment();
        _xpAwarded = true;
        _showXpSnack();
      }
    } catch (e) {
      _showSnack('Erro ao enviar comentário. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _commentsRef.doc(commentId).delete();
    } catch (e) {
      if (mounted) _showSnack('Erro ao excluir: $e');
    }
  }

  /// Atualiza o texto de um comentário/resposta já existente (edição
  /// própria — a regra do Firestore garante que só o dono ou um admin
  /// pode chegar até aqui, ver validCommentTextEdit). Marca `edited:
  /// true` e grava `editedAt` para o "(editado)" na UI. Preserva tudo
  /// mais do documento (id, likesCount, repliesCount, respostas,
  /// curtidas) porque é um update pontual de dois campos, nunca uma
  /// recriação do documento.
  Future<void> _editComment({
    required String commentId,
    required String newText,
    String? parentCommentId,
  }) async {
    final text = newText.trim();
    if (text.isEmpty || text.length < 3) {
      _showSnack('Comentário muito curto.');
      return;
    }
    try {
      final ref = parentCommentId != null
          ? _repliesRef(parentCommentId).doc(commentId)
          : _commentsRef.doc(commentId);
      await ref.update({
        'text': text,
        'edited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _editingCommentId = null;
          _editingParentCommentId = null;
        });
      }
    } catch (e) {
      if (mounted) _showSnack('Erro ao salvar edição: $e');
    }
  }

  void _startEditing({
    required String commentId,
    String? parentCommentId,
  }) {
    HapticFeedback.selectionClick();
    setState(() {
      _editingCommentId = commentId;
      _editingParentCommentId = parentCommentId;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingCommentId = null;
      _editingParentCommentId = null;
    });
  }

  Future<void> _deleteReply({
    required String parentCommentId,
    required String replyId,
  }) async {
    try {
      await _repliesRef(parentCommentId).doc(replyId).delete();
      await _commentsRef
          .doc(parentCommentId)
          .update({'repliesCount': FieldValue.increment(-1)});
    } catch (e) {
      if (mounted) _showSnack('Erro ao excluir: $e');
    }
  }

  Future<void> _toggleLike({
    required String commentId,
    required String authorUid,
    required bool alreadyLiked,
    String? parentCommentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginSnack();
      return;
    }
    final xpProvider = Provider.of<UserXpProvider>(context, listen: false);
    if (alreadyLiked) {
      await xpProvider.unlikeComment(
        postId: widget.postId,
        commentId: commentId,
        likerUid: user.uid,
        parentCommentId: parentCommentId,
      );
      // Descurtir nunca gera notificação — só o ato de curtir
      // notifica o autor (ver notifyCommentLike para a lógica de
      // dedupe quando a pessoa curte/descurte/curte de novo).
      return;
    }

    final liked = await xpProvider.likeComment(
      postId: widget.postId,
      commentId: commentId,
      authorUid: authorUid,
      parentCommentId: parentCommentId,
    );
    if (!liked) return; // já estava curtido, ou falhou — sem notificar

    final actorName =
        user.displayName ?? user.email?.split('@').first ?? 'Leitor';
    final actorPhotoUrl =
        Provider.of<UserXpProvider>(context, listen: false).data.photoUrl;
    unawaited(AppNotificationService.notifyCommentLike(
      recipientUserId: authorUid,
      actorUserId: user.uid,
      actorUserName: actorName,
      actorPhotoUrl: actorPhotoUrl,
      postId: widget.postId,
      postTitle: widget.postTitle,
      commentId: parentCommentId ?? commentId,
      replyId: parentCommentId != null ? commentId : null,
    ));
  }

  void _openUserProfile(CommentModel comment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommentUserProfileSheet(
        userId: comment.userId,
        userName: comment.userName,
        userLevel: comment.userLevel,
        userAchievements: comment.userAchievements,
      ),
    );
  }

  void _showLoginSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.lock_outline_rounded, color: Colors.white, size: 16),
          SizedBox(width: 10),
          Text('Faça login para comentar.',
              style: TextStyle(color: Colors.white)),
        ]),
        backgroundColor: AppColors.backgroundElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.backgroundElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showXpSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.star_rounded, color: AppColors.primaryOrange, size: 18),
          SizedBox(width: 10),
          Text('+XP por comentar!',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: const Color(0xFF1A0800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToggleButton(),
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1.0,
          child: FadeTransition(
            opacity: _expandAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildCommentsList(),
                // Respiro no fim da lista para a última linha não
                // ficar colada/escondida atrás da barra fixa que
                // PostDetailScreen desenha por cima do rodapé (ver
                // buildFixedInputBar) — a barra não faz mais parte
                // deste scroll, então precisa desse espaço reservado
                // manualmente aqui.
                const SizedBox(height: 88),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Botão único que abre/fecha os comentários ────────────────────
  // O contador precisa somar comentários-raiz + TODAS as respostas
  // (repliesCount de cada comentário), não só docs.length da
  // coleção postComments — do contrário um comentário com respostas
  // aparece como "1" mesmo tendo, por exemplo, 3 respostas.
  // repliesCount já é mantido corretamente em tempo real (ver
  // _sendComment/_deleteReply, que fazem FieldValue.increment(±1) a
  // cada resposta criada/excluída), então basta somar esse campo em
  // cada comentário-raiz — sem precisar de uma segunda query nas
  // subcoleções replies/*.
  Widget _buildToggleButton() {
    return StreamBuilder<QuerySnapshot>(
      stream: _commentsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final int rootCount = docs.length;
        final int repliesTotal = docs.fold<int>(0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + ((data['repliesCount'] as num?)?.toInt() ?? 0);
        });
        final count = rootCount + repliesTotal;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF0A0A0A),
                border: Border.all(
                  color: AppColors.primaryOrange
                      .withOpacity(_expanded ? 0.45 : 0.2),
                ),
                boxShadow: _expanded
                    ? [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.12),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 17, color: AppColors.primaryOrange),
                  const SizedBox(width: 10),
                  Text(
                    count > 0 ? 'Comentários ($count)' : 'Comentar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryOrange.withOpacity(0.8),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyingBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.reply_rounded,
              size: 14, color: AppColors.primaryOrange.withOpacity(0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Respondendo a @${_replyToUsername ?? ''}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primaryOrange.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: const Icon(Icons.close_rounded,
                size: 16, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Constrói a barra de comentário/resposta pronta para ser
  /// desenhada FORA desta árvore, fixa ao rodapé da tela — chamado
  /// por PostDetailScreen dentro de um Positioned(bottom: 0) no Stack
  /// do body. O Scaffold já tem resizeToAvoidBottomInset: true, então
  /// o próprio body (e este Stack dentro dele) encolhe sozinho para
  /// caber acima do teclado — não precisamos somar
  /// MediaQuery.viewInsets.bottom manualmente em lugar nenhum aqui;
  /// isso é exatamente como o Instagram ancora a barra de comentário:
  /// ela nunca rola junto com o artigo, e sobe junto com o teclado
  /// porque a área em que ela vive já subiu.
  ///
  /// PostDetailScreen só deve chamar isso enquanto `expanded` for
  /// true (comentários abertos) — com comentários fechados não há
  /// barra nenhuma, igual ao Instagram. Inclui o próprio fundo/
  /// borda/safe-area do rodapé, então quem chama não precisa embrulhar
  /// em mais nenhum Container.
  Widget buildFixedInputBar(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    // Não dá para usar MediaQuery.viewInsets.bottom > 0 aqui como
    // sinal de "teclado aberto": com resizeToAvoidBottomInset: true,
    // o body (e este widget, que vive dentro dele) já foi encolhido
    // para caber acima do teclado, então nesse ponto da árvore
    // viewInsets.bottom já está zerado — usar isso aqui sempre daria
    // "fechado". O sinal confiável é o próprio foco do campo: com o
    // teclado provavelmente aberto (campo focado), a barra já está
    // colada nele, então não precisa do respiro extra da safe area;
    // sem foco, a barra está no rodapé "de repouso" da tela e precisa
    // desse respiro para não ficar colada no gesture bar do aparelho.
    final keyboardLikelyOpen = _focusNode.hasFocus;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        border: Border(
          top: BorderSide(color: AppColors.primaryOrange.withOpacity(0.15)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: keyboardLikelyOpen ? 10 : 10 + bottomSafeArea,
        ),
        child: StreamBuilder<AppGlobalConfig>(
          stream: AppConfigService().stream(),
          builder: (context, snapshot) {
            final commentsEnabled = snapshot.data?.commentsEnabled ?? true;
            if (!commentsEnabled) {
              return _buildCommentsDisabledNotice();
            }
            return _buildInputArea(user);
          },
        ),
      ),
    );
  }

  /// Aviso mostrado no lugar do campo de comentar quando um admin
  /// desativa comentários pelas Configurações do painel. Os
  /// comentários já existentes continuam visíveis normalmente — só o
  /// envio de novos fica bloqueado.
  Widget _buildCommentsDisabledNotice() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Os comentários estão temporariamente desativados.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(User? user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0A0A0A),
          border: Border.all(color: AppColors.primaryOrange.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.05),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            if (_isReplying) _buildReplyingBanner(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 3,
                    minLines: 1,
                    maxLength: 500,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.5),
                    decoration: InputDecoration(
                      hintText: user != null
                          ? '💭 O que você achou desta notícia?'
                          : 'Faça login para comentar',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 14),
                      border: InputBorder.none,
                      counterStyle: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10),
                      contentPadding: EdgeInsets.zero,
                    ),
                    enabled: user != null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 13,
                        color: AppColors.primaryOrange.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    const Text(
                      'Ganhe XP ao comentar',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                ScaleTransition(
                  scale: _sendAnim,
                  child: GestureDetector(
                    onTap: _isSending ? null : _sendComment,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient:
                            _isSending ? null : AppColors.orangeGradient,
                        color: _isSending
                            ? AppColors.backgroundElevated
                            : null,
                        boxShadow: _isSending
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.primaryOrange
                                      .withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryOrange),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.send_rounded,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'ENVIAR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputAvatar() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Consumer<UserXpProvider>(
      builder: (context, xpProvider, _) {
        return AvatarFrame(
          level: xpProvider.data.level,
          size: 36,
          child: UserAvatarDisplay(
            name: currentUser?.displayName ??
                currentUser?.email?.split('@').first ??
                'Leitor',
            seed: currentUser?.uid,
            photoUrl: xpProvider.data.photoUrl,
            equippedPremiumAvatarId: xpProvider.data.equippedPremiumAvatarId,
            equippedCheckinRewardId: xpProvider.data.equippedCheckinRewardId,
            size: 36,
          ),
        );
      },
    );
  }

  Widget _buildCommentsList() {
    final isAdmin =
        Provider.of<AdminProvider>(context, listen: false).isAdmin;

    return StreamBuilder<QuerySnapshot>(
      stream: _commentsListStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryOrange),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // Comentários ocultos pela moderação (campo `hidden`, gravado
        // pelo painel ADM em AdminCommentService.hideComment) só ficam
        // visíveis para admin. O filtro é feito aqui no cliente, e não
        // com where('hidden', isNotEqualTo: true) na query, porque
        // comentários antigos não têm o campo `hidden` e seriam
        // excluídos do resultado pelo Firestore.
        final comments = snapshot.data!.docs
            .where((doc) =>
                isAdmin ||
                (doc.data() as Map<String, dynamic>)['hidden'] != true)
            .map((doc) => CommentModel.fromDoc(doc))
            .toList();

        // Se veio de uma notificação apontando para um comentário que
        // não está mais entre os 50 mais recentes carregados (thread
        // antiga), não há como destacar — evita ficar tentando rolar
        // para um item que nunca vai aparecer na lista.
        final highlightStillVisible = _highlightedCommentId == null ||
            comments.any((c) => c.id == _highlightedCommentId);
        if (!highlightStillVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _highlightedCommentId = null;
                _highlightedReplyId = null;
              });
            }
          });
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          itemCount: comments.length,
          itemBuilder: (context, index) => _CommentTile(
            postId: widget.postId,
            comment: comments[index],
            authorStream: _liveAuthorStream(comments[index].userId),
            authorStreamFor: _liveAuthorStream,
            timeAgo: _timeAgo(comments[index].createdAt),
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
            isAdmin: isAdmin,
            onDelete: () => _deleteComment(comments[index].id),
            onDeleteReply: (replyId) => _deleteReply(
              parentCommentId: comments[index].id,
              replyId: replyId,
            ),
            onTapUser: () => _openUserProfile(comments[index]),
            onReply: () => _startReply(
              commentId: comments[index].id,
              userId: comments[index].userId,
              username: comments[index].username,
              userName: comments[index].userName,
            ),
            onReplyToTarget: ({
              required commentId,
              required userId,
              required username,
              required userName,
            }) =>
                _startReply(
              commentId: commentId,
              userId: userId,
              username: username,
              userName: userName,
            ),
            onToggleLike: ({
              required commentId,
              required authorUid,
              required alreadyLiked,
              parentCommentId,
            }) =>
                _toggleLike(
              commentId: commentId,
              authorUid: authorUid,
              alreadyLiked: alreadyLiked,
              parentCommentId: parentCommentId,
            ),
            isEditing: _editingCommentId == comments[index].id &&
                _editingParentCommentId == null,
            editingReplyId: _editingParentCommentId == comments[index].id
                ? _editingCommentId
                : null,
            onStartEdit: () => _startEditing(commentId: comments[index].id),
            onStartEditReply: (replyId) => _startEditing(
              commentId: replyId,
              parentCommentId: comments[index].id,
            ),
            onCancelEdit: _cancelEditing,
            onSaveEdit: (newText) => _editComment(
              commentId: comments[index].id,
              newText: newText,
            ),
            onSaveEditReply: (replyId, newText) => _editComment(
              commentId: replyId,
              newText: newText,
              parentCommentId: comments[index].id,
            ),
            isHighlighted: _highlightedCommentId == comments[index].id &&
                _highlightedReplyId == null,
            highlightedReplyId: _highlightedCommentId == comments[index].id
                ? _highlightedReplyId
                : null,
            autoExpandReplies: _highlightedCommentId == comments[index].id,
            onHighlightShown: () {
              if (_highlightedCommentId == comments[index].id) {
                setState(() {
                  _highlightedCommentId = null;
                  _highlightedReplyId = null;
                });
              }
            },
            repliesRef: _repliesRef(comments[index].id),
            timeAgoBuilder: _timeAgo,
          ),
        );
      },
    );
  }
}

typedef LikeToggleCallback = Future<void> Function({
  required String commentId,
  required String authorUid,
  required bool alreadyLiked,
  String? parentCommentId,
});

typedef ReplyTargetCallback = void Function({
  required String commentId,
  required String userId,
  required String? username,
  required String userName,
});

// ═══════════════════════════════════════════════════════════════════
// COMMENT TILE
// ═══════════════════════════════════════════════════════════════════
class _CommentTile extends StatefulWidget {
  final String postId;
  final CommentModel comment;
  final Stream<DocumentSnapshot> authorStream;
  /// Repassada para _RepliesList — cada resposta busca sua própria
  /// stream ao vivo (cacheada por userId) sob demanda com isso.
  final Stream<DocumentSnapshot> Function(String userId) authorStreamFor;
  final String timeAgo;
  final String currentUserId;
  final bool isAdmin;
  final VoidCallback onDelete;
  final ValueChanged<String> onDeleteReply;
  final VoidCallback onTapUser;
  final VoidCallback onReply;
  final ReplyTargetCallback onReplyToTarget;
  final LikeToggleCallback onToggleLike;
  final CollectionReference repliesRef;
  final String Function(DateTime) timeAgoBuilder;

  // ── Edição ──────────────────────────────────────────────────────
  final bool isEditing;
  final String? editingReplyId;
  final VoidCallback onStartEdit;
  final ValueChanged<String> onStartEditReply;
  final VoidCallback onCancelEdit;
  final ValueChanged<String> onSaveEdit;
  final void Function(String replyId, String newText) onSaveEditReply;

  // ── Destaque vindo de notificação ──────────────────────────────
  final bool isHighlighted;
  final String? highlightedReplyId;
  final bool autoExpandReplies;
  final VoidCallback onHighlightShown;

  const _CommentTile({
    Key? key,
    required this.postId,
    required this.comment,
    required this.authorStream,
    required this.authorStreamFor,
    required this.timeAgo,
    required this.currentUserId,
    required this.isAdmin,
    required this.onDelete,
    required this.onDeleteReply,
    required this.onTapUser,
    required this.onReply,
    required this.onReplyToTarget,
    required this.onToggleLike,
    required this.repliesRef,
    required this.timeAgoBuilder,
    required this.isEditing,
    required this.editingReplyId,
    required this.onStartEdit,
    required this.onStartEditReply,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onSaveEditReply,
    required this.isHighlighted,
    required this.highlightedReplyId,
    required this.autoExpandReplies,
    required this.onHighlightShown,
  }) : super(key: key);

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  bool _repliesExpanded = false;
  final GlobalKey _tileKey = GlobalKey();

  // Mesma correção aplicada em CommentsSectionState: a stream de
  // respostas precisa ser criada UMA VEZ (aqui, no initState), nunca
  // dentro do build() de _RepliesList (que é StatelessWidget e por
  // isso não tem onde guardar esse cache sozinho) — senão qualquer
  // setState local neste tile (como ativar o modo de edição de uma
  // resposta) recriava a Stream a cada rebuild, o StreamBuilder
  // cancelava a subscription antiga e reconstruía as respostas do
  // zero em ConnectionState.waiting, resetando o modo de edição quase
  // instantaneamente.
  late final Stream<QuerySnapshot> _repliesStream = widget.repliesRef
      .orderBy('createdAt', descending: false)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();

    if (widget.autoExpandReplies) _repliesExpanded = true;
    if (widget.isHighlighted || widget.highlightedReplyId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIntoView());
    }
  }

  /// Rola a tela até este comentário ficar visível — usado quando a
  /// tela foi aberta a partir de uma notificação de resposta/curtida.
  /// Tenta em múltiplos instantes porque, no primeiro frame após
  /// abrir a notícia, o CustomScrollView pai ainda pode não ter o
  /// tamanho final (imagem de capa/HTML ainda carregando).
  void _scrollIntoView() {
    for (final delay in const [200, 500, 900]) {
      Future.delayed(Duration(milliseconds: delay), () {
        final ctx = _tileKey.currentContext;
        if (ctx == null || !mounted) return;
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.3,
        );
      });
    }
    // Some o destaque sozinho depois de dar tempo da pessoa ver —
    // evita que o comentário fique "aceso" para sempre na tela.
    Future.delayed(const Duration(seconds: 3), widget.onHighlightShown);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isOwner => widget.comment.userId == widget.currentUserId;
  bool get _canDelete => _isOwner || widget.isAdmin;

  void _confirmDelete(BuildContext context) {
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.2)),
        ),
        title: const Text('Excluir comentário?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          widget.isAdmin && !_isOwner
              ? 'Você está excluindo o comentário de ${widget.comment.userName} como administrador.'
              : 'Esta ação não pode ser desfeita.',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => rootNav.pop(),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              rootNav.pop();
              widget.onDelete();
            },
            child: const Text('Excluir',
                style: TextStyle(
                    color: AppColors.emergencyRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(LiveAuthorInfo info) {
    return GestureDetector(
      onTap: widget.onTapUser,
      child: AvatarFrame(
        level: info.level,
        size: 36,
        child: UserAvatarDisplay(
          name: widget.comment.userName,
          seed: widget.comment.userId,
          photoUrl: info.photoUrl,
          equippedPremiumAvatarId: info.equippedPremiumAvatarId,
          equippedCheckinRewardId: info.equippedCheckinRewardId,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    // Só mostra o menu (⋮) se há pelo menos uma ação disponível —
    // editar (só o dono) ou excluir (dono ou admin). Substitui o
    // ícone de lixeira solto por um menu, deixando espaço visual
    // para a nova opção "Editar" sem poluir a linha de metadados.
    if (!_isOwner && !_canDelete) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert_rounded,
          size: 16, color: AppColors.textMuted),
      color: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.15)),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          widget.onStartEdit();
        } else if (value == 'delete') {
          _confirmDelete(context);
        }
      },
      itemBuilder: (context) => [
        // Editar: só o próprio autor do comentário — nunca aparece
        // para admin em comentário de outra pessoa (edição alheia
        // continua proibida mesmo para admin, só exclusão é permitida).
        if (_isOwner)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.primaryOrange),
                SizedBox(width: 10),
                Text('Editar', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        if (_canDelete)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppColors.emergencyRed.withOpacity(0.9)),
                const SizedBox(width: 10),
                const Text('Excluir', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: AnimatedContainer(
          key: _tileKey,
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: widget.isHighlighted
                ? AppColors.primaryOrange.withOpacity(0.10)
                : const Color(0xFF0D0D0D),
            border: Border.all(
              color: widget.isHighlighted
                  ? AppColors.primaryOrange.withOpacity(0.7)
                  : _isOwner
                      ? AppColors.primaryOrange.withOpacity(0.25)
                      : AppColors.borderSubtle,
              width: widget.isHighlighted ? 1.4 : 1,
            ),
            boxShadow: widget.isHighlighted
                ? [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.18),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          // Avatar, moldura, nível e conquistas exibidos aqui vêm do
          // perfil ATUAL do autor (ver _LiveAuthorData), não mais do
          // snapshot congelado salvo no momento em que o comentário
          // foi enviado — um comentário antigo agora reflete o
          // nível/título/cor/foto de agora do autor, não os de
          // quando ele comentou.
          child: _LiveAuthorData(
            authorStream: widget.authorStream,
            fallback: widget.comment,
            builder: (context, info) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(info),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: GestureDetector(
                                    onTap: widget.onTapUser,
                                    child: Text(
                                      widget.comment.userName,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _isOwner
                                            ? AppColors.primaryOrange
                                            : Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        decoration:
                                            TextDecoration.underline,
                                        decorationColor: _isOwner
                                            ? AppColors.primaryOrange
                                                .withOpacity(0.4)
                                            : Colors.white
                                                .withOpacity(0.2),
                                        decorationStyle:
                                            TextDecorationStyle.dotted,
                                      ),
                                    ),
                                  ),
                                ),
                                // Selo de assinante: primeiro badge
                                // logo após o nome, antes até da tag
                                // "EU" e do nível.
                                if (info.isPremium) ...[
                                  const SizedBox(width: 5),
                                  SubscriberBadge(size: 13),
                                ],
                                if (_isOwner) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      color: AppColors.primaryOrange
                                          .withOpacity(0.15),
                                    ),
                                    child: const Text(
                                      'EU',
                                      style: TextStyle(
                                        color: AppColors.primaryOrange,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 5),
                                LevelBadgeInline(level: info.level),
                                if (info.achievements.isNotEmpty)
                                  UnlockedBadgesRow(
                                    unlockedAchievements:
                                        info.achievements,
                                    maxVisible: 3,
                                    badgeSize: 9,
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                widget.timeAgo,
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11),
                              ),
                              if (widget.comment.edited) ...[
                                const SizedBox(width: 5),
                                Text(
                                  '· editado',
                                  style: TextStyle(
                                    color: AppColors.textMuted
                                        .withOpacity(0.8),
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              _buildMenuButton(context),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (widget.isEditing)
                        _CommentEditField(
                          initialText: widget.comment.text,
                          onCancel: widget.onCancelEdit,
                          onSave: widget.onSaveEdit,
                        )
                      else
                        _CommentText(comment: widget.comment),
                      const SizedBox(height: 8),
                      _CommentActionsRow(
                        postId: widget.postId,
                        commentId: widget.comment.id,
                        authorUid: widget.comment.userId,
                        likesCount: widget.comment.likesCount,
                        currentUserId: widget.currentUserId,
                        onToggleLike: widget.onToggleLike,
                        onReply: widget.onReply,
                      ),
                      if (widget.comment.repliesCount > 0) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(() =>
                              _repliesExpanded = !_repliesExpanded),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 1,
                                color:
                                    AppColors.textMuted.withOpacity(0.4),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _repliesExpanded
                                    ? 'Ocultar respostas'
                                    : 'Ver ${widget.comment.repliesCount} ${widget.comment.repliesCount == 1 ? 'resposta' : 'respostas'}',
                                style: TextStyle(
                                  color: AppColors.primaryOrange
                                      .withOpacity(0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_repliesExpanded)
                        _RepliesList(
                          postId: widget.postId,
                          parentCommentId: widget.comment.id,
                          repliesStream: _repliesStream,
                          authorStreamFor: widget.authorStreamFor,
                          currentUserId: widget.currentUserId,
                          isAdmin: widget.isAdmin,
                          onDeleteReply: widget.onDeleteReply,
                          onToggleLike: widget.onToggleLike,
                          onReplyToReply: (reply) =>
                              widget.onReplyToTarget(
                            commentId: widget.comment.id,
                            userId: reply.userId,
                            username: reply.username,
                            userName: reply.userName,
                          ),
                          timeAgoBuilder: widget.timeAgoBuilder,
                          editingReplyId: widget.editingReplyId,
                          onStartEditReply: widget.onStartEditReply,
                          onCancelEdit: widget.onCancelEdit,
                          onSaveEditReply: widget.onSaveEditReply,
                          highlightedReplyId: widget.highlightedReplyId,
                          onHighlightShown: widget.onHighlightShown,
                        ),
                    ],
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

// ── Campo de edição inline (substitui _CommentText quando editando) ──
// Compartilhado entre comentário-raiz e resposta. Mantém visual
// coerente com o campo de novo comentário (mesma paleta laranja/
// preto), só que compacto o bastante para caber dentro do próprio
// card do comentário sendo editado.
class _CommentEditField extends StatefulWidget {
  final String initialText;
  final VoidCallback onCancel;
  final ValueChanged<String> onSave;

  const _CommentEditField({
    required this.initialText,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_CommentEditField> createState() => _CommentEditFieldState();
}

class _CommentEditFieldState extends State<_CommentEditField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);
  late final FocusNode _focusNode = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Foca automaticamente e já seleciona o texto todo, para a
    // pessoa poder simplesmente começar a digitar por cima se quiser
    // reescrever do zero (comportamento padrão de "editar" na maioria
    // dos apps).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    widget.onSave(text);
    // Não desligamos _saving aqui de propósito: o widget é
    // desmontado pelo pai assim que _editingCommentId volta a null
    // (onSaveEdit conclui e sai do modo de edição), então não há
    // necessidade de reverter o estado de um widget que já vai
    // sumir da árvore.
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF141414),
        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: 4,
            minLines: 1,
            maxLength: 500,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, height: 1.4),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              counterStyle:
                  TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : widget.onCancel,
                style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10)),
                child: const Text('Cancelar',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: _saving ? null : AppColors.orangeGradient,
                    color: _saving ? AppColors.backgroundElevated : null,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primaryOrange),
                        )
                      : const Text(
                          'Salvar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Texto do comentário, destacando "@fulano" no início se houver ──
class _CommentText extends StatelessWidget {
  final CommentModel comment;

  const _CommentText({required this.comment});

  @override
  Widget build(BuildContext context) {
    final mention = comment.replyToUsername;
    if (mention == null || mention.trim().isEmpty) {
      return Text(
        comment.text,
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 14,
          height: 1.5,
        ),
      );
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 14,
          height: 1.5,
        ),
        children: [
          TextSpan(
            text: '@$mention ',
            style: TextStyle(
              color: AppColors.primaryOrange.withOpacity(0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: comment.text),
        ],
      ),
    );
  }
}

// ── Linha de curtir/responder, compartilhada entre comentário e resposta ──
class _CommentActionsRow extends StatelessWidget {
  final String postId;
  final String commentId;
  final String authorUid;
  final int likesCount;
  final String currentUserId;
  final LikeToggleCallback onToggleLike;
  final VoidCallback onReply;
  final String? parentCommentId;

  const _CommentActionsRow({
    required this.postId,
    required this.commentId,
    required this.authorUid,
    required this.likesCount,
    required this.currentUserId,
    required this.onToggleLike,
    required this.onReply,
    this.parentCommentId,
  });

  DocumentReference get _likeDocRef {
    final base = FirebaseFirestore.instance
        .collection('comments')
        .doc(postId)
        .collection('postComments');
    final commentRef = parentCommentId != null
        ? base.doc(parentCommentId).collection('replies').doc(commentId)
        : base.doc(commentId);
    return commentRef.collection('likes').doc(currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (currentUserId.isEmpty)
          _LikeButton(
            liked: false,
            count: likesCount,
            onTap: () => onToggleLike(
              commentId: commentId,
              authorUid: authorUid,
              alreadyLiked: false,
              parentCommentId: parentCommentId,
            ),
          )
        else
          StreamBuilder<DocumentSnapshot>(
            stream: _likeDocRef.snapshots(),
            builder: (context, snapshot) {
              final liked = snapshot.data?.exists ?? false;
              return _LikeButton(
                liked: liked,
                count: likesCount,
                onTap: () => onToggleLike(
                  commentId: commentId,
                  authorUid: authorUid,
                  alreadyLiked: liked,
                  parentCommentId: parentCommentId,
                ),
              );
            },
          ),
        const SizedBox(width: 16),
        Builder(
          builder: (context) => GestureDetector(
            onTap: () {
              onReply();
              // Rola este botão "Responder" para uma posição visível
              // ANTES da barra fixa cobrir o rodapé — sem isso, se o
              // comentário/resposta tocado já estava perto do fim da
              // lista, ele pode ficar (parcial ou totalmente) atrás
              // da barra que acabou de aparecer, tornando o próprio
              // botão que o usuário tocou inacessível para um
              // segundo toque (ex.: cancelar e responder outro).
              // alignment: 0.3 deixa uma folga confortável acima do
              // botão, não cola ele na borda exata da área visível.
              Future.delayed(const Duration(milliseconds: 80), () {
                if (!context.mounted) return;
                Scrollable.ensureVisible(
                  context,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  alignment: 0.3,
                );
              });
            },
            child: const Text(
              'Responder',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LikeButton extends StatelessWidget {
  final bool liked;
  final int count;
  final VoidCallback onTap;

  const _LikeButton({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 15,
            color: liked ? AppColors.emergencyRed : AppColors.textMuted,
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: liked ? AppColors.emergencyRed : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Lista de respostas de um comentário (1 nível, estilo Instagram) ──
class _RepliesList extends StatelessWidget {
  final String postId;
  final String parentCommentId;
  final Stream<QuerySnapshot> repliesStream;
  final String currentUserId;
  final bool isAdmin;
  final ValueChanged<String> onDeleteReply;
  final LikeToggleCallback onToggleLike;
  final ValueChanged<CommentModel> onReplyToReply;
  final String Function(DateTime) timeAgoBuilder;

  /// Pede ao CommentsSectionState a stream (cacheada, compartilhada
  /// entre todos os tiles do mesmo autor) do perfil ao vivo de um
  /// userId — usada por cada _ReplyTile para nível/título/cor/foto
  /// atuais do autor da resposta.
  final Stream<DocumentSnapshot> Function(String userId) authorStreamFor;

  // ── Edição ──────────────────────────────────────────────────────
  final String? editingReplyId;
  final ValueChanged<String> onStartEditReply;
  final VoidCallback onCancelEdit;
  final void Function(String replyId, String newText) onSaveEditReply;

  // ── Destaque vindo de notificação ──────────────────────────────
  final String? highlightedReplyId;
  final VoidCallback onHighlightShown;

  const _RepliesList({
    required this.postId,
    required this.parentCommentId,
    required this.repliesStream,
    required this.currentUserId,
    required this.isAdmin,
    required this.onDeleteReply,
    required this.onToggleLike,
    required this.onReplyToReply,
    required this.timeAgoBuilder,
    required this.authorStreamFor,
    this.editingReplyId,
    required this.onStartEditReply,
    required this.onCancelEdit,
    required this.onSaveEditReply,
    this.highlightedReplyId,
    required this.onHighlightShown,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: repliesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primaryOrange),
            ),
          );
        }
        // Respostas ocultas pela moderação só aparecem para admin
        // (mesma regra da lista de comentários-raiz).
        final replies = snapshot.data!.docs
            .where((doc) =>
                isAdmin ||
                (doc.data() as Map<String, dynamic>)['hidden'] != true)
            .map((doc) => CommentModel.fromDoc(doc))
            .toList();

        return Padding(
          padding: const EdgeInsets.only(top: 10, left: 20),
          child: Column(
            children: replies
                .map((reply) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReplyTile(
                        postId: postId,
                        parentCommentId: parentCommentId,
                        reply: reply,
                        authorStream: authorStreamFor(reply.userId),
                        timeAgo: timeAgoBuilder(reply.createdAt),
                        currentUserId: currentUserId,
                        isAdmin: isAdmin,
                        onDelete: () => onDeleteReply(reply.id),
                        onReply: () => onReplyToReply(reply),
                        onToggleLike: onToggleLike,
                        isEditing: editingReplyId == reply.id,
                        onStartEdit: () => onStartEditReply(reply.id),
                        onCancelEdit: onCancelEdit,
                        onSaveEdit: (newText) =>
                            onSaveEditReply(reply.id, newText),
                        isHighlighted: highlightedReplyId == reply.id,
                        onHighlightShown: onHighlightShown,
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

// ── Tile de uma resposta individual — visual mais compacto ──────────
class _ReplyTile extends StatefulWidget {
  final String postId;
  final String parentCommentId;
  final CommentModel reply;
  final Stream<DocumentSnapshot> authorStream;
  final String timeAgo;
  final String currentUserId;
  final bool isAdmin;
  final VoidCallback onDelete;
  final VoidCallback onReply;
  final LikeToggleCallback onToggleLike;
  final bool isEditing;
  final VoidCallback onStartEdit;
  final VoidCallback onCancelEdit;
  final ValueChanged<String> onSaveEdit;
  final bool isHighlighted;
  final VoidCallback onHighlightShown;

  const _ReplyTile({
    required this.postId,
    required this.parentCommentId,
    required this.reply,
    required this.authorStream,
    required this.timeAgo,
    required this.currentUserId,
    required this.isAdmin,
    required this.onDelete,
    required this.onReply,
    required this.onToggleLike,
    required this.isEditing,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.isHighlighted,
    required this.onHighlightShown,
  });

  @override
  State<_ReplyTile> createState() => _ReplyTileState();
}

class _ReplyTileState extends State<_ReplyTile> {
  final GlobalKey _tileKey = GlobalKey();

  CommentModel get reply => widget.reply;
  String get currentUserId => widget.currentUserId;
  bool get isAdmin => widget.isAdmin;

  bool get _isOwner => reply.userId == currentUserId;
  bool get _canDelete => _isOwner || isAdmin;

  @override
  void initState() {
    super.initState();
    if (widget.isHighlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIntoView());
    }
  }

  void _scrollIntoView() {
    for (final delay in const [200, 500, 900]) {
      Future.delayed(Duration(milliseconds: delay), () {
        final ctx = _tileKey.currentContext;
        if (ctx == null || !mounted) return;
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.3,
        );
      });
    }
    Future.delayed(const Duration(seconds: 3), widget.onHighlightShown);
  }

  void _confirmDelete(BuildContext context) {
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.2)),
        ),
        title: const Text('Excluir resposta?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          isAdmin && !_isOwner
              ? 'Você está excluindo a resposta de ${reply.userName} como administrador.'
              : 'Esta ação não pode ser desfeita.',
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => rootNav.pop(),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              rootNav.pop();
              widget.onDelete();
            },
            child: const Text('Excluir',
                style: TextStyle(
                    color: AppColors.emergencyRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    if (!_isOwner && !_canDelete) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert_rounded,
          size: 13, color: AppColors.textMuted),
      color: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.15)),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          widget.onStartEdit();
        } else if (value == 'delete') {
          _confirmDelete(context);
        }
      },
      itemBuilder: (context) => [
        if (_isOwner)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.primaryOrange),
                SizedBox(width: 10),
                Text('Editar', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        if (_canDelete)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppColors.emergencyRed.withOpacity(0.9)),
                const SizedBox(width: 10),
                const Text('Excluir', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: _tileKey,
      duration: const Duration(milliseconds: 400),
      padding:
          widget.isHighlighted ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: widget.isHighlighted
            ? AppColors.primaryOrange.withOpacity(0.10)
            : Colors.transparent,
        border: widget.isHighlighted
            ? Border.all(color: AppColors.primaryOrange.withOpacity(0.6))
            : null,
      ),
      // Mesmo tratamento do _CommentTile: avatar, moldura e nível
      // aqui vêm do perfil ATUAL do autor da resposta (ver
      // _LiveAuthorData), não do snapshot congelado salvo quando a
      // resposta foi enviada.
      child: _LiveAuthorData(
        authorStream: widget.authorStream,
        fallback: reply,
        builder: (context, info) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarFrame(
              level: info.level,
              size: 28,
              child: UserAvatarDisplay(
                name: reply.userName,
                seed: reply.userId,
                photoUrl: info.photoUrl,
                equippedPremiumAvatarId: info.equippedPremiumAvatarId,
                equippedCheckinRewardId: info.equippedCheckinRewardId,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                reply.userName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _isOwner
                                      ? AppColors.primaryOrange
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // Selo de assinante: primeiro badge logo
                            // após o nome, antes do nível.
                            if (info.isPremium) ...[
                              const SizedBox(width: 5),
                              SubscriberBadge(size: 12),
                            ],
                            const SizedBox(width: 5),
                            LevelBadgeInline(level: info.level),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            widget.timeAgo,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 10),
                          ),
                          if (reply.edited) ...[
                            const SizedBox(width: 4),
                            Text(
                              '· editado',
                              style: TextStyle(
                                color:
                                    AppColors.textMuted.withOpacity(0.8),
                                fontSize: 9,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          _buildMenuButton(context),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (widget.isEditing)
                    _CommentEditField(
                      initialText: reply.text,
                      onCancel: widget.onCancelEdit,
                      onSave: widget.onSaveEdit,
                    )
                  else
                    _CommentText(comment: reply),
                  const SizedBox(height: 6),
                  _CommentActionsRow(
                    postId: widget.postId,
                    commentId: reply.id,
                    authorUid: reply.userId,
                    likesCount: reply.likesCount,
                    currentUserId: currentUserId,
                    onToggleLike: widget.onToggleLike,
                    onReply: widget.onReply,
                    parentCommentId: widget.parentCommentId,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}