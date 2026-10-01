import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/initials_helper.dart';
import '../config/premium_avatars_config.dart';
import '../config/checkin_rewards_config.dart';
import 'premium_avatars.dart';
import 'checkin_reward_painters.dart';
import 'level_aura.dart';
import 'pet_painters.dart';
import '../config/pet_config.dart';

/// Avatar circular do app. Quando [photoUrl] é informado, exibe a foto
/// de perfil do usuário; caso contrário, gera as iniciais do nome em
/// tempo de execução — sem depender de imagens, emojis ou ícones de
/// pessoa. A cor de fundo das iniciais é determinística: o mesmo
/// [name] (ou [seed], quando informado) sempre resulta na mesma cor.
///
/// Único componente de avatar do app — reutilizado em perfil, ranking,
/// comentários e telas administrativas.
class AppAvatar extends StatelessWidget {
  /// Nome usado para gerar as iniciais exibidas no avatar.
  final String? name;

  /// Chave estável opcional para determinar a cor (ex.: UID do usuário).
  /// Quando ausente, a cor é determinada pelo próprio [name].
  final String? seed;

  /// URL da foto de perfil (Cloudinary). Quando presente e
  /// carregada com sucesso, substitui as iniciais.
  final String? photoUrl;

  final double size;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppAvatar({
    Key? key,
    required this.name,
    this.seed,
    this.photoUrl,
    this.size = 44,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  }) : super(key: key);

  // ── Paleta compatível com a identidade visual do Horizonte News:
  // tons escuros e variações de laranja, mantendo contraste suficiente
  // para o texto branco permanecer legível.
  static const List<Color> _palette = [
    Color(0xFFFF6B00), // laranja principal
    Color(0xFFCC4400), // laranja escuro
    Color(0xFFFF8C3A), // laranja claro
    Color(0xFF8A3B00), // marrom-laranja
    Color(0xFF2A2A2A), // grafite
    Color(0xFF3D3D3D), // cinza escuro
    Color(0xFF4A2A00), // âmbar escuro
    Color(0xFF662200), // ferrugem
  ];

