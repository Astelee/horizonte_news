// Envio de notificações push. Cada rota confere no Firestore (via conta de
// serviço) que o evento realmente aconteceu e que quem pede tem permissão.
// O app só informa IDs — título, texto e destinatário saem dos documentos.

import { HttpError, deterministicUuid, requireDocId, requireString, truncate } from './util.js';

const TIERS = ['none', 'pro', 'ultra'];
const TIER_LABEL = { pro: 'PRO', ultra: 'ULTRA' };
const EXPIRY_WINDOW_MS = 3 * 24 * 60 * 60 * 1000;

function publicResult(r) {
  return { ok: r.ok, id: r.id ?? null, recipients: r.recipients ?? null, message: r.message ?? null };
}

function normalizeName(value) {
  return String(value ?? '').replace(/^@/, '').trim().toLowerCase();
}

export function createNotifyHandlers({ fs, onesignal, now = () => Date.now() }) {
  async function isAdmin(uid) {
    return (await fs.get(`admins/${uid}`)) !== null;
  }

  async function requireAdmin(uid) {
    if (!(await isAdmin(uid))) throw new HttpError(403, 'forbidden', 'Apenas administradores.');
  }

  // Mesmo critério das regras do Firestore (isSupportAgent).
  async function isSupportAgent(uid) {
    if (!(await isAdmin(uid))) return false;
    const agents = await fs.get('support_config/agents');
    if (!agents) return true;
    return Array.isArray(agents.agentUids) && agents.agentUids.includes(uid);
  }

  async function adminUids() {
    return (await fs.list('admins', 100)).map((d) => d.id);
  }

  async function displayNameOf(uid) {
    const u = await fs.get(`users_xp/${uid}`);
    const display = String(u?.displayName ?? '').trim();
    const username = String(u?.username ?? '').trim();
    return display || username || 'Leitor';
  }

  return {
    /** Notícia publicada → todos os inscritos. Só administrador. */
    async news(caller, body) {
      const postId = requireDocId(body.postId, 'postId');
      await requireAdmin(caller.uid);

      const post = await fs.get(`noticias/${postId}`);
      if (!post) throw new HttpError(404, 'not_found', 'Notícia não encontrada.');
      if (post.status !== 'publicado') {
        throw new HttpError(409, 'not_published', 'A notícia não está publicada.');
      }

      let category = '';
      if (typeof post.categoria === 'string' && post.categoria.trim()) category = post.categoria.trim();
      else if (Array.isArray(post.categorias) && post.categorias.length) category = String(post.categorias[0]);

      let image = typeof post.capaUrl === 'string' ? post.capaUrl.trim() : '';
      if (!image && typeof body.imageUrl === 'string' && /^https:\/\//.test(body.imageUrl) && body.imageUrl.length < 1000) {
        image = body.imageUrl;
      }
      const publishedMs = post.publicadoEm instanceof Date ? post.publicadoEm.getTime() : 0;

      const result = await onesignal.send({
        included_segments: ['All'],
        headings: { en: category ? category.toUpperCase() : 'HORIZONTE NEWS' },
        contents: { en: truncate(post.titulo || 'Nova notícia', 200) },
        big_picture: image || undefined,
        data: { postId },
        idempotency_key: await deterministicUuid(`news|${postId}|${publishedMs}`),
      });
      return publicResult(result);
    },

    /** Resposta ou curtida em comentário → push individual ao destinatário. */
    async comment(caller, body) {
      const kind = body.kind;
      if (kind !== 'reply' && kind !== 'like') throw new HttpError(400, 'invalid_request', 'kind inválido.');
      const postId = requireDocId(body.postId, 'postId');
      const commentId = requireDocId(body.commentId, 'commentId');
      const replyId = body.replyId ? requireDocId(body.replyId, 'replyId') : null;

      const commentPath = `comments/${postId}/postComments/${commentId}`;
      const data = { kind: 'comment', postId, commentId, ...(replyId ? { replyId } : {}) };

      if (kind === 'reply') {
        if (!replyId) throw new HttpError(400, 'invalid_request', 'replyId é obrigatório.');
        const recipient = requireDocId(body.recipientUserId, 'recipientUserId');
        if (recipient === caller.uid) return { ok: true, skipped: 'self' };

        const reply = await fs.get(`${commentPath}/replies/${replyId}`);
        if (!reply) throw new HttpError(404, 'not_found', 'Resposta não encontrada.');
        if (reply.userId !== caller.uid) throw new HttpError(403, 'forbidden', 'A resposta não é sua.');
        const parent = await fs.get(commentPath);
        if (!parent) throw new HttpError(404, 'not_found', 'Comentário não encontrado.');

        let allowed = recipient === parent.userId;
        if (!allowed && reply.replyToUsername) {
          const target = await fs.get(`users_xp/${recipient}`);
          const wanted = normalizeName(reply.replyToUsername);
          allowed =
            !!target &&
            wanted !== '' &&
            (normalizeName(target.username) === wanted || normalizeName(target.displayName) === wanted);
        }
        if (!allowed) throw new HttpError(403, 'recipient_mismatch', 'Destinatário não confere.');

        const actor = String(reply.username ?? '').trim() || String(reply.userName ?? '').trim() || 'Leitor';
        const result = await onesignal.send({
          include_aliases: { external_id: [recipient] },
          target_channel: 'push',
          headings: { en: actor },
          contents: { en: `respondeu ao seu comentário: ${truncate(reply.text, 120)}` },
          data,
          idempotency_key: await deterministicUuid(`reply|${postId}|${replyId}`),
        });
        return publicResult(result);
      }

      // like
      const targetPath = replyId ? `${commentPath}/replies/${replyId}` : commentPath;
      const target = await fs.get(targetPath);
      if (!target) throw new HttpError(404, 'not_found', 'Comentário não encontrado.');
      const like = await fs.get(`${targetPath}/likes/${caller.uid}`);
      if (!like) throw new HttpError(403, 'like_not_found', 'Curtida não encontrada.');
      const recipient = String(target.userId ?? '');
      if (!recipient) throw new HttpError(404, 'not_found', 'Autor não encontrado.');
      if (recipient === caller.uid) return { ok: true, skipped: 'self' };

      const result = await onesignal.send({
        include_aliases: { external_id: [recipient] },
        target_channel: 'push',
        headings: { en: await displayNameOf(caller.uid) },
        contents: { en: 'curtiu seu comentário' },
        data,
        idempotency_key: await deterministicUuid(`like|${postId}|${commentId}|${replyId ?? '-'}|${caller.uid}`),
      });
      return publicResult(result);
    },

    /** Mensagem do atendimento → equipe (se o usuário escreveu) ou usuário (se o atendente respondeu). */
    async support(caller, body) {
      const conversationId = requireDocId(body.conversationId, 'conversationId');
      const messageId = requireDocId(body.messageId, 'messageId');

      const message = await fs.get(`support_conversations/${conversationId}/messages/${messageId}`);
      if (!message) throw new HttpError(404, 'not_found', 'Mensagem não encontrada.');
      if (message.senderId !== caller.uid) throw new HttpError(403, 'forbidden', 'A mensagem não é sua.');

      const conversation = (await fs.get(`support_conversations/${conversationId}`)) || {};
      const publicCfg = (await fs.get('support_config/public')) || {};
      const preview = truncate(message.text, 100);

      if (message.senderRole === 'agent') {
        if (!(await isSupportAgent(caller.uid))) throw new HttpError(403, 'forbidden', 'Apenas atendentes.');
        // Mesmo padrão do app (SupportConversation.hidePreview): oculta, a não ser que seja false.
        const hide = conversation.hidePreview !== false;
        const result = await onesignal.send({
          include_aliases: { external_id: [conversationId] },
          target_channel: 'push',
          headings: { en: 'Atendimento Horizonte News' },
          contents: { en: hide ? 'Você recebeu uma resposta do atendimento' : preview },
          data: { kind: 'support', conversationId, messageId },
          idempotency_key: await deterministicUuid(`support|${messageId}|${conversationId}`),
          collapse_id: `support_${conversationId}`,
        });
        return publicResult(result);
      }

      if (message.senderRole !== 'user' || caller.uid !== conversationId) {
        throw new HttpError(403, 'forbidden', 'Remetente inválido.');
      }
      // Equipe = notifyUids (ou, na falta, os atendentes/admins). Mira os
      // UIDs direto — não depende de tag no aparelho, que o próprio
      // usuário poderia ativar para espiar as mensagens.
      const agents = await fs.get('support_config/agents');
      let team = [];
      if (agents && Array.isArray(agents.notifyUids) && agents.notifyUids.length) team = agents.notifyUids;
      else if (agents && Array.isArray(agents.agentUids)) team = agents.agentUids;
      else team = await adminUids();
      team = team.filter((u) => typeof u === 'string' && u && u !== caller.uid);
      if (!team.length) return { ok: false, id: null, recipients: 0, message: 'Equipe sem destinatários.' };

      // Mesmo padrão do app (SupportPublicConfig.hidePreviewAgent): oculta, a não ser que seja false.
      const hide = publicCfg.hidePreviewAgent !== false;
      const who = String(conversation.userName ?? '').trim() || 'Usuário';
      const result = await onesignal.send({
        include_aliases: { external_id: team },
        target_channel: 'push',
        headings: { en: hide ? 'Atendimento Horizonte News' : `${who} · Atendimento` },
        contents: { en: hide ? 'Você tem uma nova mensagem no atendimento' : preview },
        data: { kind: 'support', conversationId, messageId },
        idempotency_key: await deterministicUuid(`support|${messageId}|team`),
        collapse_id: `support_${conversationId}`,
      });
      return publicResult(result);
    },

    /** Pedido de assinatura (fluxo manual) → avisa os administradores. */
    async subscriptionRequest(caller, body) {
      const requestId = requireDocId(body.requestId, 'requestId');
      const request = await fs.get(`subscriptionRequests/${requestId}`);
      if (!request) throw new HttpError(404, 'not_found', 'Solicitação não encontrada.');
      if (request.uid !== caller.uid) throw new HttpError(403, 'forbidden', 'A solicitação não é sua.');
      if (request.status !== 'pendente') return { ok: true, skipped: 'not_pending' };

      const admins = (await adminUids()).filter((u) => u !== caller.uid);
      if (!admins.length) return { ok: false, id: null, recipients: 0, message: 'Sem administradores.' };

      const plan = TIER_LABEL[request.plan] || String(request.plan || '').toUpperCase();
      const name = truncate(request.userName || 'Usuário', 60);
      const result = await onesignal.send({
        include_aliases: { external_id: admins },
        target_channel: 'push',
        headings: { en: 'Nova solicitação de assinatura' },
        contents: { en: `${name} solicitou o plano ${plan}.` },
        data: { kind: 'subscription_request', requestId },
        idempotency_key: await deterministicUuid(`subreq|${requestId}`),
      });
      return publicResult(result);
    },

    /** Push manual do painel (um usuário ou todos). Só administrador. */
    async admin(caller, body) {
      await requireAdmin(caller.uid);
      const title = requireString(body.title, 'title', { min: 1, max: 100 });
      const text = requireString(body.body, 'body', { min: 1, max: 500 });
      const data = {};
      if (body.data && typeof body.data === 'object') {
        for (const [k, v] of Object.entries(body.data).slice(0, 10)) data[String(k).slice(0, 40)] = String(v).slice(0, 200);
      }
      let target;
      if (body.target === 'user') {
        const uid = requireDocId(body.uid, 'uid');
        target = { include_aliases: { external_id: [uid] }, target_channel: 'push' };
      } else if (body.target === 'all') {
        target = { included_segments: ['All'] };
      } else {
        throw new HttpError(400, 'invalid_request', 'target inválido.');
      }
      const result = await onesignal.send({
        ...target,
        headings: { en: title },
        contents: { en: text },
        ...(Object.keys(data).length ? { data } : {}),
      });
      return publicResult(result);
    },

    /** Atualiza a tag `tier` de um usuário. Só administrador. */
    async tierTag(caller, body) {
      await requireAdmin(caller.uid);
      const uid = requireDocId(body.uid, 'uid');
      if (!TIERS.includes(body.tier)) throw new HttpError(400, 'invalid_request', 'tier inválido.');
      const ok = await onesignal.setTierTag(uid, body.tier);
      return { ok };
    },

    /** Aviso "assinatura perto de vencer" — só para o próprio usuário. */
    async premiumExpiry(caller) {
      const user = await fs.get(`users_xp/${caller.uid}`);
      if (!user) throw new HttpError(404, 'not_found', 'Usuário não encontrado.');
      const tier = user.premiumTier;
      const expires = user.premiumExpiresAt instanceof Date ? user.premiumExpiresAt : null;
      if (!TIER_LABEL[tier] || !expires) return { ok: true, skipped: 'no_subscription' };
      if (user.premiumTrial === true) return { ok: true, skipped: 'trial' };
      const remaining = expires.getTime() - now();
      if (remaining <= 0 || remaining > EXPIRY_WINDOW_MS) return { ok: true, skipped: 'outside_window' };

      const label = new Intl.DateTimeFormat('pt-BR', {
        timeZone: 'America/Sao_Paulo',
        day: '2-digit',
        month: '2-digit',
      }).format(expires);
      const result = await onesignal.send({
        include_aliases: { external_id: [caller.uid] },
        target_channel: 'push',
        headings: { en: 'Sua assinatura está perto de vencer' },
        contents: {
          en: `Sua assinatura ${TIER_LABEL[tier]} vence em ${label}. Renove para continuar aproveitando seus benefícios.`,
        },
        data: { kind: 'premium_promo' },
        idempotency_key: await deterministicUuid(`premium_expiry|${caller.uid}|${expires.getTime()}`),
      });
      return publicResult(result);
    },
  };
}