# Auditoria Horizonte News — novembro/2026

Documento de acompanhamento da auditoria (segurança, XP, check-in, assinaturas,
notificações, comentários, estatísticas e estabilidade). O que está aqui foi
**feito lendo o código do ZIP**; o que **não foi executado** está marcado.

## 1. Como aplicar (ordem segura)

1. **Backend primeiro** (não muda nada no app ainda): configure o Cloudflare Worker
   e confira `/v1/health` → `cloudflare/horizonte-worker/README.md`.
2. **App novo** (build com `BACKEND_URL` já configurado) → teste com sua conta:
   comentar, responder, curtir, atendimento, check-in, compra de teste.
3. **Publique o app** e espere a maioria dos usuários atualizar.
4. **Só então publique o `firestore.rules`** (Console → Firestore → Regras, ou
   `firebase deploy --only firestore:rules`). As regras novas recusam as formas
   antigas de gravar (comentário sem marca anti-spam, check-in sem data do servidor,
   XP de curtida direto no app…); versões antigas do app perdem esses recursos.
   Antes de publicar, rode os testes das regras (CI) ou use o "Simulador de regras".
5. **Troque a chave REST do OneSignal** (a antiga está dentro dos APKs já publicados).

Enquanto `BACKEND_URL` não existir no build, o app se comporta como antes
(push direto, aprovação manual de assinaturas). Nada em produção muda sozinho.

## 2. Achados

### Bugs confirmados (no código)
| # | Onde | Problema |
|---|---|---|
| B1 | `xp_service.dart` | Tempo online recebia multiplicador de plano (2x/8x) e de evento; a regra é **exatamente 2 XP/min**. |
| B2 | `xp_service.dart` | Nível calculado em cima de total desatualizado → `level` podia não bater com o XP em ações simultâneas. |
| B3 | `xp_service.dart` | Trava anti-duplicação do XP (leitura/compartilhamento) era uma leitura separada → dois toques pagavam duas vezes. |
| B4 | `user_xp_provider.dart` | Minutos online eram perdidos se a gravação falhasse (sem internet); sem limite de tamanho por envio. |
| B5 | `user_xp_provider.dart` | `initialize()` repetia observer/escuta a cada chamada; sem reset no logout (tempo de um usuário podia ir para o próximo). |
| B6 | `checkin_service.dart` | Check-in somava XP sem atualizar o nível. |
| B7 | `checkin_service.dart` | `recoverDay` em **duas etapas** (dia gravado, depois XP/sequência): falha no meio = dia consumido sem XP; não validava "só mês atual" no serviço. |
| B8 | `purchase_service.dart` | Compras só eram processadas ao **abrir a tela Premium**; compra era "concluída" mesmo se o registro falhasse; cada restauração criava outro pedido e outro push. |
| B9 | `subscription_request_service.dart` | O push "novo pedido" aos admins **nunca funcionava para usuário comum** (lê `admins/` sem permissão; erro engolido). |
| B10 | `comments_section.dart` | Trava de "enviando" só era ligada depois de 2 consultas de rede → duplo toque publicava 2×. Resposta + contador em escritas separadas. |
| B11 | `xp_service.dart` | Curtir → descurtir → curtir pagava +5 XP de novo (farm). |
| B12 | `admin_views_service.dart` | Visualização única: leitor e contadores em escritas separadas e sem trava (contagem dupla / inconsistente). |
| B13 | `admin_user_service.dart` | `syncAllUserLevels` falha com mais de 500 usuários (limite do batch) e ignora override de nível. |
| B14 | `admin_dashboard_service.dart`, `users_tab.dart` | Escuta em tempo real da coleção `users_xp` inteira (custo cresce com os usuários). |

