# Horizonte News — Guia para IA

> **Revisado em:** 23/09/2026
>
> Este guia deve ser usado junto com `ESTRUTURA_PROJETO.md`. Ambos foram revisados com base no código atual do projeto.

---

## 1. Regra principal

Antes de criar ou alterar qualquer coisa:

1. Procure primeiro o arquivo e o serviço que já executam a função.
2. Prefira editar/reutilizar código existente.
3. Não crie sistemas paralelos para resolver algo que já existe.
4. Verifique dependências entre tela, provider, service, widget e Firestore.
5. Consulte `ESTRUTURA_PROJETO.md` antes de assumir que um arquivo existe.
6. Se a alteração envolver Firebase, consulte `firestore.rules`.
7. Se a alteração envolver notificações, verifique `notification_service.dart`, `app_notification_service.dart` e os serviços administrativos de push.
8. Se a alteração envolver notícias, verifique `NewsService`, `AdminNewsService` e `PostModel` antes de mexer no Blogger.
9. Preserve as funcionalidades existentes, salvo pedido explícito para removê-las.

---

# 2. Visão geral atual

O Horizonte News é um aplicativo Flutter focado em notícias de Horizonte e região, com:

- feed de notícias em Firestore;
- categorias e busca;
- matérias relacionadas;
- vídeos dentro das matérias;
- usuários via Firebase Auth;
- XP e níveis;
- badges/emblemas;
- ranking;
- check-in diário;
- favoritos;
- comentários e respostas;
- notificações internas e push;
- perfil e avatares;
- avatares animados Premium;
- planos PRO/ULTRA;
- anúncios AdMob/parceiros;
- painel administrativo;
- gerenciamento de notícias dentro do painel ADM;
- moderação de usuários e avatares;
- solicitações de assinatura;
- configurações globais e modo manutenção.

---

# 3. Inicialização — `lib/main.dart`

O `main.dart` é o ponto de entrada.

A sequência atual é:

```text
WidgetsFlutterBinding.ensureInitialized()
        ↓
Firebase.initializeApp()
        ↓
AuthService.enforceRememberPreference()
        ↓
MobileAds.initialize()
NotificationService.init()
SoundService.init()
        ↓
MultiProvider
        ↓
HorizonteNewsApp
        ↓
DeepLinkService.init() após primeiro frame
        ↓
AuthGate
```

### Providers globais

```text
ThemeProvider
PostsProvider
FavoritesProvider
UserXpProvider
AdminProvider
```

Não duplicar esses providers em telas individuais sem necessidade.

### Autenticação

`_AuthGate` verifica `AppConfigService`.

Se o modo manutenção estiver ativo:

- usuário não autenticado → tela de manutenção;
- usuário autenticado que é admin → continua para o app/painel;
- usuário autenticado comum → tela de manutenção.

No fluxo normal:

- autenticado → Home;
- não autenticado → Login.

Ao detectar usuário autenticado, o app também chama:

```text
NotificationService.loginExternalUser(uid)
```

Ao sair da conta:

```text
NotificationService.logoutExternalUser()
```

Não remover esse comportamento ao alterar o fluxo de autenticação.

---

# 4. Notícias — regra importante

## Fonte atual

A fonte principal atual é:

```text
Firestore → noticias
```

O serviço principal é:

```text
lib/services/news_service.dart
```

Ele trabalha com notícias `publicado` e suporta:

- feed ao vivo;
- paginação por cursor;
- categorias;
- busca normalizada;
- busca por palavras;
- matéria por ID;
- matérias relacionadas.

### Admin

O painel possui:

```text
lib/features/admin/services/admin_news_service.dart
lib/features/admin/screens/tabs/news_tab.dart
lib/features/admin/screens/news_editor_screen.dart
```

O administrador pode:

- listar notícias;
- criar;
- editar;
- publicar;
- despublicar;
- excluir;
- reindexar campos de busca.

Ao publicar uma notícia pelo painel, o sistema pode disparar push via `PushNotificationService`.

### Blogger

Existe:

```text
lib/services/blogger_service.dart
lib/config/blogger_config.dart
```

Mas `BloggerService` é legado/compatibilidade/importação. **Não assumir que o feed atual usa Blogger.**

Se alguém pedir uma alteração no sistema de notícias, verificar primeiro `NewsService` e `AdminNewsService`.

---

# 5. Modelo de notícia

Arquivo:

```text
lib/models/post_model.dart
```

O modelo suporta, entre outros dados:

- título;
- resumo;
- conteúdo;
- URL;
- publicação/atualização;
- thumbnail;
- galeria;
- vídeo;
- enquadramento do vídeo;
- categorias;
- status;
- autor.

