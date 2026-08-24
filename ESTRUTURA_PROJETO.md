Horizonte News - Estrutura do Projeto
Flutter App

Arquivo Principal
lib/
└── main.dart

Configurações
lib/config/
├── app_colors.dart
├── app_routes.dart
├── app_theme.dart
├── badge_config.dart
└── blogger_config.dart

Features
lib/features/
└── admin/
    ├── models/
    │   └── admin_log_model.dart
    ├── providers/
    │   └── admin_provider.dart
    ├── screens/
    │   ├── admin_panel_screen.dart
    │   └── tabs/
    │       ├── banned_tab.dart
    │       ├── comments_tab.dart
    │       ├── overview_tab.dart
    │       ├── poderes_tab.dart
    │       ├── users_tab.dart
    │       └── views_tab.dart
    ├── services/
    │   ├── admin_comment_service.dart
    │   ├── admin_dashboard_service.dart
    │   ├── admin_user_service.dart
    │   └── admin_views_service.dart
    └── widgets/
        ├── admin_banned_tile.dart
        ├── admin_comment_tile.dart
        ├── admin_shared_widgets.dart
        ├── admin_user_tile.dart
        ├── ban_user_dialog.dart
        ├── dashboard_widgets.dart
        └── poderes_panel.dart

Models
lib/models/
├── category_model.dart
└── post_model.dart

Providers
lib/providers/
├── favorites_provider.dart
├── posts_provider.dart
├── theme_provider.dart
└── user_xp_provider.dart

Screens
lib/screens/

Notícias
├── home_screen.dart
├── post_detail_screen.dart
├── category_screen.dart
├── most_read_screen.dart
├── search_screen.dart
├── favorites_screen.dart
├── horizon_now_screen.dart
└── events_screen.dart

Usuário
├── login_screen.dart
├── register_screen.dart
├── forgot_password_screen.dart
├── profile_screen.dart
└── settings_screen.dart

Outros
├── contact_screen.dart
└── ranking_screen.dart

Services
lib/services/
├── auth_service.dart
├── blogger_service.dart
├── favorites_service.dart
├── notification_service.dart
├── sound_service.dart
└── xp_service.dart

Ads
lib/ads/
├── ad_config.dart
└── hybrid_banner_ad.dart

Widgets
lib/widgets/
├── app_avatar.dart
├── app_drawer.dart
├── avatar_frame.dart
├── badge_widgets.dart
├── breaking_news_banner.dart
├── category_bar.dart
├── comments_section.dart
├── featured_carousel.dart
├── level_up_overlay.dart
├── news_card.dart
└── relative_time_text.dart

Utils
lib/utils/
├── blogger_cleaner.dart
└── initials_helper.dart

Assets
assets/

Imagens
└── images/
    └── icon_app.png

Sons
└── sounds/
    ├── ambient.mp3
    ├── click.mp3
    └── ranking.mp3

Ícones
└── icons/

Anúncios de parceiros
└── ads/
    └── parceiros/
        └── parceiro_1.png

Firebase Functions
functions/
└── index.js

Firestore
firestore.rules

Android
android/
├── build.gradle
├── gradle.properties
├── settings.gradle
├── gradle/
│   └── wrapper/
│       └── gradle-wrapper.properties
└── app/
    ├── build.gradle
    ├── google-services.json
    └── src/
        └── main/
            ├── AndroidManifest.xml
            ├── kotlin/
            │   └── MainActivity.kt
            └── res/
                ├── drawable/
                │   ├── launch_background.xml
                │   └── splash.png
                ├── values/
                │   ├── colors.xml
                │   └── styles.xml
                └── values-v31/
                    └── styles.xml

GitHub Actions
.github/
└── workflows/
    └── build_apk.yml

Testes
test/
└── widget_test.dart

---

NÃO EXISTEM NO PROJETO (não recriar):

- Sistema de amigos (amigos_tela.dart e afins)
- Sistema de chat (chat_screen.dart)
- Tela de vídeos (videos_screen.dart)
- Editor de posts no app (post_editor_screen.dart) — publicação é feita pelo Blogger, não pelo app
- firebase_service.dart, blogger_rss_service.dart, presence_service.dart

Se alguma dessas funcionalidades for pedida no futuro, é uma feature NOVA, não uma correção de algo existente.
