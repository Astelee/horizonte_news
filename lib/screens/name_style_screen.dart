import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/name_style_config.dart';
import '../providers/user_xp_provider.dart';
import '../services/name_style_service.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_messenger.dart';
import '../widgets/styled_user_name.dart';
import '../widgets/subscriber_badge.dart';

// ═══════════════════════════════════════════════════════════════════
// SELETOR DE PERSONALIZAÇÃO DO NOME (assinantes)
// ═══════════════════════════════════════════════════════════════════
// Tela aberta pelo botão ao lado do nome no Perfil (só para quem tem
// assinatura vigente — quem não tem é levado à tela Premium antes de
// chegar aqui; e o NameStyleService ainda recusa o salvamento).
//
// NÃO desenha nada por conta própria: a prévia usa o StyledUserName
// (o mesmo widget de comentários/ranking/perfil), então o que aparece
// aqui é exatamente o que todo mundo verá depois de salvar. Toda a
// otimização de name_effects.dart (relógio único, ~30 FPS, "reduzir
// animações", pausa com a tela coberta) continua valendo.
//
// Estado local: [_draft] é o rascunho (null = visual padrão) e
// [_saved] o que está gravado. A prévia acompanha o rascunho a cada
// toque; nada é gravado até tocar em Salvar / Restaurar padrão.
// ═══════════════════════════════════════════════════════════════════

class NameStyleScreen extends StatefulWidget {
  const NameStyleScreen({Key? key}) : super(key: key);

  @override
  State<NameStyleScreen> createState() => _NameStyleScreenState();
}

class _NameStyleScreenState extends State<NameStyleScreen> {
  // Ícone e descrição curta de cada efeito. Um efeito novo em
  // NameEffect aparece sozinho na lista (com ícone genérico e sem
  // descrição) — basta acrescentar aqui para caprichar.
  static const Map<NameEffect, IconData> _effectIcons = {
    NameEffect.glow: FontAwesomeIcons.sun,
    NameEffect.gradient: FontAwesomeIcons.water,
    NameEffect.particles: FontAwesomeIcons.wandMagicSparkles,
    NameEffect.lightning: FontAwesomeIcons.bolt,
  };

  static const Map<NameEffect, String> _effectHints = {
    NameEffect.glow: 'Aura de luz que respira ao redor do nome.',
    NameEffect.gradient: 'Cores que deslizam pelas letras.',
    NameEffect.particles: 'Faíscas que sobem e brilham.',
    NameEffect.lightning: 'Descargas rápidas de energia.',
  };

  NameStyle? _saved; // gravado (null = padrão)
  NameStyle? _draft; // rascunho da prévia (null = padrão)
  bool _saving = false;
  bool _initialized = false;
  late String _displayName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    // Lê só UMA vez: se o stream do perfil emitir de novo enquanto a
    // pessoa mexe nas opções, o rascunho não é sobrescrito.
    final data = context.read<UserXpProvider>().data;
    _saved = _clean(data.nameStyle);
    _draft = _saved;