  Color _colorFor(String key) {
    var hash = 0;
    for (final codeUnit in key.codeUnits) {
      hash = 0x1fffffff & (hash + codeUnit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    return _palette[hash % _palette.length];
  }

  Widget _initialsContent() {
    final key = (seed != null && seed!.trim().isNotEmpty)
        ? seed!.trim()
        : (name ?? '');
    final initials = InitialsHelper.getInitials(name);
    final bgColor = key.isEmpty ? const Color(0xFF2A2A2A) : _colorFor(key);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: showBorder
            ? Border.all(
                color: borderColor ?? const Color(0xFFFF6B00),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B00).withOpacity(0.2),
            blurRadius: size * 0.2,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    final content = hasPhoto
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: showBorder
                  ? Border.all(
                      color: borderColor ?? const Color(0xFFFF6B00),
                      width: 2,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B00).withOpacity(0.2),
                  blurRadius: size * 0.2,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              placeholder: (_, __) => _initialsContent(),
              errorWidget: (_, __, ___) => _initialsContent(),
            ),
          )
        : _initialsContent();

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

/// Decide o que mostrar dentro do círculo do avatar: se o usuário tem
/// um avatar animado premium equipado (equippedPremiumAvatarId), ele
/// tem prioridade máxima sobre foto e iniciais; caso contrário, cai
/// para o comportamento normal de [AppAvatar] (foto ou iniciais).
/// Independente disso, se houver uma recompensa de Check-in equipada
/// (equippedCheckinRewardId), ela é sobreposta como um selo no canto
/// inferior direito — é o mesmo campo lido em `checkin_screen.dart`,
/// aqui replicado para todo lugar que exibe o avatar do usuário
/// (perfil, ranking, comentários, respostas, configurações...).
///
/// Quando [level] é informado (> 0), o [LevelBadge] correspondente
/// flutua no canto superior esquerdo do avatar, 50% maior que o
/// tamanho original e deslocado PARA FORA da foto (ver
/// [levelBadgeScale] e [levelBadgeOutset]) — substituindo o antigo
/// AvatarFrame (moldura ao redor de todo o avatar). O avatar em si
/// (foto/iniciais/assinatura) nunca ganha borda ou efeito de nível;
/// o selo é um elemento independente, fechado e autocontido, que não
/// cobre mais o rosto.
///
/// Este é o único ponto de decisão dessa composição — usado como
/// substituto direto de AppAvatar (e do antigo
/// `AvatarFrame(child: AppAvatar(...))`) em todo lugar que exibe o
/// avatar de um usuário, preservando o mesmo tamanho e posição gerais.
class UserAvatarDisplay extends StatelessWidget {
  /// Tamanho mínimo (px) para a aura aparecer por padrão.
  static const double _minAuraSize = 28;

  final String? name;
  final String? seed;
  final String? photoUrl;

  /// Chave salva em equippedPremiumAvatarId (UserXpData). Quando nula
  /// ou desconhecida, o avatar animado é ignorado e o widget se
  /// comporta como um AppAvatar comum.
  final String? equippedPremiumAvatarId;

  /// Chave salva em equippedCheckinRewardId (UserXpData). Quando nula
  /// ou desconhecida, nenhum selo é desenhado no canto inferior
  /// direito.
  final String? equippedCheckinRewardId;

  /// Nível do usuário (UserXpData.level). Quando nulo ou <= 0, nenhum
  /// selo de nível é desenhado no canto superior esquerdo — usado
  /// pelas telas que ainda não têm esse dado à mão.
  final int? level;

  /// Pet equipado. Quando omitido, usa automaticamente o pet do nível
  /// atual como fallback.
  final String? equippedPetId;

  /// Reserva espaço extra e afasta o pet da aura no cabeçalho do perfil.
  /// O movimento em infinito é ativo também nos avatares compactos;
  /// esta opção controla apenas a reserva de espaço e o afastamento.
  final bool orbitPet;

  /// Multiplicador do tamanho do selo de nível. Padrão 1.5 = 50% maior
  /// que o tamanho original, em TODO o app (ranking, perfil,
  /// configurações, comentários, respostas e painel ADM).
  final double levelBadgeScale;

  /// Deslocamento do selo de nível para FORA do avatar, como fração do
  /// tamanho do selo. Padrão 0.75 = o selo sobe bem para o canto
  /// superior esquerdo, fora da foto e acima da aura, em vez de ficar
  /// por cima dela. Use 0 para o comportamento antigo (selo colado
  /// sobre o canto da foto).
  final double levelBadgeOutset;

  /// Mostra a aura animada de nível (partículas, raios, fogos) ao
  /// redor da foto. Uma por faixa de raridade — ver [LevelAura].
  ///
  /// Passe `true`/`false` explicitamente para forçar o comportamento;
  /// quando não informado (`null`), a aura aparece em avatares >= 28px.
  /// Em avatares < 48px ela é desenhada como overlay (não altera o
  /// tamanho do layout, então não empurra o texto ao lado); a partir
  /// de 48px o Stack cresce para acomodá-la.
  final bool? showLevelAura;

  /// Reduz/aumenta o quanto a aura se estende para fora da foto.
  final double levelAuraExtentScale;

  final double size;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const UserAvatarDisplay({
    Key? key,
    required this.name,
    this.seed,
    this.photoUrl,
    this.equippedPremiumAvatarId,
    this.equippedCheckinRewardId,
    this.level,
    this.equippedPetId,
    this.orbitPet = false,
    this.levelBadgeScale = 1.5,
    this.levelBadgeOutset = 0.75,
    this.showLevelAura,
    this.levelAuraExtentScale = 1.0,
    this.size = 44,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final avatarId =
        PremiumAvatarIdX.fromStorageKey(equippedPremiumAvatarId);
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    Widget avatarContent;
    if (avatarId != null && hasPhoto) {
      // Tem avatar animado premium equipado E foto de perfil: em vez
      // de esconder a foto para sempre atrás do avatar, alterna entre
      // os dois em loop (avatar visível → foto revelada por alguns
      // segundos → avatar de volta...), para nenhum dos dois "sumir"
      // permanentemente.
      avatarContent = _PremiumAvatarPhotoCycle(
        avatarId: avatarId,
        size: size,
        name: name,
        seed: seed,
        photoUrl: photoUrl,
        showBorder: showBorder,
        borderColor: borderColor,
      );
    } else if (avatarId != null) {
      // Sem foto salva: nada para alternar, mantém só o avatar.
      avatarContent = ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: PremiumAnimatedAvatar(avatarId: avatarId, size: size),
        ),
      );
    } else {
      avatarContent = AppAvatar(
        name: name,
        seed: seed,
        photoUrl: photoUrl,
        size: size,
        showBorder: showBorder,
        borderColor: borderColor,
      );
    }

    final hasCheckinReward = CheckinRewardIdX.fromStorageKey(
          equippedCheckinRewardId,
        ) !=
        null;
    final hasLevelBadge = level != null && level! > 0;
    final candidatePet = PetCatalog.byId(equippedPetId);
    final resolvedPet = hasLevelBadge
        ? (candidatePet != null && candidatePet.levelRequired <= level!
            ? candidatePet
            : PetCatalog.fallbackForLevel(level!))
        : null;

    Widget content = avatarContent;
    if (hasCheckinReward || hasLevelBadge) {
      // Selos flutuantes, independentes do avatar em si — nunca criam
      // moldura ao redor da foto/iniciais, só se sobrepõem nos cantos.
      // Nível no canto superior esquerdo (novo LevelBadge, substitui
      // o antigo AvatarFrame); recompensa de check-in no canto
      // inferior direito, como já funcionava. Ambos proporcionais ao
      // tamanho do avatar, para continuar legíveis mesmo em ~36px.
      final checkinBadgeSize = (size * 0.42).clamp(14.0, 28.0);
      final levelBadgeSize = ((size * 0.4).clamp(13.0, 26.0) *
              levelBadgeScale)
          .toDouble();
      // Posição do selo: padrão colado no canto (-12%); com outset > 0
      // ele sobe/sai pela esquerda, ficando fora da foto — e acima da
      // aura, que também se estende para fora nesse mesmo canto.
      final levelBadgeOffset = -levelBadgeSize * (0.12 + levelBadgeOutset);
      // Aura ligada por padrão a partir de 28px (antes só >= 48px, o
      // que deixava comentários, respostas e ranking sem aura).
      final showAura =
          hasLevelBadge && (showLevelAura ?? size >= _minAuraSize);
      // Avatares grandes (>= 48px): o Stack cresce para acomodar a
      // aura (comportamento original, já validado). Avatares pequenos:
      // a aura é só um OVERLAY — o layout continua com exatamente
      // `size`, então o texto ao lado não é empurrado.
      final overlayAura = showAura && size < 48;
      final auraExtent = showAura
          ? LevelAura.extentFor(level!, size, scale: levelAuraExtentScale)
          : 0.0;
      final stackSize =
          overlayAura ? size : size * (1 + 2 * auraExtent);
      final petSize = levelBadgeSize * 1.18;
      final motionRadius = petSize * math.sqrt(0.16 * 0.16 + 0.07 * 0.07);
      // Usa o limite externo da aura e a diagonal do pet, incluindo
      // toda a trajetória. A folga permanece em qualquer fase do loop.
      final petDistance = (size * (0.5 + auraExtent) +
              petSize / math.sqrt2 + motionRadius + size * 0.08) /
          math.sqrt2;
      final petOrigin = orbitPet
          ? math.min(
              stackSize / 2 - size / 2 + levelBadgeOffset,
              stackSize / 2 - petDistance - petSize / 2,
            )
          : stackSize / 2 - size / 2 + levelBadgeOffset;
      final petInset = orbitPet && resolvedPet != null
          ? math.max(0.0, -petOrigin + petSize * 0.16)
          : 0.0;
      content = Padding(
        // Simétrico para manter a foto centralizada e contabilizar o
        // desenho que antes escapava do Stack sem ocupar espaço.
        padding: EdgeInsets.all(petInset),
        child: SizedBox(
          width: stackSize,
          height: stackSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (showAura && !overlayAura)
              LevelAura(
                level: level!,
                avatarSize: size,
                extentScale: levelAuraExtentScale,
              ),
              if (overlayAura)
              Positioned(
                left: -size * auraExtent,
                top: -size * auraExtent,
                width: size * (1 + 2 * auraExtent),
                height: size * (1 + 2 * auraExtent),
                child: LevelAura(
                  level: level!,
                  avatarSize: size,
                  extentScale: levelAuraExtentScale,
                ),
              ),
              avatarContent,
              if (hasLevelBadge && resolvedPet != null)
              Positioned(
                left: petOrigin,
                top: petOrigin,
                child: PetDisplay(
                  pet: resolvedPet,
                  size: petSize,
                  // Todos os avatares compartilham a mesma trajetória.
                  // orbitPet controla só o espaço extra do perfil.
                  orbit: true,
                ),
              ),
              if (hasCheckinReward)
              Positioned(
                right: stackSize / 2 - size / 2 - checkinBadgeSize * 0.12,
                bottom: stackSize / 2 - size / 2 - checkinBadgeSize * 0.12,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0A0A0A),
                  ),
                  child: CheckinRewardBadge(
                    storageKey: equippedCheckinRewardId,
                    size: checkinBadgeSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

/// Alterna, em loop contínuo, entre o avatar animado premium
/// equipado e a foto de perfil real por baixo dele — em vez de o
/// avatar substituir a foto para sempre. Ciclo: avatar visível por
/// [_avatarDuration], crossfade para a foto, foto visível por
/// [_photoDuration], crossfade de volta ao avatar, e repete.
class _PremiumAvatarPhotoCycle extends StatefulWidget {
  final PremiumAvatarId avatarId;
  final double size;
  final String? name;
  final String? seed;
  final String? photoUrl;
  final bool showBorder;
  final Color? borderColor;

  const _PremiumAvatarPhotoCycle({
    required this.avatarId,
    required this.size,
    required this.name,
    required this.seed,
    required this.photoUrl,
    required this.showBorder,
    required this.borderColor,
  });

  @override
  State<_PremiumAvatarPhotoCycle> createState() =>
      _PremiumAvatarPhotoCycleState();
}

class _PremiumAvatarPhotoCycleState extends State<_PremiumAvatarPhotoCycle> {
  static const _avatarDuration = Duration(seconds: 6);
  static const _photoDuration = Duration(seconds: 3);
  static const _fadeDuration = Duration(milliseconds: 600);

  bool _showAvatar = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer = Timer(_showAvatar ? _avatarDuration : _photoDuration, () {
      if (!mounted) return;
      setState(() => _showAvatar = !_showAvatar);
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Foto por baixo, sempre presente — é ela que fica
            // revelada quando o avatar desvanece.
            AppAvatar(
              name: widget.name,
              seed: widget.seed,
              photoUrl: widget.photoUrl,
              size: widget.size,
            ),
            AnimatedOpacity(
              opacity: _showAvatar ? 1.0 : 0.0,
              duration: _fadeDuration,
              curve: Curves.easeInOut,
              child: PremiumAnimatedAvatar(
                avatarId: widget.avatarId,
                size: widget.size,
              ),
            ),
          ],
        ),
      ),
    );
  }
}