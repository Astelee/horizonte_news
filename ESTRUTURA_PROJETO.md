# Horizonte News — Estrutura atual do projeto

Flutter / Android — documento revisado a partir do código presente neste pacote.

> **Última varredura:** 23/09/2026
> 
> Este arquivo descreve o estado real do projeto nesta versão. Não usar versões antigas desta documentação para assumir que um arquivo, tela ou serviço existe.

---

## 1. Arquivo principal e inicialização

```text
lib/main.dart
```

O `main.dart` atualmente:

- inicializa o Firebase com `FirebaseOptions`;
- aplica `AuthService.enforceRememberPreference()` antes do `runApp`;
- inicializa AdMob em segundo plano;
- inicializa OneSignal por `NotificationService`;
- inicializa `SoundService`;
- registra os Providers globais:
  - `ThemeProvider`
  - `PostsProvider`
  - `FavoritesProvider`
  - `UserXpProvider`
  - `AdminProvider`
- inicia `HorizonteNewsApp`;
- configura `navigatorKey` por `AppNavigator`;
- aplica tema claro/escuro conforme `ThemeProvider`;
- usa localização `pt-BR`;
- configura as rotas de `AppRoutes`;
- inicia `DeepLinkService` após o primeiro frame;
- possui `_AuthGate`, que verifica configuração global/manutenção;
- durante manutenção, usuários administradores continuam acessando o painel;
- `_AuthenticatedGate` reage ao `FirebaseAuth.authStateChanges()`;
- quando há usuário logado, inicializa XP/admin e associa o UID ao OneSignal como External ID;
- quando não há usuário logado, reseta o estado administrativo e desassocia o OneSignal.

### Fluxo de entrada

```text
main()
  ↓
Firebase.initializeApp()
  ↓
enforceRememberPreference()
  ↓
AdMob + OneSignal + SoundService (sem bloquear o boot)
  ↓
MultiProvider
  ↓
HorizonteNewsApp
  ↓
AuthGate
  ├── manutenção ativa → verifica admins/{uid}
  └── fluxo normal → FirebaseAuth
        ├── logado → Home
        └── não logado → Login
```

---

## 2. Estrutura real de diretórios

```text
.
├── .github/
│   └── workflows/
│       ├── build_apk.yml
│       └── deploy_hosting.yml
│
├── android/
│   ├── build.gradle
│   ├── gradle.properties
│   ├── settings.gradle
│   ├── gradle/wrapper/gradle-wrapper.properties
│   └── app/
│       ├── build.gradle
│       ├── google-services.json
│       └── src/main/
│           ├── AndroidManifest.xml
│           ├── kotlin/com/astelee/horizonte_news/MainActivity.kt
│           └── res/
│               ├── drawable/
│               │   ├── launch_background.xml
│               │   └── splash.png
│               ├── values/
│               │   ├── colors.xml
│               │   └── styles.xml
│               └── values-v31/styles.xml
│
├── assets/
│   ├── ads/parceiros/parceiro_1.png
│   ├── images/icon_app.png
│   ├── icons/
│   └── sounds/
│       ├── ambient.mp3
│       ├── click.mp3
│       └── ranking.mp3
│
├── lib/
│   ├── ads/
│   ├── config/
│   ├── features/admin/
│   ├── models/
│   ├── providers/
│   ├── screens/
│   ├── services/
│   ├── utils/
│   ├── widgets/
│   └── main.dart
│
├── test/
│   ├── badge_config_test.dart
│   ├── widget_test.dart
│   └── xp_service_test.dart
│
├── firestore.rules
├── firebase.json
├── pubspec.yaml
├── ESTRUTURA_PROJETO.md
└── GUIA_DA_IA.md
```

### Importante

**Não existe a pasta `functions/` neste pacote.** A documentação antiga que dizia existir `functions/index.js` estava desatualizada.

Também não há `README` com conteúdo relevante no pacote atual.

---

# 3. Configurações — `lib/config/`

```text
app_colors.dart
app_navigator.dart
app_routes.dart
app_theme.dart
badge_config.dart
blogger_config.dart
premium_avatars_config.dart
premium_config.dart
```

### Responsabilidades