Status Firestore:

```text
publicado
rascunho
despublicado
```

---

# 6. Busca de notícias

A busca atual usa campos normalizados:

```text
tituloBusca
palavrasBusca
```

O utilitário é:

```text
lib/utils/search_normalizer.dart
```

Existe uma ação administrativa de reindexação para notícias antigas.

Não criar outro mecanismo de busca sem antes verificar esse sistema.

---

# 7. Usuários

O núcleo de progresso fica em:

```text
users_xp/{uid}
```

Também existem:

```text
users/{uid}
usernames/{uid}
admins/{uid}
suspensions/{uid}
banned_users/{uid}
```

Para alterações relacionadas ao usuário, verificar:

```text
lib/services/auth_service.dart
lib/providers/user_xp_provider.dart
lib/services/xp_service.dart
lib/screens/profile_screen.dart
lib/features/admin/services/admin_user_service.dart
```

---

# 8. Painel administrativo

Arquivo principal:

```text
lib/features/admin/screens/admin_panel_screen.dart
```

Abas atuais:

```text
0  Overview
1  Comments
2  Banned
3  Users
4  Views
5  Poderes
6  News
7  Avatar approvals
8  Subscription requests
9  Config
10 Ads bar
```

Não assumir que o painel possui apenas as abas antigas de `overview/users/comments/banned/views/poderes`.

---

# 9. Aba Usuários

Arquivos principais:

```text
lib/features/admin/screens/tabs/users_tab.dart
lib/features/admin/widgets/admin_user_tile.dart
lib/features/admin/services/admin_user_service.dart
```

O serviço já possui:

- listagem em tempo real;
- ordenação por `lastSeenAt`;
- suspensão/desbloqueio;
- dados brutos do usuário;
- alteração administrativa de nível;
- restauração do nível real;
- alteração administrativa de título/tag;
- restauração do título;
- concessão PRO/ULTRA;
- revogação Premium;
- sincronização de níveis;
- logs administrativos.

A `UsersTab` atualmente oferece pesquisa básica e cards de usuários.

Se a aba for ampliada, reutilizar `AdminUserService` e `AdminUserTile`. Não criar um segundo serviço de usuários.

---

# 10. Premium

Configuração central:

```text
lib/config/premium_config.dart
```

Tiers:

```text
none
pro
ultra
```

Os multiplicadores atuais são:

```text
none = 1x
pro  = 2x
ultra = 8x
```

A validade considera `premiumExpiresAt`.

O admin pode conceder/revogar Premium por:

```text
lib/features/admin/services/admin_user_service.dart
```

Não alterar os campos Premium diretamente de uma tela sem respeitar as regras do Firestore.

---

# 11. Avatares

Fotos do usuário:

```text
avatar_upload_service.dart
avatar_approval_service.dart
admin_avatar_approval_service.dart
```

O fluxo de foto envolve aprovação administrativa.

Avatares animados Premium:

```text
config/premium_avatars_config.dart
widgets/premium_avatars.dart
screens/premium_avatar_gallery_screen.dart
```

Catálogo atual:

- Nova Aurora
- Fênix Elétrica
- Lobo Espectral
- Cristal Quântico
- Águia Solar
- Serpente Aurora

---

# 12. XP, níveis e check-in

Arquivos principais:

```text
lib/services/xp_service.dart
lib/providers/user_xp_provider.dart
lib/config/badge_config.dart
lib/widgets/badge_widgets.dart
lib/widgets/level_up_overlay.dart
lib/services/checkin_service.dart
lib/screens/checkin_screen.dart
lib/widgets/checkin_calendar.dart
```

Antes de alterar nível/XP:

1. verificar `XpService`;
2. verificar `UserXpProvider`;
3. verificar `firestore.rules`;
4. verificar testes de XP;
5. verificar overrides administrativos.

O painel administrativo possui sincronização de níveis.

---

# 13. Comentários

Arquivo visual principal:

```text
lib/widgets/comments_section.dart
```

Admin:

```text
lib/features/admin/services/admin_comment_service.dart
lib/features/admin/screens/tabs/comments_tab.dart
```

Estrutura:

```text
comments/{postId}/postComments/{commentId}
  ├── replies/{replyId}
  └── likes/{likerId}
```

Respostas possuem suas próprias curtidas.

O sistema atual suporta:

- comentários;
- respostas;
- edição do próprio comentário;
- curtidas;
- contadores;
- notificações;
- exclusão pelo autor/admin;
- XP por interações.

Ao alterar comentários, conferir também as regras do Firestore.

---

# 14. Notificações

Existem dois níveis:

### OneSignal

