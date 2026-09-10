import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../services/cloudinary_upload_service.dart';
import '../../services/admin_config_service.dart';
import '../../widgets/admin_shared_widgets.dart';

/// Aba "Barra de anúncios" do painel admin.
///
/// Controla, em tempo real via Firestore (app_config/global), qual
/// tipo de anúncio a Home exibe:
///   - admob   → banner do AdMob
///   - partner → imagem de parceiro configurada aqui mesmo
///   - off     → barra completamente desativada
///
/// Só um modo fica ativo por vez — trocar de modo já desliga o
/// anterior automaticamente, sem precisar publicar nova versão do app.
class AdsBarTab extends StatefulWidget {
  final AdminConfigService configService;
  const AdsBarTab({required this.configService, Key? key}) : super(key: key);

  @override
  State<AdsBarTab> createState() => _AdsBarTabState();
}

class _AdsBarTabState extends State<AdsBarTab> {
  final _cloudinary = CloudinaryUploadService();
  final _picker = ImagePicker();

  final _partnerNameCtrl = TextEditingController();
  final _partnerLinkCtrl = TextEditingController();

  bool _uploadingImage = false;
  bool _savingMode = false;
  String? _localPartnerImageUrl;
  bool _syncedControllersOnce = false;

  @override
  void dispose() {
    _partnerNameCtrl.dispose();
    _partnerLinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminSectionHeader(
            icon: Icons.campaign_rounded,
            iconColor: AppColors.textSecondary,
            text: 'Barra de anúncios',
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'Escolha o que aparece na barra de anúncios da Home. A '
              'mudança é aplicada em todos os aparelhos na hora, sem '
              'precisar publicar uma nova versão na Play Store.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: widget.configService.configStream(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final mode = (data?['adsBarMode'] as String?) ?? 'admob';
              final partnerName = (data?['adsPartnerName'] as String?) ?? '';
              final partnerImageUrl =
                  (data?['adsPartnerImageUrl'] as String?) ?? '';
              final partnerLinkUrl =
                  (data?['adsPartnerLinkUrl'] as String?) ?? '';

              // Sincroniza os campos de texto com o valor salvo apenas
              // uma vez (na primeira carga), pra não sobrescrever o
              // admin enquanto ele está digitando.
              if (!_syncedControllersOnce && snapshot.hasData) {
                _syncedControllersOnce = true;
                _partnerNameCtrl.text = partnerName;
                _partnerLinkCtrl.text = partnerLinkUrl;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeSelector(mode),
                  const SizedBox(height: 18),
                  if (mode == 'partner') ...[
                    _buildPartnerCard(
                      currentImageUrl: partnerImageUrl,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _buildPreviewCard(
                    mode: mode,
                    partnerImageUrl: _localPartnerImageUrl ?? partnerImageUrl,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Seletor de modo ──────────────────────────────────────────
  Widget _buildModeSelector(String mode) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  color: AppColors.primaryOrange, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Modo ativo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_savingMode)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryOrange,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _ModeOption(
            emoji: '🟢',
            title: 'Anúncio AdMob',
            subtitle: 'Exibe o banner do Google AdMob na Home.',
            selected: mode == 'admob',
            color: const Color(0xFF66BB6A),
            onTap: () => _handleModeChange('admob'),
          ),
          const SizedBox(height: 10),
          _ModeOption(
            emoji: '🟢',
            title: 'Anúncio de parceria',
            subtitle: 'Exibe a imagem do parceiro cadastrado abaixo.',
            selected: mode == 'partner',
            color: const Color(0xFF66BB6A),
            onTap: () => _handleModeChange('partner'),
          ),
          const SizedBox(height: 10),
          _ModeOption(
            emoji: '⚪',
            title: 'Desativado',
            subtitle: 'A barra de anúncios não aparece na Home.',
            selected: mode == 'off',
            color: AppColors.textSecondary,
            onTap: () => _handleModeChange('off'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleModeChange(String mode) async {
    setState(() => _savingMode = true);
    try {
      await widget.configService.setAdsBarMode(mode);
    } catch (e) {
      if (mounted) _showSnack('Erro ao salvar: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingMode = false);
    }
  }

  // ── Card de configuração do parceiro ────────────────────────
  Widget _buildPartnerCard({required String currentImageUrl}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake_rounded,
                  color: Color(0xFF66BB6A), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Anúncio de parceria',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Imagem do banner',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if ((_localPartnerImageUrl ?? currentImageUrl).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _localPartnerImageUrl ?? currentImageUrl,
                  height: 60,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 60,
                    color: const Color(0xFF151515),
                    alignment: Alignment.center,
                    child: const Text('Não foi possível carregar a imagem',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _uploadingImage ? null : _pickAndUploadPartnerImage,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                side: const BorderSide(
                    color: AppColors.primaryOrange, width: 1.2),
              ),
              icon: _uploadingImage
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primaryOrange),
                    )
                  : const Icon(Icons.image_rounded, size: 18),
              label: Text(
                (_localPartnerImageUrl ?? currentImageUrl).isEmpty
                    ? 'Escolher imagem'
                    : 'Trocar imagem',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nome do parceiro',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _partnerNameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _fieldDecoration('Ex.: Loja XYZ'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Link ao tocar no banner (opcional)',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _partnerLinkCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            keyboardType: TextInputType.url,
            decoration: _fieldDecoration('https://...'),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _savePartnerDetails,
              child: const Text('Salvar parceiro',
                  style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: const Color(0xFF151515),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _pickAndUploadPartnerImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingImage = true);
    try {
      final url = await _cloudinary.uploadImage(File(picked.path));
      setState(() => _localPartnerImageUrl = url);
    } catch (e) {
      if (mounted) _showSnack('Falha ao enviar imagem: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _savePartnerDetails() async {
    String imageUrl = _localPartnerImageUrl ?? '';
    // Se não trocou a imagem agora, preserva a que já está salva —
    // buscamos o valor atual para não sobrescrever com vazio.
    if (_localPartnerImageUrl == null) {
      final snap = await widget.configService.configStream().first;
      imageUrl = (snap.data()?['adsPartnerImageUrl'] as String?) ?? '';
    }
    if (imageUrl.isEmpty && _partnerNameCtrl.text.trim().isEmpty) {
      if (mounted) {
        _showSnack('Escolha uma imagem ou preencha o nome do parceiro.',
            error: true);
      }
      return;
    }
    try {
      await widget.configService.setAdsPartner(
        name: _partnerNameCtrl.text.trim(),
        imageUrl: imageUrl,
        linkUrl: _partnerLinkCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _localPartnerImageUrl = null);
        _showSnack('Parceiro salvo.');
      }
    } catch (e) {
      if (mounted) _showSnack('Erro ao salvar parceiro: $e', error: true);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? const Color(0xFFEF5350) : const Color(0xFF1A1A1A),
      ),
    );
  }

  // ── Prévia de como fica na Home ─────────────────────────────
  Widget _buildPreviewCard({
    required String mode,
    required String partnerImageUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prévia da Home',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildPreviewContent(mode, partnerImageUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(String mode, String partnerImageUrl) {
    if (mode == 'off') {
      return Container(
        height: 52,
        width: double.infinity,
        color: const Color(0xFF151515),
        alignment: Alignment.center,
        child: const Text(
          'Espaço vazio — nenhum anúncio será exibido',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
        ),
      );
    }
    if (mode == 'partner') {
      if (partnerImageUrl.isEmpty) {
        return Container(
          height: 52,
          width: double.infinity,
          color: const Color(0xFF151515),
          alignment: Alignment.center,
          child: const Text(
            'Nenhuma imagem de parceiro cadastrada ainda',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
        );
      }
      return Image.network(
        partnerImageUrl,
        height: 52,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 52,
          color: const Color(0xFF151515),
          alignment: Alignment.center,
          child: const Text('Não foi possível carregar a imagem',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
        ),
      );
    }
    // admob
    return Container(
      height: 52,
      width: double.infinity,
      color: const Color(0xFF151515),
      alignment: Alignment.center,
      child: const Text(
        'Banner do AdMob (carregado em tempo real no app)',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
      ),
    );
  }
}

// ── Item selecionável de modo (rádio estilizado) ────────────────
class _ModeOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.10) : const Color(0xFF151515),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color.withOpacity(0.6) : AppColors.borderDark,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? color : AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}