### Vulnerabilidades confirmadas (nas regras / no app)
| # | Problema |
|---|---|
| V1 | Dono podia gravar `totalXp`, `level`, `achievements`, estatísticas e missões sem limite (ex.: nível 30 direto). |
| V2 | **Qualquer usuário logado** podia somar +5 XP e trocar o `level` de QUALQUER outro, sem limite. |
| V3 | Campos de override de nível/título de admin editáveis pelo próprio dono. |
| V4 | **E-mail e data de nascimento legíveis por todos** os logados (`users_xp`, `post_views/*/viewers`, coleção legada `users`). |
| V5 | Ranking público mostrava o começo do e-mail de quem não tinha nome. |
| V6 | **Chave REST do OneSignal compilada no APK** (qualquer pessoa poderia mandar push a todos). |
| V7 | Suspensão/banimento só era checado no app (app modificado comentava). |
| V8 | Contadores de curtidas, respostas, visualizações e compartilhamentos incrementáveis sem prova. |
| V9 | Notificações internas forjáveis em massa; a equipe de atendimento era alcançada por **tag** que qualquer usuário podia ativar no próprio aparelho (espiar mensagens). |
| V10 | Check-in aceitava data inventada/futura; XP do check-in não era amarrado ao documento do dia. |
| V11 | Comentário podia exibir nível/conquistas falsos. |
| V12 | `subscriptionRequests` sem validação de campos; `suspensions` legíveis por todos. |

### Possíveis problemas — **não confirmados**
- O comentário antigo do `xp_service.dart` dizia que as regras em produção exigiam `level` igual ao XP;
  o `firestore.rules` do ZIP não exigia. **As regras publicadas podem ser diferentes das do repositório** — confira no Console.
- Não dá para saber daqui se o **App Check está em modo "enforce"** no Firestore.
- Não verifiquei o plano de preços/benefícios no Play Console (produtos `premium_pro_mensal` / `premium_ultra_mensal` foram mantidos).

## 3. O que foi implementado

**Regras do Firestore** (`firestore.rules`, testes em `tests/firestore_rules/`)
- XP: só sobe (+1000 máx. por gravação), `level` ≤ nível permitido pelo XP (tabela idêntica à do app), campos de premium/override só admin/backend, tempo online e conquistas só crescem.
- Ninguém escreve no XP de outra pessoa (o +5 de curtida passou ao backend, com livro-razão anti-farm).
- E-mail/nascimento → `users_private` (dono + admin); `users` legado e `suspensions` fechados; viewers (com e-mail) só dono/admin.
- Check-in: data conferida com o relógio do servidor (±1 dia de fuso), recuperação só de dias passados do mês atual, 10 XP fixos, um documento por dia.
- Comentários: suspensão/ban imposta nas regras; envio em batch com `lastCommentAt` (mín. 10 s: acaba com duplicata e spam); contadores só mudam junto da curtida/resposta; nível/conquistas exibidos precisam bater; campos permitidos listados.
- Visualização única e compartilhamento com prova no mesmo batch; notificações amarradas a curtida/resposta reais; solicitações de assinatura validadas; `billing_purchases` e `xp_ledger` só pelo backend.

**Backend (Cloudflare Worker, `cloudflare/horizonte-worker/`)**
- Push (notícia, resposta, curtida, atendimento, pedido de assinatura, painel, vencimento) — a chave REST só existe lá; o servidor confere o fato no Firestore e quem pode pedir.
- Assinaturas: valida o `purchaseToken` na Google Play Developer API, confere produto e conta (`obfuscatedExternalAccountId`), reconhece a compra, bloqueia token de outra conta, e grava o Premium só depois. Avisos RTDN tratam renovação, cancelamento, reembolso, expiração, PRO+ULTRA simultâneos e não derrubam concessão manual do admin.
- XP de curtida com trava de uma vez por curtida (transação + livro-razão).