```text
lib/services/notification_service.dart
lib/features/admin/services/push_notification_service.dart
```

Usado para push.

### Notificações internas

```text
lib/services/app_notification_service.dart
lib/models/notification_model.dart
lib/screens/notifications_screen.dart
```

A coleção é:

```text
notifications
```

O sistema também usa External ID do OneSignal baseado no UID do Firebase para direcionamento individual.

Não remover o login/logout do OneSignal do `_AuthenticatedGate`.

---

# 15. Configuração global

Arquivo:

```text
lib/services/app_config_service.dart
```

Documento:

```text
app_config/global
```

Configurações atuais:

- `maintenanceMode`;
- `maintenanceMessage`;
- `commentsEnabled`;
- `adsBarMode`;
- `adsPartnerName`;
- `adsPartnerImageUrl`;
- `adsPartnerLinkUrl`.

Modos de anúncio:

```text
admob
partner
off
```

---

# 16. Firestore

Antes de criar/alterar uma coleção:

1. procure a coleção no código;
2. procure a coleção em `firestore.rules`;
3. confira quem pode ler/escrever;
4. confira se existem subcoleções;
5. atualize as regras junto com o schema, se necessário.

Coleções principais atuais:

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

Subcoleções importantes:

```text
users_xp/{uid}/checkins
post_views/{postId}/viewers
comments/{postId}/postComments/{commentId}/replies
comments/{postId}/postComments/{commentId}/likes
comments/{postId}/postComments/{commentId}/replies/{replyId}/likes
```

---

# 17. Cloud Functions

**Não existe `functions/` neste pacote atual.**

Não criar ou documentar Cloud Functions como se já existissem.

Pushes administrativos e individuais atualmente são tratados pelos serviços Flutter/OneSignal existentes.

---

# 18. Uploads e mídia

Cloudinary:

```text
avatar_upload_service.dart
cloudinary_upload_service.dart
cloudinary_url_utils.dart
```

Vídeos:

```text
widgets/post_video_player.dart
features/admin/widgets/video_frame_editor.dart
```

Existe suporte a vídeo dentro das matérias, mas **não existe uma tela pública independente de vídeos**.

---

# 19. Rotas atuais

Definidas em:

```text
lib/config/app_routes.dart
```

Rotas principais:

```text
/
/category
/post-detail
/search
/favorites
/contact
/settings
/login
/register
/forgot-password
/profile
/admin-panel
/most-read
/horizon-now
/events
/ranking
/checkin
/premium
/premium-avatars
/notifications
```

Ao criar uma tela nova, verificar primeiro se a navegação existente pode ser reutilizada.

---

# 20. Sistemas que NÃO existem

Não assumir que existam:

- sistema de amigos;
- sistema de chat;
- `chat_screen.dart`;
- sistema social de amizade;
- `videos_screen.dart` como tela independente.

Existe suporte a vídeo em notícias, então não confundir as duas coisas.

Também existe editor de notícias no painel administrativo:

```text
news_editor_screen.dart
```

Portanto, não afirmar que o projeto não possui editor administrativo.

---

# 21. Regra para alterações

Ao implementar uma funcionalidade:

1. Identifique os arquivos existentes.
2. Reutilize services/providers/widgets existentes.
3. Evite duplicação.
4. Não crie uma segunda fonte de verdade para o mesmo dado.
5. Preserve Firebase/Auth/Firestore.
6. Preserve XP e níveis.
7. Preserve comentários e respostas.
8. Preserve notificações.
9. Preserve Premium/assinaturas.
10. Preserve aprovação de avatares.
11. Não altere regras de segurança sem verificar o impacto.
12. Se houver alteração de schema Firestore, atualize `firestore.rules`.
13. Se houver alteração no fluxo de notícias, verifique `NewsService` e `AdminNewsService`.
14. Se houver alteração na autenticação, verifique `main.dart`, `AuthService` e OneSignal.

---

# 22. Regra para resposta da IA

Antes de executar uma alteração relevante, informar de forma objetiva:

- arquivos que serão alterados;
- motivo de cada alteração;
- impacto esperado;
- dependências afetadas;
- se há mudança no Firestore;
- se há mudança nas regras.

Depois da alteração, informar:

- arquivos efetivamente alterados;
- funcionalidades implementadas;
- limitações/dados que não existem atualmente;
- necessidade ou não de alteração no Firebase.

Não afirmar que uma função foi implementada se ela apenas foi planejada.

---

# 23. Princípio final

**O código atual é a fonte de verdade.**

Se este guia, `ESTRUTURA_PROJETO.md` e o código entrarem em conflito, primeiro verificar o código e depois atualizar a documentação.