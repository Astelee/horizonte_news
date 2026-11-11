# Backend seguro do Horizonte News (Cloudflare Workers)

Faz três coisas que **não podem ficar dentro do app**:

1. **Push via OneSignal** — a chave REST do OneSignal passa a existir só aqui.
   Antes ela era compilada dentro do APK (qualquer pessoa conseguia extraí-la e
   mandar notificação para todos os usuários).
2. **Validação das assinaturas PRO/ULTRA** na Google Play Developer API: o Premium
   só é liberado depois que o Google confirma a compra; renovação, cancelamento,
   reembolso e expiração chegam por avisos do Google (RTDN).
3. **XP de curtida recebida** (+5 ao autor), com trava de "uma vez por curtida".

Roda no **plano gratuito** da Cloudflare (100 mil requisições/dia). Nenhuma etapa
abaixo é feita automaticamente: **o app continua funcionando como hoje até você
configurar o `BACKEND_URL`** (ver "Ordem segura").

## Rotas

| Rota | Quem chama | O que faz |
|---|---|---|
| `POST /v1/notify/news` | admin | push de notícia publicada (confere admin e status) |
| `POST /v1/notify/comment` | quem respondeu/curtiu | push de resposta/curtida (confere o fato no Firestore) |
| `POST /v1/notify/support` | usuário ou atendente | push do atendimento (equipe = `support_config/agents.notifyUids`) |
| `POST /v1/notify/subscription-request` | usuário | avisa admins de pedido de assinatura (modo manual) |
| `POST /v1/notify/admin` · `tier-tag` | admin | push manual do painel / tag de plano |
| `POST /v1/notify/premium-expiry` | o próprio usuário | aviso "assinatura vence em até 3 dias" |
| `POST /v1/billing/verify` | usuário | valida a compra no Google Play e libera o Premium |
| `POST /v1/billing/rtdn?secret=…` | Google (Pub/Sub) | renovação / cancelamento / reembolso / expiração |
| `POST /v1/xp/like` | quem curtiu | credita o XP da curtida ao autor |
| `GET /v1/health` | qualquer um | mostra o que está configurado (sem revelar valores) |

Todas (menos health e rtdn) exigem o **ID token do Firebase** em `Authorization: Bearer …`;
o `uid` vem do token, nunca do corpo da requisição.

## Passo a passo (tudo pelo celular dá para fazer)

### 1. Conta e Worker
1. Crie uma conta gratuita em cloudflare.com.
2. Gere um **API Token** (My Profile → API Tokens → modelo "Edit Cloudflare Workers") e copie
   também o **Account ID** (página inicial da conta).
3. No GitHub do projeto: *Settings → Secrets and variables → Actions → Secrets* →
   crie `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`.
4. *Actions → "Publicar backend seguro (Cloudflare Worker)" → Run workflow.*
   Isso roda os testes e publica. A URL final aparece no painel da Cloudflare
   (Workers & Pages → `horizonte-news-api`), algo como
   `https://horizonte-news-api.SEU-USUARIO.workers.dev`.

### 2. Segredos do Worker (3)
Cadastre no painel da Cloudflare (Worker → *Settings → Variables and Secrets → Add → Secret*)
**ou** como secrets do GitHub com o prefixo `WORKER_` (o workflow envia por você).

| Segredo | Valor |
|---|---|
| `ONESIGNAL_REST_API_KEY` | **uma chave NOVA** do OneSignal (veja o passo 6) |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | o JSON inteiro de uma conta de serviço (passo 3) |
| `RTDN_SHARED_SECRET` | um texto aleatório longo (você inventa; use o mesmo no passo 5) |

Confira com `https://SUA-URL/v1/health` — deve mostrar `onesignal`, `googleServiceAccount` e
`rtdn` como `true`.

### 3. Conta de serviço do Google (Firestore + Google Play)
1. Google Cloud Console → projeto do Firebase (`horizontenews-6b48f`) → *IAM e administrador →
   Contas de serviço*. Pode usar a conta "firebase-adminsdk-…" ou criar uma nova com o papel
   **Cloud Datastore User** (leitura/escrita do Firestore). Gere uma **chave JSON**.
2. Ative a API **Google Play Android Developer API** nesse mesmo projeto (APIs e serviços → Biblioteca).
3. Play Console → *Usuários e permissões → Convidar usuários*: convide o e-mail da conta de serviço
   com as permissões **"Ver informações do app"** e **"Gerenciar pedidos e assinaturas"**.
   (O convite pode levar algumas horas para valer.)

### 4. App: ligar o backend
1. GitHub → *Settings → Secrets and variables → Actions → aba **Variables*** → crie
   `BACKEND_URL` = a URL do Worker (sem barra no final).
2. Gere o app normalmente (*Compilar Flutter*). Com `BACKEND_URL` presente o build **não leva mais**
   a chave REST do OneSignal.

### 5. Avisos em tempo real do Google (renovação, cancelamento, reembolso)
Play Console → *Monetização → Configurações de monetização → Notificações em tempo real do
desenvolvedor*: crie um tópico do Pub/Sub (o Console ensina), dê permissão de *publisher* a
`google-play-developer-notifications@system.gserviceaccount.com`, crie uma **assinatura Push**
apontando para
`https://SUA-URL/v1/billing/rtdn?secret=SEU_RTDN_SHARED_SECRET` e use "Enviar notificação de teste".
Sem esta etapa o Premium é liberado na compra e renovado quando o usuário abre o app, mas
reembolso/expiração só chegam ao Firestore quando o app reverifica.

### 6. Trocar a chave do OneSignal (importante)
A chave antiga já está dentro dos APKs publicados. Depois de ligar o backend: OneSignal →
*Settings → Keys & IDs* → gere uma chave nova, cadastre-a no Worker (passo 2) e **revogue a antiga**.
Apague também o secret `ONESIGNAL_REST_API_KEY` do GitHub.

## Ordem segura (não quebra produção)
1. Publicar o Worker e cadastrar segredos → conferir `/v1/health`.
2. Testar com um build próprio (com `BACKEND_URL`): comentar/curtir/responder, atendimento, comprar
   com uma conta de teste de licença do Play.
3. Só então publicar o app para todos e, **depois** de a maioria atualizar, publicar o
   `firestore.rules` novo (versões antigas do app deixam de funcionar com as regras novas).
4. Trocar a chave do OneSignal (passo 6).

## Desenvolvimento
```bash
npm test          # 60+ testes, sem dependências (Node 20+)
npx wrangler dev  # roda local
```
Os testes cobrem: verificação do ID token, permissões de cada rota, validação de compra
(fraude, renovação, cancelamento, reembolso, PRO+ULTRA), RTDN e XP de curtida.
**Não** conversam com Google/OneSignal de verdade — isso só dá para validar com as credenciais reais.