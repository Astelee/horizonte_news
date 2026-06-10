// ── Lista todas as conquistas possíveis com status ───────────────
  // icon agora é o ID do achievement — BadgeConfig resolve o ícone FA
  List<Achievement> getAllAchievements(List<String> unlocked) {
    return [
      Achievement(
        id: 'first_login',
        title: 'Primeiro Acesso',
        description: 'Entrou no Horizonte News pela primeira vez',
        icon: 'first_login', // ← era '🚀', agora é o próprio ID
        unlocked: unlocked.contains('first_login'),
      ),
      Achievement(
        id: '1h_online',
        title: '1 Hora Online',
        description: 'Ficou 1 hora ativo no aplicativo',
        icon: '1h_online',
        unlocked: unlocked.contains('1h_online'),
      ),
      Achievement(
        id: '10h_online',
        title: '10 Horas Online',
        description: 'Ficou 10 horas ativo no aplicativo',
        icon: '10h_online',
        unlocked: unlocked.contains('10h_online'),
      ),
      Achievement(
        id: '100_articles',
        title: 'Leitor Dedicado',
        description: 'Leu 100 notícias no aplicativo',
        icon: '100_articles',
        unlocked: unlocked.contains('100_articles'),
      ),
      Achievement(
        id: 'first_share',
        title: 'Compartilhador',
        description: 'Compartilhou uma notícia pela primeira vez',
        icon: 'first_share',
        unlocked: unlocked.contains('first_share'),
      ),
      Achievement(
        id: 'first_comment',
        title: 'Comentarista',
        description: 'Realizou seu primeiro comentário',
        icon: 'first_comment',
        unlocked: unlocked.contains('first_comment'),
      ),
      Achievement(
        id: 'level_5',
        title: 'Veterano',
        description: 'Alcançou o nível 5',
        icon: 'level_5',
        unlocked: unlocked.contains('level_5'),
      ),
      Achievement(
        id: 'level_10',
        title: 'Lenda',
        description: 'Alcançou o nível 10',
        icon: 'level_10',
        unlocked: unlocked.contains('level_10'),
      ),
    ];
  }

  // ── levelIcon agora delega para BadgeConfig ──────────────────────
  // Mantido por compatibilidade com código existente que chame
  // XpService.levelIcon(). Retorna String vazia pois a UI
  // agora usa BadgeConfig.levelIcon(level) diretamente.
  static String levelIcon(int level) => '';
