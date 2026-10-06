import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../config/app_navigator.dart';
import '../config/app_routes.dart';
import '../models/support_models.dart';
import '../widgets/app_messenger.dart';

/// Abre o atendimento a partir de qualquer lugar (toque no push, menu,
/// botão flutuante) e guarda a conversa que está sendo vista.
class SupportLauncher {
  SupportLauncher._();

  /// Conversa atualmente em primeiro plano na tela do chat. Usado para
  /// NÃO exibir push de uma conversa que a pessoa já está olhando.
  static String? viewingConversationId;

  /// Índice da aba "Atendimento" no painel ADM (ver AdminPanelScreen).
  static const int adminInboxTab = 10;

  static String? _pendingConversationId;
  static bool _opening = false;

  /// Toque no push. Se o app ainda está abrindo, ou o login ainda não
  /// terminou, a abertura fica pendente e é retomada por
  /// [openPendingIfAny] (chamado pelo gate de autenticação em main.dart).
  static Future<void> handlePushTap(String? conversationId) async {
    if (conversationId == null || conversationId.isEmpty) return;
    _pendingConversationId = conversationId;
    await openPendingIfAny();
  }

  static Future<void> openPendingIfAny() async {
    final id = _pendingConversationId;
    if (id == null || _opening) return;

    final nav = navigatorKey.currentState;
    final user = FirebaseAuth.instance.currentUser;
    if (nav == null || user == null) return; // aguarda navegação e login

    _opening = true;
    _pendingConversationId = null;
    try {
      if (viewingConversationId == id) return; // já está nela

      if (id == user.uid) {
        await nav.pushNamed(AppRoutes.support);
        return;
      }

      // Conversa de outra pessoa: só atendente. Valida de novo o acesso
      // lendo o documento (as regras do Firestore decidem).
      final snap = await FirebaseFirestore.instance
          .collection('support_conversations')
          .doc(id)
          .get();
      if (!snap.exists) {
        AppMessenger.error('Esta conversa não está mais disponível.');
        return;
      }
      await nav.pushNamed(
        AppRoutes.support,
        arguments: SupportChatArgs(conversationId: id),
      );
    } on FirebaseException {
      AppMessenger.error('Você não tem acesso a esta conversa.');
    } catch (_) {
      AppMessenger.error('Não foi possível abrir a conversa.');
    } finally {
      _opening = false;
    }
  }

  /// Usuário comum: abre a própria conversa. ADM: abre a caixa de
  /// atendimento no painel. Usa a chave global de navegação, então
  /// funciona de qualquer lugar (inclusive do botão flutuante, que fica
  /// acima do Navigator).
  static void open({required bool asAgent}) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    if (asAgent) {
      nav.pushNamed(AppRoutes.adminPanel, arguments: {'tab': adminInboxTab});
    } else {
      nav.pushNamed(AppRoutes.support);
    }
  }

  /// Abre (ou prepara) a conversa com [profile] no modo atendente.
  /// Usado pelo botão "Enviar mensagem" do perfil ADM. Se a conversa
  /// ainda não existe, ela só é criada na primeira mensagem enviada.
  static Future<void> openForUser(
    BuildContext context,
    SupportProfile profile,
  ) {
    return Navigator.of(context).pushNamed(
      AppRoutes.support,
      arguments: SupportChatArgs(
        conversationId: profile.userId,
        seedProfile: profile,
      ),
    );
  }
}