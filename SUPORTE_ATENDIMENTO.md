# Atendimento privado (usuário ↔ equipe Horizonte News)

Chat de texto privado dentro do app, sem criar login, cadastro nem painel novos:
usa Firebase Auth, Firestore, Provider e OneSignal que o projeto já tem.

## Decisão de arquitetura: push saindo do próprio app (plano gratuito)

Não há Cloud Functions nem outro backend. Cada envio grava, no MESMO batch, a
mensagem e o resumo da conversa; só depois da confirmação do servidor o app de
quem enviou dispara o push pelo OneSignal (como já era feito para comentários).

O que isso garante: histórico, contadores e "não lidas" vêm do Firestore e
funcionam mesmo com push desativado; reenviar a mesma mensagem não duplica
mensagem nem push (ID da mensagem gerado no aparelho + `idempotency_key`).

O que isso NÃO garante (limites reais, sem backend):

- **A chave REST do OneSignal continua dentro do APK** (`ONESIGNAL_REST_API_KEY`
  via dart-define, como antes). Quem extrair o APK consegue enviar push. Tirar a
  chave do app exige um backend (Cloud Functions no plano Blaze, ou um serviço
  gratuito como Cloudflare Workers). Não foi feito.
- **O push depende do app de quem envia estar vivo** no momento do envio. Se o
  app fechar entre gravar e disparar, a mensagem existe, mas o push não sai.
- **Sem limite por minuto/hora no servidor.** As regras do Firestore impõem
  tamanho máximo (2000), remetente correto, contador +1 e intervalo mínimo de
  2 s entre envios. Spam em volume só seria barrado por um backend; use
  "Bloquear envio no atendimento" para abuso.
- **Privacidade do push:** como não há verificação de identidade do OneSignal,
  alguém que forje o External ID/tag no próprio aparelho poderia receber o push
  de outra pessoa. Por isso o padrão é **ocultar o conteúdo** na notificação
  ("Você tem uma nova mensagem no atendimento"); o texto só aparece dentro do app.
- O push para a equipe usa a tag `support_agent=1`, aplicada no aparelho do admin
  quando ele abre o app. Remover alguém de "Push" só vale no aparelho dele depois
  que abrir o app de novo.
- Android pode atrasar ou descartar notificações (economia de bateria, permissão
  negada). Entrega não é garantida.

## Publicar (ordem importa)

1. Copie os arquivos para o projeto com os mesmos caminhos.
2. **Índices:** `firebase deploy --only firestore:indexes` (ou crie no console os 2
   índices de `support_conversations` listados em `firestore.indexes.json`).
3. **Regras:** `firebase deploy --only firestore:rules`. A leitura pública geral
   (`match /{document=**}`) foi removida: o que não tem regra explícita agora é
   negado. Regras explícitas foram criadas para `noticias`, `comments/{postId}` e
   consultas de grupo `postComments`/`replies`. Teste logo depois: abrir notícias
   sem login, comentários, ranking, check-in, painel ADM (aba Comentários) e
   excluir conta.
4. Gere o APK pelo GitHub Actions como de costume (nenhum segredo novo).
5. No app, entre com a conta ADM → Painel → aba **Atendimento** → ícone de
   ajustes: marque quem **atende** e quem recebe **push** (a lista vem de
   `admins/`; nenhum UID é digitado), escreva boas-vindas e aviso fora do
   horário, defina o horário. Salve. Enquanto não salvar, todo admin atende e
   recebe (modo inicial).
6. Abra o app com cada admin que deve receber push (aplica a tag no aparelho).

## Onde fica cada coisa

- Usuário: botão "Fale conosco" (telas principais), menu lateral → Atendimento,
  Fale Conosco → "Conversar com a equipe", central de notificações e sino
  (contam não lidas).
- ADM: mesmo botão/menu abre Painel → Atendimento; aba com filtros, busca,
  fixar, resolver/reabrir, respostas rápidas, ajustes; perfil do usuário →
  "Enviar mensagem" (abre a MESMA conversa `support_conversations/{uid}`).
- Bloquear envio no atendimento é separado da suspensão/banimento do app.

## Banco

`support_conversations/{uid}` (ID = UID do usuário, nunca duplica) e
`.../messages/{id}` (imutáveis). `support_config/public` (boas-vindas, horário,
legível por logados), `support_config/agents` (quem atende/recebe, só admins) e
`support_quick_replies`. Leitura "lida" é por horário na conversa
(`userReadAt`/`agentReadAt`), então contador do botão = 1 documento.

Custos de Firestore: cada mensagem = 2 escritas; cada abertura do chat = leitura
da conversa + 30 mensagens; o contador do botão é 1 listener. Atendentes pagam
reads extras nas regras (`exists`/`get` de `admins` e `support_config/agents`).
Dentro da cota gratuita para volume baixo; acompanhe em Uso do Firebase.

## Testes

Scripts em `tests/firestore_rules/` (emulador do Firestore; 2 contas comuns, 1
ADM, sem login): `cd tests/firestore_rules && npm install && npm test`.
**Estado em que foram entregues: escritos, NÃO executados** (sem Flutter nem
emulador no ambiente onde o código foi gerado), e o app **não foi compilado**.
Roteiro manual obrigatório depois do build: envio nos dois sentidos, conversa
iniciada pelo ADM, mensagem recebida durante a leitura, modo avião → reconectar,
trocar de conta com o chat aberto, toque no push com o app fechado.

## Segunda etapa (não implementada): fotos, áudios e vídeos

Proposta: Firebase Storage com caminho privado `support/{uid}/{messageId}/{arquivo}`,
regras de Storage só para o dono e ADM, sem URL pública permanente (baixar por
token curto), limites (foto 5 MB, áudio 2 min, vídeo 30 s/25 MB), upload antes do
batch da mensagem e campo `attachment` (path, tipo, tamanho) validado nas regras.
Storage exige o plano Blaze para criar buckets novos; confirme antes.