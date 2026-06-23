# Horizonte News - Estrutura do Projeto

## Flutter App

### Arquivo Principal
lib/main.dart

---

## Configurações

lib/config/
├── app_colors.dart
├── app_routes.dart
├── app_theme.dart
├── badge_config.dart
└── blogger_config.dart

---

## Models

lib/models/
├── category_model.dart
└── post_model.dart

---

## Providers

lib/providers/
├── admin_provider.dart
├── favorites_provider.dart
├── posts_provider.dart
├── theme_provider.dart
└── user_xp_provider.dart

---

## Screens

lib/screens/

### Sistema de Amigos
├── amigos_tela.dart
├── amigos_aba_lista.dart
├── amigos_aba_pedidos.dart
├── amigos_aba_conversas.dart
├── amigos_adicionar.dart
├── amigos_perfil.dart
├── amigos_modelos.dart
└── amigos_widgets.dart

### Notícias
├── home_screen.dart
├── post_detail_screen.dart
├── category_screen.dart
├── most_read_screen.dart
├── search_screen.dart
├── favorites_screen.dart
├── videos_screen.dart
├── horizon_now_screen.dart
└── events_screen.dart

### Usuário
├── login_screen.dart
├── register_screen.dart
├── forgot_password_screen.dart
├── profile_screen.dart
├── settings_screen.dart

### Administração
├── admin_panel_screen.dart
├── post_editor_screen.dart

### Outros
├── chat_screen.dart
└── contact_screen.dart

---

## Services

lib/services/
├── admin_service.dart
├── blogger_service.dart
├── favorites_service.dart
├── firebase_service.dart
├── notification_service.dart
└── xp_service.dart

---

## Widgets

lib/widgets/
├── app_drawer.dart
├── badge_widgets.dart
├── breaking_news_banner.dart
├── category_bar.dart
├── comments_section.dart
├── featured_carousel.dart
├── news_card.dart
└── relative_time_text.dart

---

## Utils

lib/utils/
└── blogger_cleaner.dart

---

## Assets

assets/

### Imagens
├── images/icon_app.png

### Sons
├── sounds/ambient.mp3

### Ícones
└── icons/

---

## Firebase Functions

functions/
└── index.js

---

## Android

android/
├── build.gradle
├── gradle.properties
├── settings.gradle
├── gradle/wrapper/
│   └── gradle-wrapper.properties
└── app/
    ├── build.gradle
    ├── google-services.json
    └── src/main/
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

---

## GitHub Actions

.github/workflows/
└── build_apk.yml

---

## Testes

test/
└── widget_test.dart