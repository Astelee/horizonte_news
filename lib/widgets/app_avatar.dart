import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/initials_helper.dart';
import '../config/premium_avatars_config.dart';
import 'premium_avatars.dart';

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
///
/// Este é o único ponto de decisão dessa prioridade — usado como
/// substituto direto de AppAvatar em todo lugar que já compõe
/// `AvatarFrame(child: AppAvatar(...))`, preservando exatamente o
/// mesmo tamanho e posição, sem alterar o resto do layout.
class UserAvatarDisplay extends StatelessWidget {
  final String? name;
  final String? seed;
  final String? photoUrl;

  /// Chave salva em equippedPremiumAvatarId (UserXpData). Quando nula
  /// ou desconhecida, o avatar animado é ignorado e o widget se
  /// comporta como um AppAvatar comum.
  final String? equippedPremiumAvatarId;

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

    Widget content;
    if (avatarId != null && hasPhoto) {
      // Tem avatar animado premium equipado E foto de perfil: em vez
      // de esconder a foto para sempre atrás do avatar, alterna entre
      // os dois em loop (avatar visível → foto revelada por alguns
      // segundos → avatar de volta...), para nenhum dos dois "sumir"
      // permanentemente.
      content = _PremiumAvatarPhotoCycle(
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
      content = ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: PremiumAnimatedAvatar(avatarId: avatarId, size: size),
        ),
      );
    } else {
      content = AppAvatar(
        name: name,
        seed: seed,
        photoUrl: photoUrl,
        size: size,
        showBorder: showBorder,
        borderColor: borderColor,
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