    final user = FirebaseAuth.instance.currentUser;
    _displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'Usuário';
  }

  // Cópia sem premiumExpiresAt: assim rascunho e gravado se comparam
  // só por cor + efeitos + intensidade.
  NameStyle? _clean(NameStyle? style) {
    if (style == null) return null;
    return NameStyle(
      colorId: style.colorId,
      effects: Set<NameEffect>.of(style.effects),
      intensity: style.intensity,
    );
  }

  NameStyle get _base => _draft ?? const NameStyle();

  bool get _dirty => _draft != _saved;
  bool get _canSave => _dirty && _draft != null && !_saving;
  bool get _canRestore => (_saved != null || _draft != null) && !_saving;

  // ── Ações sobre o rascunho (a prévia reage na hora) ──────────────
  void _setColor(String id) {
    setState(() => _draft = _base.copyWith(colorId: id));
  }

  void _toggleEffect(NameEffect effect) {
    final next = Set<NameEffect>.of(_base.effects);
    if (!next.add(effect)) next.remove(effect);
    setState(() => _draft = _base.copyWith(effects: next));
  }

  void _setIntensity(NameIntensity intensity) {
    if (!(_draft?.hasEffects ?? false)) return;
    setState(() => _draft = _base.copyWith(intensity: intensity));
  }

  // ── Salvar ───────────────────────────────────────────────────────
  Future<void> _save() async {
    final style = _draft;
    if (style == null || _saving) return;

    setState(() => _saving = true);
    try {
      await NameStyleService.save(style);
      if (!mounted) return;
      AppMessenger.success('Nome personalizado!');
      Navigator.of(context).pop();
    } on StateError catch (e) {
      AppMessenger.error(e.message);
    } catch (_) {
      AppMessenger.error('Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Restaurar padrão ─────────────────────────────────────────────
  Future<void> _restore() async {
    if (_saving) return;

    // Nada gravado ainda: só descarta o rascunho, sem ir ao Firestore.
    if (_saved == null) {
      setState(() => _draft = null);
      return;
    }

    final ok = await AppConfirmDialog.show(
      context,
      title: 'Restaurar padrão?',
      message: 'Seu nome volta ao visual padrão, sem cor nem efeitos. '
          'Você pode personalizar de novo quando quiser.',
      confirmLabel: 'Restaurar',
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await NameStyleService.reset();
      if (!mounted) return;
      setState(() {
        _saved = null;
        _draft = null;
      });
      AppMessenger.success('Nome restaurado ao padrão.');
    } catch (_) {
      AppMessenger.error('Não foi possível restaurar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'PERSONALIZAR NOME',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // Prévia fixa no topo: continua visível enquanto a pessoa
          // rola pelas opções.
          _buildPreview(),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildSection(
                  title: 'COR',
                  subtitle: 'A cor principal do seu nome.',
                  child: _buildColors(),
                ),
                const SizedBox(height: 14),
                _buildSection(
                  title: 'EFEITOS',
                  subtitle: 'Toque em mais de um para combinar.',
                  child: _buildEffects(),
                ),
                const SizedBox(height: 14),
                _buildSection(
                  title: 'INTENSIDADE',
                  subtitle: 'Tamanho do brilho, quantidade de faíscas e '
                      'velocidade.',
                  child: _buildIntensity(),
                ),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── Prévia ───────────────────────────────────────────────────────
  Widget _buildPreview() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isDefault = _draft == null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF141414), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.08),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'PRÉVIA',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Text(
                isDefault ? 'Visual padrão' : 'Ao vivo',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: StyledUserName(
                    _displayName,
                    nameStyle: _draft,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const SubscriberBadge(size: 20),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1E1E1E)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Comentários e ranking',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StyledUserName(
                    _displayName,
                    nameStyle: _draft,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (reduceMotion && (_draft?.hasEffects ?? false)) ...[
            const SizedBox(height: 10),
            const Text(
              'Animações reduzidas estão ativas no seu aparelho: a prévia '
              'aparece parada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Card de seção ────────────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryOrange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ── Cores ────────────────────────────────────────────────────────
  Widget _buildColors() {
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: [
        for (final preset in NameColors.all) _buildColorSwatch(preset),
      ],
    );
  }

  Widget _buildColorSwatch(NameColorPreset preset) {
    final selected = _draft?.colorId == preset.id;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setColor(preset.id),
      child: SizedBox(
        width: 56,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [preset.primary, preset.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: selected ? Colors.white : Colors.white12,
                  width: selected ? 2.4 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: preset.primary.withOpacity(0.6),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? const Icon(
                      FontAwesomeIcons.check,
                      size: 15,
                      color: Colors.black87,
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              preset.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Efeitos (combináveis) ────────────────────────────────────────
  Widget _buildEffects() {
    return Column(
      children: [
        for (int i = 0; i < NameEffect.values.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildEffectTile(NameEffect.values[i]),
        ],
      ],
    );
  }

  Widget _buildEffectTile(NameEffect effect) {
    final selected = _draft?.effects.contains(effect) ?? false;
    final hint = _effectHints[effect];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _toggleEffect(effect),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? AppColors.primaryOrange.withOpacity(0.10)
                : AppColors.surfaceDark,
            border: Border.all(
              color: selected
                  ? AppColors.primaryOrange.withOpacity(0.75)
                  : const Color(0xFF212121),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.primaryOrange.withOpacity(0.18)
                      : Colors.white.withOpacity(0.05),
                ),
                child: Icon(
                  _effectIcons[effect] ?? FontAwesomeIcons.wandMagicSparkles,
                  size: 15,
                  color: selected
                      ? AppColors.primaryOrange
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      effect.label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primaryOrange : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryOrange
                        : const Color(0xFF3A3A3A),
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        FontAwesomeIcons.check,
                        size: 11,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Intensidade ──────────────────────────────────────────────────
  Widget _buildIntensity() {
    final enabled = _draft?.hasEffects ?? false;
    final current = _draft?.intensity ?? NameIntensity.normal;
    const values = NameIntensity.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Row(
            children: [
              for (int i = 0; i < values.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _buildIntensityOption(
                    values[i],
                    selected: enabled && values[i] == current,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!enabled) ...[
          const SizedBox(height: 10),
          const Text(
            'Escolha pelo menos um efeito para ajustar a intensidade.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIntensityOption(
    NameIntensity intensity, {
    required bool selected,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setIntensity(intensity),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected ? AppColors.orangeGradient : null,
          color: selected ? null : AppColors.surfaceDark,
          border: Border.all(
            color: selected
                ? Colors.white.withOpacity(0.15)
                : const Color(0xFF212121),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          intensity.label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ── Barra inferior: Restaurar padrão + Salvar ────────────────────
  Widget _buildBottomBar() {
    final canSave = _canSave;
    final canRestore = _canRestore;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: GestureDetector(
                onTap: canRestore ? _restore : null,
                child: Opacity(
                  opacity: canRestore ? 1 : 0.4,
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.surfaceDark,
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: const Text(
                      'Restaurar padrão',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: GestureDetector(
                onTap: canSave ? _save : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: canSave ? AppColors.orangeGradient : null,
                    color: canSave ? null : const Color(0xFF1A1A1A),
                    boxShadow: canSave
                        ? [
                            BoxShadow(
                              color: AppColors.primaryOrange.withOpacity(0.35),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Salvar',
                          style: TextStyle(
                            color: canSave
                                ? Colors.white
                                : AppColors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}