- `app_colors.dart` — identidade visual e cores globais.
- `app_navigator.dart` — `navigatorKey` global.
- `app_routes.dart` — rotas principais do aplicativo.
- `app_theme.dart` — temas claro/escuro.
- `badge_config.dart` — níveis, títulos/emblemas e configurações relacionadas.
- `blogger_config.dart` — configuração da integração legada com Blogger.
- `premium_config.dart` — tiers `none`, `pro` e `ultra`, multiplicadores de XP, selo e regras de leitura do Premium.
- `premium_avatars_config.dart` — catálogo de avatares animados Premium.

### Premium atual

```text
none → multiplicador XP 1x
pro  → multiplicador XP 2x
ultra → multiplicador XP 8x
```

O tier é lido de `users_xp/{uid}` e `premiumExpiresAt` é considerado na validade.

---

# 4. Models — `lib/models/`

```text
category_model.dart
notification_model.dart
post_model.dart
```

- `CategoryModel` — categorias.
- `AppNotificationModel` / `NotificationType` — notificações internas.
- `PostModel` — notícias, incluindo status, galeria, vídeo e configuração de enquadramento do vídeo.

`PostModel` possui suporte antigo a JSON do Blogger, mas o caminho principal atual do aplicativo é Firestore.

---

# 5. Providers — `lib/providers/`

```text
favorites_provider.dart
posts_provider.dart
theme_provider.dart
user_xp_provider.dart
```

- `PostsProvider` — feed, stream das notícias recentes, paginação, categorias, busca e vídeos.
- `FavoritesProvider` — favoritos.
- `ThemeProvider` — tema.
- `UserXpProvider` — XP, nível, progresso e atualização de atividade.

Também existe:

```text
lib/features/admin/providers/admin_provider.dart
```

Responsável pelo estado de administrador, papel do admin e logs administrativos.

---

# 6. Telas principais — `lib/screens/`

```text
category_screen.dart
checkin_screen.dart
contact_screen.dart
events_screen.dart
favorites_screen.dart
forgot_password_screen.dart
home_screen.dart
horizon_now_screen.dart
login_screen.dart
most_read_screen.dart
notifications_screen.dart
post_detail_screen.dart
premium_avatar_gallery_screen.dart
premium_screen.dart
profile_screen.dart
ranking_screen.dart
register_screen.dart
search_screen.dart
settings_screen.dart
splash_screen.dart
```

### Funcionalidades existentes

- Home/feed de notícias.
- Categorias.
- Detalhes de notícia.
- Busca.
- Favoritos.
- Mais lidas.
- Horizonte Agora.
- Eventos.
- Ranking.
- Check-in diário e recuperação de dia perdido.
- Perfil.
- Configurações.
- Notificações.
- Login/cadastro/recuperação de senha.
- Premium.
- Galeria de avatares Premium.
- Splash.

---

# 7. Serviços — `lib/services/`

```text
app_config_service.dart
app_notification_service.dart
auth_service.dart
avatar_approval_service.dart
avatar_upload_service.dart
blogger_service.dart
checkin_service.dart
cloudinary_upload_service.dart
deep_link_service.dart
favorites_service.dart
news_service.dart
notification_service.dart
purchase_service.dart
rewarded_ad_service.dart
sound_service.dart
subscription_request_service.dart
xp_service.dart
```

### Pontos importantes

- `auth_service.dart` — Firebase Auth, login/logout e preferência de lembrar login.
- `news_service.dart` — fonte atual de notícias publicadas no Firestore (`noticias`).
- `blogger_service.dart` — integração antiga/compatibilidade com Blogger; não assumir que ele seja a fonte atual do feed.
- `notification_service.dart` — OneSignal, permissão de push, External ID e preferências de push.
- `app_notification_service.dart` — central de notificações internas/individuais via Firestore + OneSignal.
- `xp_service.dart` — XP, níveis, conquistas e recompensas.
- `checkin_service.dart` — calendário/check-in e recuperação.
- `purchase_service.dart` — fluxo de compras/in-app purchase.
- `subscription_request_service.dart` — solicitações de assinatura/Premium para aprovação administrativa.
- `avatar_upload_service.dart` / `cloudinary_upload_service.dart` — upload de imagens para Cloudinary.
- `avatar_approval_service.dart` — fila de aprovação de fotos de perfil.
- `app_config_service.dart` — modo manutenção, comentários e configuração da barra de anúncios.
- `deep_link_service.dart` — links/deep links e abertura de matérias.
- `rewarded_ad_service.dart` — anúncios recompensados.
- `sound_service.dart` — sons e preferências de áudio.

