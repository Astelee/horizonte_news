import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../models/support_models.dart';
import '../../../widgets/app_messenger.dart';
import '../providers/admin_provider.dart';
import '../services/admin_support_service.dart';

/// Opção de exclusão escolhida pelo atendente.
enum SupportDeleteChoice { onlyMe, both }

/// Pergunta como excluir a conversa e executa. Devolve true se a
/// conversa saiu da caixa de entrada (arquivada ou apagada).
///
/// • "Só para mim": some da caixa de entrada e o histórico anterior
///   fica escondido para a equipe. O usuário continua vendo tudo; se ele
///   escrever de novo, a conversa volta.
/// • "Para os dois": apaga mensagens e conversa de vez, para todo mundo.
///   Não é permitido com o envio bloqueado (apagaria o bloqueio).
Future<bool> askAndDeleteSupportConversation(
  BuildContext context, {
  required AdminSupportService service,
  required SupportConversation conversation,
}) async {
  final choice = await showModalBottomSheet<SupportDeleteChoice>(
    context: context,
    backgroundColor: AppColors.backgroundElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Excluir conversa com ${conversation.userName}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _option(
              icon: Icons.visibility_off_rounded,
              color: AppColors.primaryOrange,
              title: 'Excluir só para mim (equipe)',
              subtitle:
                  'Sai da sua caixa de entrada e o histórico some para a equipe. '
                  'O usuário continua vendo a conversa. Se ele escrever de novo, ela volta.',
              onTap: () => Navigator.pop(ctx, SupportDeleteChoice.onlyMe),
            ),
            const SizedBox(height: 8),
            _option(
              icon: Icons.delete_forever_rounded,
              color: AppColors.emergencyRed,
              title: 'Excluir para os dois',
              subtitle: conversation.blocked
                  ? 'Indisponível: o envio desta pessoa está bloqueado e a exclusão '
                      'apagaria o bloqueio. Desbloqueie antes.'
                  : 'Apaga as mensagens e a conversa de vez, para você e para o usuário. '
                      'Não tem como desfazer.',
              enabled: !conversation.blocked,
              onTap: () => Navigator.pop(ctx, SupportDeleteChoice.both),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;

  if (choice == SupportDeleteChoice.both) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Excluir para os dois?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Todas as mensagens com ${conversation.userName} serão apagadas '
          'para você e para ele, sem como recuperar.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir',
                  style: TextStyle(color: AppColors.emergencyRed))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return false;
  }

  // Indicador de progresso (apagar muitas mensagens leva alguns segundos).
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: AppColors.primaryOrange),
    ),
  );
  var done = false;
  try {
    if (choice == SupportDeleteChoice.both) {
      await service.deleteConversationForAll(conversation.id);
    } else {
      await service.archiveConversation(conversation.id);
    }
    done = true;
    if (context.mounted) {
      context.read<AdminProvider>().logAction(
            action: choice == SupportDeleteChoice.both
                ? 'support_delete_all'
                : 'support_archive',
            targetId: conversation.userId,
            targetType: 'user',
          );
    }
  } catch (_) {
    AppMessenger.error('Não foi possível excluir a conversa.');
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
  if (done) {
    AppMessenger.success(choice == SupportDeleteChoice.both
        ? 'Conversa excluída para os dois'
        : 'Conversa removida da sua caixa de entrada');
  }
  return done;
}

Widget _option({
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  bool enabled = true,
}) {
  return Opacity(
    opacity: enabled ? 1 : 0.45,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}