**App**
- Tempo online = 2 XP/min **sem** multiplicadores; ganhos de XP em transação (nível sempre coerente) com anti-duplicação atômica.
- Check-in e recuperação atômicos (histórico + sequência + XP + nível), recuperação só do mês atual (`CheckinService.isRecoverableDay`).
- Compras iniciadas no login, reprocessadas ao reiniciar, concluídas só após validação; novas tentativas automáticas; deduplicação no modo manual.
- Comentários: trava imediata, batch atômico, mensagens de erro claras; exclusão de resposta atômica.
- Dados pessoais fora do perfil público (migração automática no login); idade pública só com opt-in.
- Painel admin: e-mails lidos de `users_private`, lista de usuários paginada (300 + "carregar mais"), contagem de online agregada.
- Crashlytics (relatórios de erro em release), CI e workflow de deploy do Worker.

## 4. Testes

| O quê | Situação |
|---|---|
| Backend: 64 testes (`cd cloudflare/horizonte-worker && npm test`) | ✅ **executados aqui — 64/64 passaram** |
| Tabela de níveis (regras = backend = fórmula do app) e IDs de produto | ✅ verificados por script aqui |
| Sintaxe dos testes de regras; delimitadores e funções de `firestore.rules`; delimitadores dos `.dart` alterados; YAML dos workflows | ✅ checados aqui (não substitui compilar nem o emulador) |
| Varredura de controllers/timers/streams sem `dispose`/`cancel` em todo o `lib/` | ✅ feita (heurística): sem pendências além do provider de XP, já corrigido |
| `flutter analyze`, `flutter test` | ⛔ **não executados** (sem Flutter no ambiente). Há testes Dart novos: `checkin_recovery_rules_test.dart` e `backend_contract_test.dart`. |
| Testes das regras no emulador (`rules_hardening.test.js`, 33 testes novos + os antigos) | ⛔ **não executados** (sem emulador/rede). Rode no CI. |
| Integração real com Google Play, OneSignal, Pub/Sub | ⛔ só com as credenciais reais |

O primeiro build após aplicar pode acusar erro de compilação em algum ponto que eu não consegui
compilar — o trecho será indicado pelo próprio log do build.

## 5. Configurações que dependem de você
- Conta Cloudflare + secrets `CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_ACCOUNT_ID` e publicar o Worker.
- 3 segredos do Worker: `ONESIGNAL_REST_API_KEY` (nova), `GOOGLE_SERVICE_ACCOUNT_JSON`, `RTDN_SHARED_SECRET`.
- Play Console: convidar a conta de serviço (permissões de pedidos/assinaturas) e ligar as notificações em tempo real (Pub/Sub).
- Variável do GitHub `BACKEND_URL`.
- Publicar `firestore.rules` (depois do app) e conferir se as regras em produção coincidem com o repositório.
- Revogar a chave antiga do OneSignal.
- Conferir o `firebase_crashlytics` (^4.1.0) na primeira compilação.

## 5b. Pontos de atenção na primeira publicação das regras
- O `firestore.rules` usa `int()` sobre texto e `timestamp.date()` para validar a data do check-in.
  Eu **não consegui rodar o emulador**: se o emulador/Console reclamar dessas linhas (função
  `checkinDay`), é o único ponto de sintaxe que mais merece olhar.
- Rode os testes das regras (CI → "Regras do Firestore") **antes** de publicar.

## 6. Limites conhecidos (não corrigidos)
- **XP continua calculado no aparelho.** As regras limitam o estrago (sem saltos, sem nível falso, sem mexer em conta alheia),
  mas um app adulterado ainda ganha XP "no ritmo máximo por gravação". Eliminar isso exige creditar todo o XP no backend (o Worker já tem a base: `src/xp.js`).
- Versões antigas do app deixam de funcionar em parte com as regras novas (ver "Como aplicar").
- Exclusão de conta ainda percorre toda a árvore de comentários (custo alto) e comentários apagados deixam subcoleções órfãs.
- `loadDashboard()` do painel ainda lê todos os usuários quando o admin pede atualização.
- Unicidade de `username` continua verificada só no app (corrida teórica).
- No modo antigo (sem `BACKEND_URL`) o push de atendimento ainda usa tag do OneSignal.