---

# 8. Administração — `lib/features/admin/`

## Tela principal

```text
admin_panel_screen.dart
```

O painel possui **11 abas**:

```text
0  Visão geral
1  Comentários
2  Banidos
3  Usuários
4  Visualizações
5  Poderes
6  Notícias
7  Aprovações de avatar
8  Solicitações de assinatura
9  Configurações
10 Barra de anúncios
```

## Abas

```text
screens/tabs/
├── overview_tab.dart
├── comments_tab.dart
├── banned_tab.dart
├── users_tab.dart
├── views_tab.dart
├── poderes_tab.dart
├── news_tab.dart
├── avatar_approvals_tab.dart
├── subscription_requests_tab.dart
├── config_tab.dart
└── ads_bar_tab.dart
```

## Serviços administrativos

```text
admin_avatar_approval_service.dart
admin_comment_service.dart
admin_config_service.dart
admin_dashboard_service.dart
admin_news_service.dart
admin_subscription_request_service.dart
admin_user_service.dart
admin_views_service.dart
push_notification_service.dart
```

## Widgets administrativos

```text
admin_avatar_approval_tile.dart
admin_banned_tile.dart
admin_comment_tile.dart
admin_shared_widgets.dart
admin_subscription_request_tile.dart
admin_user_tile.dart
ban_user_dialog.dart
dashboard_widgets.dart
premium_grant_dialog.dart
video_frame_editor.dart
```

### Administração de usuários atualmente existente

`AdminUserService` já possui suporte para:

- stream dos usuários por `users_xp`;
- acompanhamento de `lastSeenAt`;
- suspender usuário;
- remover suspensão;
- consultar dados brutos do usuário;
- override administrativo de nível;
- restaurar nível real;
- override administrativo de título/tag;
- restaurar título real;
- conceder PRO/ULTRA com data de expiração;
- revogar Premium;
- sincronizar níveis de todos os usuários;
- registrar ações em `admin_logs`.

A `UsersTab` atual ainda é uma listagem relativamente simples com busca por nome/e-mail e cards `AdminUserTile`. Isso é uma área que pode ser expandida sem criar um novo sistema paralelo.

---

# 9. Notícias — fonte atual

O sistema atual **não deve ser descrito como dependente exclusivamente do Blogger**.

A fonte pública atual é:

```text
Firestore → noticias
```

`NewsService` lê somente notícias com:

```text
status == publicado
```

O feed usa:

- stream das notícias recentes;
- paginação por cursor;
- busca normalizada;
- categorias;
- matérias relacionadas;
- suporte a vídeos.

O painel administrativo possui `AdminNewsService` e `NewsEditorScreen`, portanto existe **editor de notícias dentro do painel ADM**.

`BloggerService` permanece no projeto para compatibilidade/importação, mas não deve ser tratado como fonte principal atual sem verificar o código.

---

# 10. Comentários e notificações

Comentários ficam em:

```text
comments/{postId}/postComments/{commentId}
```

Respostas ficam em:

```text
comments/{postId}/postComments/{commentId}/replies/{replyId}
```

Curtidas possuem subcoleções `likes`.

O sistema atual contempla:

- criação;
- respostas;
- edição do próprio comentário;
- curtidas/descurtidas;
- contadores;
- exclusão pelo autor/admin;
- XP relacionado a interações;
- notificações individuais para respostas/curtidas.

---

# 11. Firebase / Firestore

Coleções atualmente referenciadas pelo código/regras:

```text
admins
app_config
users_xp
users
suspensions
banned_users
usernames
avatarApprovals
post_views
post_shares
admin_logs
comments
notifications
presence
subscriptionRequests
noticias
```

Existem também subcoleções, como:

