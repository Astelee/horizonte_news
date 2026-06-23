GUIA_DA_IA.md

Horizonte News - Guia para IA

IMPORTANTE

Antes de criar qualquer arquivo novo:

1. Verifique se já existe um arquivo com função semelhante.
2. Prefira editar arquivos existentes em vez de criar duplicatas.
3. Nunca recrie sistemas já existentes.
4. Sempre respeite a estrutura atual do projeto.
5. Se precisar alterar um sistema, identifique primeiro quais arquivos estão envolvidos.

---

Visão Geral

Horizonte News é um aplicativo Flutter de notícias com:

- Sistema de notícias
- Sistema de usuários
- Sistema de XP e níveis
- Sistema de emblemas
- Sistema de amigos
- Sistema de chat
- Sistema de favoritos
- Painel administrativo
- Integração com Firebase
- Notificações

---

Estrutura Principal

Arquivo Inicial

lib/main.dart

Responsável por:

- Inicializar Firebase
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

admin_provider.dart

Gerencia funções administrativas.

theme_provider.dart

Gerencia tema do aplicativo.

user_xp_provider.dart

Gerencia:

- XP
- Níveis
- Progressão do usuário

---

SISTEMA DE AMIGOS

Todos os arquivos abaixo pertencem ao mesmo sistema.

lib/screens/

amigos_tela.dart
amigos_aba_lista.dart
amigos_aba_pedidos.dart
amigos_aba_conversas.dart
amigos_adicionar.dart
amigos_perfil.dart
amigos_modelos.dart
amigos_widgets.dart

IMPORTANTE:

Não criar versões novas como:

- amigos_v2.dart
- novo_amigos.dart
- social_screen.dart

O sistema já existe.

Sempre reutilizar os arquivos atuais.

---

SISTEMA DE CHAT

Arquivo:

chat_screen.dart

Responsável por:

- Conversas privadas
- Mensagens entre usuários

Antes de alterar o chat verificar integração com:

- Sistema de amigos
- Firebase

---

SISTEMA DE XP

Arquivos principais:

user_xp_provider.dart
xp_service.dart
badge_config.dart
badge_widgets.dart

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
videos_screen.dart
horizon_now_screen.dart
events_screen.dart

Widgets relacionados:

news_card.dart
featured_carousel.dart
breaking_news_banner.dart
category_bar.dart

---

SISTEMA DE COMENTÁRIOS

Arquivo principal:

comments_section.dart

Antes de alterar comentários verificar:

- Perfil do usuário
- Sistema de XP
- Sistema de emblemas

---

PERFIL DO USUÁRIO

Arquivo:

profile_screen.dart

Relacionado com:

- XP
- Emblemas
- Amigos
- Favoritos

Qualquer alteração deve preservar as integrações existentes.

---

FAVORITOS

Arquivos:

favorites_screen.dart
favorites_provider.dart
favorites_service.dart

---

ADMINISTRAÇÃO

Arquivos:

admin_panel_screen.dart
post_editor_screen.dart

Serviços:

admin_service.dart

Funções:

- Gerenciar notícias
- Publicar conteúdo
- Ferramentas administrativas

---

FIREBASE

Serviços:

firebase_service.dart
notification_service.dart

Cloud Functions:

functions/index.js

IMPORTANTE:

Antes de modificar Firebase verificar compatibilidade com:

- Android
- Cloud Functions
- Notificações

---

WIDGETS REUTILIZÁVEIS

Pasta:

lib/widgets/

app_drawer.dart
badge_widgets.dart
breaking_news_banner.dart
category_bar.dart
comments_section.dart
featured_carousel.dart
news_card.dart
relative_time_text.dart

Antes de criar um novo widget verificar se algum destes já resolve o problema.

---

ASSETS

assets/images/

icon_app.png

assets/sounds/

ambient.mp3

assets/icons/

Ícones do aplicativo.

---

REGRA PARA ALTERAÇÕES

Ao implementar qualquer funcionalidade:

1. Identifique os arquivos já existentes.
2. Reutilize componentes existentes.
3. Evite duplicação de código.
4. Não criar versões paralelas do mesmo sistema.
5. Manter compatibilidade com Firebase.
6. Preservar sistema de XP.
7. Preservar sistema de amigos.
8. Preservar sistema de comentários.
9. Preservar sistema de notificações.

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

O projeto já possui:

✓ Sistema de amigos

✓ Sistema de chat

✓ Sistema de XP

✓ Sistema de níveis

✓ Sistema de emblemas

✓ Sistema de favoritos

✓ Sistema de notícias

✓ Sistema administrativo

✓ Firebase

✓ Notificações

A IA deve considerar esses sistemas existentes antes de propor novas implementações.