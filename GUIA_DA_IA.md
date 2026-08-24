GUIA_DA_IA.md

Horizonte News - Guia para IA

IMPORTANTE

Antes de criar qualquer arquivo novo:

1. Verifique se já existe um arquivo com função semelhante.
2. Prefira editar arquivos existentes em vez de criar duplicatas.
3. Nunca recrie sistemas já existentes.
4. Sempre respeite a estrutura atual do projeto.
5. Se precisar alterar um sistema, identifique primeiro quais arquivos estão envolvidos.
6. Consulte sempre o ESTRUTURA_PROJETO.md antes de assumir que uma tela ou serviço existe.

---

Visão Geral

Horizonte News é um aplicativo Flutter de notícias com:

- Sistema de notícias (conteúdo vem do Blogger via API)
- Sistema de usuários (Firebase Auth)
- Sistema de XP e níveis
- Sistema de emblemas
- Sistema de favoritos
- Sistema de comentários
- Painel administrativo
- Integração com Firebase (Auth, Firestore, Analytics)
- Notificações (OneSignal)
- Anúncios (AdMob + parceiros próprios)

NÃO EXISTE no projeto (não recriar nem tentar "corrigir"):

- Sistema de amigos
- Sistema de chat
- Tela de vídeos
- Editor de posts dentro do app

---

Estrutura Principal

Arquivo Inicial

lib/main.dart

Responsável por:

- Inicializar Firebase
- Inicializar AdMob
- Aplicar preferência de "Lembrar login"
- Carregar Providers
- Definir tema
- Iniciar aplicativo

---

CONFIGURAÇÕES

Pasta:

lib/config/

Arquivos:

app_colors.dart
app_routes.dart
app_theme.dart
badge_config.dart
blogger_config.dart

Funções:

- Cores globais
- Rotas
- Tema
- Configuração de badges
- Configuração do Blogger

---

MODELS

Pasta:

lib/models/

category_model.dart

Modelo de categoria de notícias.

post_model.dart

Modelo de postagem.

---

PROVIDERS

Pasta:

lib/providers/

posts_provider.dart

Gerencia carregamento das notícias.

favorites_provider.dart

Gerencia favoritos.

theme_provider.dart

Gerencia tema do aplicativo.

user_xp_provider.dart

Gerencia:

- XP
- Níveis
- Progressão do usuário

lib/features/admin/providers/admin_provider.dart

Gerencia autenticação e permissões do painel administrativo.

---

AUTENTICAÇÃO

Arquivo:

lib/services/auth_service.dart

Responsável por:

- Login e logout (Firebase Auth)
- Preferência "Lembrar login" (salva apenas o e-mail — a senha nunca é salva no dispositivo; quem mantém a sessão logada é a persistência nativa do Firebase Auth)

---

SISTEMA DE XP

Arquivos principais:

user_xp_provider.dart
xp_service.dart
badge_config.dart
badge_widgets.dart
level_up_overlay.dart

Funções:

- Ganho de XP
- Níveis
- Emblemas
- Recompensas

Qualquer alteração de nível deve verificar estes arquivos.

---

SISTEMA DE NOTÍCIAS

Arquivos:

home_screen.dart
post_detail_screen.dart
category_screen.dart
most_read_screen.dart
search_screen.dart
horizon_now_screen.dart
events_screen.dart

Widgets relacionados:

news_card.dart
featured_carousel.dart
breaking_news_banner.dart
category_bar.dart

Conteúdo vem do Blogger via lib/services/blogger_service.dart e lib/config/blogger_config.dart. Não existe editor de posts dentro do app — publicação é feita direto no Blogger.

---

SISTEMA DE COMENTÁRIOS

Arquivo principal:

comments_section.dart

Antes de alterar comentários verificar:

- Perfil do usuário
- Sistema de XP
- Sistema de emblemas
- Sistema de banimento (coleção suspensions no Firestore)

---

PERFIL DO USUÁRIO

Arquivo:

profile_screen.dart

Relacionado com:

- XP
- Emblemas
- Favoritos

Qualquer alteração deve preservar as integrações existentes.

---

RANKING

Arquivo:

ranking_screen.dart

Mostra o ranking de usuários por XP.

---

FAVORITOS

Arquivos:

favorites_screen.dart
favorites_provider.dart
favorites_service.dart

---

ADMINISTRAÇÃO

Arquivo:

lib/features/admin/screens/admin_panel_screen.dart

Abas (lib/features/admin/screens/tabs/):

overview_tab.dart
users_tab.dart
comments_tab.dart
banned_tab.dart
views_tab.dart
poderes_tab.dart

Serviços (lib/features/admin/services/):

admin_comment_service.dart
admin_dashboard_service.dart
admin_user_service.dart
admin_views_service.dart

Funções:

- Gerenciar usuários e comentários
- Banir/desbanir usuários (coleção suspensions)
- Ver estatísticas e visualizações
- Ferramentas administrativas ("poderes")

Não existe post_editor_screen.dart nem admin_service.dart — a publicação de notícias é feita pelo Blogger, fora do app.

---

FIREBASE

Serviços:

lib/services/notification_service.dart (integração com OneSignal)

Cloud Functions:

functions/index.js — envia notificação push quando um novo post é criado na coleção noticias.

Segurança:

firestore.rules — define quem pode ler/escrever cada coleção. Sempre consultar este arquivo antes de adicionar uma nova coleção no Firestore, e atualizar as regras junto com qualquer mudança de schema.

IMPORTANTE:

Antes de modificar Firebase verificar compatibilidade com:

- Android
- Cloud Functions
- Notificações
- firestore.rules

---

ANÚNCIOS

Pasta:

lib/ads/

ad_config.dart — configuração de parceiros e do AdMob.
hybrid_banner_ad.dart — exibe banner do parceiro ativo ou do AdMob.

---

WIDGETS REUTILIZÁVEIS

Pasta:

lib/widgets/

app_avatar.dart
app_drawer.dart
avatar_frame.dart
badge_widgets.dart
breaking_news_banner.dart
category_bar.dart
comments_section.dart
featured_carousel.dart
level_up_overlay.dart
news_card.dart
relative_time_text.dart

Antes de criar um novo widget verificar se algum destes já resolve o problema.

---

ASSETS

assets/images/

icon_app.png

assets/sounds/

ambient.mp3
click.mp3
ranking.mp3

assets/icons/

Ícones do aplicativo.

assets/ads/parceiros/

Imagens dos parceiros de anúncio.

---

REGRA PARA ALTERAÇÕES

Ao implementar qualquer funcionalidade:

1. Identifique os arquivos já existentes.
2. Reutilize componentes existentes.
3. Evite duplicação de código.
4. Não criar versões paralelas do mesmo sistema.
5. Manter compatibilidade com Firebase e com firestore.rules.
6. Preservar sistema de XP.
7. Preservar sistema de comentários.
8. Preservar sistema de notificações.
9. Não assumir que sistemas de amigos, chat, vídeos ou editor de posts existem — eles não existem.

---

REGRA PARA RESPOSTAS DA IA

Sempre informar:

- Quais arquivos serão alterados.
- Por que serão alterados.
- Impacto da alteração.
- Dependências afetadas.

Antes de criar um novo arquivo, justificar por que um arquivo existente não pode ser reutilizado.

---

OBSERVAÇÃO

O projeto possui:

✓ Sistema de notícias (via Blogger)
✓ Sistema de XP e níveis
✓ Sistema de emblemas
✓ Sistema de favoritos
✓ Sistema de comentários
✓ Sistema de ranking
✓ Sistema administrativo
✓ Firebase (Auth, Firestore, Analytics)
✓ Notificações (OneSignal)
✓ Anúncios (AdMob + parceiros)

O projeto NÃO possui (não recriar):

✗ Sistema de amigos
✗ Sistema de chat
✗ Tela de vídeos
✗ Editor de posts dentro do app