```text
users_xp/{uid}/checkins
post_views/{postId}/viewers
comments/{postId}/postComments/{commentId}/replies
comments/{postId}/postComments/{commentId}/likes
comments/{postId}/postComments/{commentId}/replies/{replyId}/likes
```

A segurança está em:

```text
firestore.rules
```

**Sempre verificar e alterar as regras junto com qualquer mudança de schema ou coleção.**

---

# 12. Integrações externas

### Firebase

- Firebase Core
- Firebase Auth
- Cloud Firestore
- Firebase Analytics

### OneSignal

- Push de notícias.
- Push individual por External ID.
- Notificações relacionadas a comentários/interações.

### Google AdMob

Inicializado no `main.dart` e usado pelo sistema de anúncios.

### Cloudinary

Usado para uploads de imagens de avatar e recursos relacionados.

### Google Play Billing

O projeto possui `in_app_purchase` e `PurchaseService`.

### Blogger

`BloggerService` permanece para compatibilidade/legado. A leitura pública atual de notícias usa `NewsService` + Firestore.

---

# 13. Anúncios

```text
lib/ads/
├── ad_config.dart
└── hybrid_banner_ad.dart
```

A configuração global em `app_config/global` suporta os modos:

```text
admob
partner
off
```

Há também assets de parceiros em:

```text
assets/ads/parceiros/
```

---

# 14. Avatares e perfil

Existem dois sistemas distintos que trabalham juntos:

### Avatar do usuário

```text
app_avatar.dart
avatar_approval_service.dart
avatar_upload_service.dart
```

Fotos podem passar por aprovação administrativa antes de serem publicadas.

### Avatares animados Premium

```text
premium_avatars_config.dart
premium_avatars.dart
premium_avatar_gallery_screen.dart
```

Atualmente existem 6 avatares configurados:

- Nova Aurora
- Fênix Elétrica
- Lobo Espectral
- Cristal Quântico
- Águia Solar
- Serpente Aurora

---

# 15. Widgets reutilizáveis — `lib/widgets/`

```text
app_avatar.dart
app_drawer.dart
avatar_frame.dart
badge_widgets.dart
breaking_news_banner.dart
category_bar.dart
checkin_calendar.dart
comments_section.dart
featured_carousel.dart
level_up_overlay.dart
news_card.dart
notification_bell.dart
post_video_player.dart
premium_avatars.dart
profile_edit_sheets.dart
relative_time_text.dart
subscriber_badge.dart
```

Antes de criar um widget novo, verificar se um desses já pode ser reutilizado.

---

# 16. Utils — `lib/utils/`

```text
blogger_cleaner.dart
cloudinary_url_utils.dart
initials_helper.dart
plain_text_html_converter.dart
search_normalizer.dart
```

---

# 17. Assets

```text
assets/images/icon_app.png
assets/icons/
assets/sounds/ambient.mp3
assets/sounds/click.mp3
assets/sounds/ranking.mp3
assets/ads/parceiros/parceiro_1.png
```

---

# 18. Testes

```text
test/badge_config_test.dart
test/widget_test.dart
test/xp_service_test.dart
```

Ao alterar XP, badges ou comportamento estrutural, verificar os testes correspondentes.

---

# 19. O que NÃO existe

Nesta versão, não assumir que existam os seguintes sistemas:

- sistema de amigos;
- sistema de chat;
- `chat_screen.dart`;
- sistema social de amizade;
- uma tela pública de vídeos independente (`videos_screen.dart`).

**Atenção:** existe `PostVideoPlayer` e existe suporte a vídeos dentro das notícias. Isso não significa que exista uma seção independente de vídeos.

Também **existe editor administrativo de notícias** (`news_editor_screen.dart`), portanto não afirmar que `post_editor_screen.dart` seja necessário ou que o painel não tenha editor.

---

# 20. Regra de manutenção desta documentação

Quando o projeto mudar estruturalmente:

1. atualizar `ESTRUTURA_PROJETO.md`;
2. atualizar `GUIA_DA_IA.md`;
3. confirmar os nomes reais dos arquivos;
4. verificar dependências entre serviços, telas e Firestore;
5. remover da documentação qualquer sistema que tenha sido excluído;
6. não documentar como existente uma função apenas planejada.