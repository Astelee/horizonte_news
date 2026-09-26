import 'package:flutter/material.dart';
import '../config/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════
// APP CONFIRM DIALOG — dialog de confirmação centralizado
// ═══════════════════════════════════════════════════════════════════
// Parte da Fase 4 da padronização de feedback visual: complementa o
// AppMessenger (mensagens temporárias) com um componente único para
// diálogos de confirmação ("Excluir?", "Sair da conta?" etc.), na
// mesma identidade visual (fundo preto, borda e destaque laranja,
// cantos arredondados).
//
// Uso:
//   final ok = await AppConfirmDialog.show(
//     context,
//     title: 'Excluir comentário?',
//     message: 'Esta ação não pode ser desfeita.',
//     confirmLabel: 'Excluir',
//     confirmColor: AppColors.emergencyRed, // opcional, default laranja
//   );
//   if (ok == true) { ... }
// ═══════════════════════════════════════════════════════════════════
class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Color confirmColor;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.confirmColor = AppColors.primaryOrange,
  });

  /// Mostra o dialog e retorna `true` se confirmado, `false`/`null`
  /// se cancelado ou dispensado.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    Color confirmColor = AppColors.primaryOrange,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        confirmColor: confirmColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.2)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: confirmColor, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}