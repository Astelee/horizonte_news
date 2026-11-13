// Validação de assinaturas do Google Play (PRO / ULTRA) e liberação do
// Premium. REGRA DE OURO: o Premium só é gravado depois que a Google Play
// Developer API confirma a compra. O app apenas entrega o purchaseToken.
//
// Fonte da verdade: coleção `billing_purchases/{sha256(purchaseToken)}`
// (negada a qualquer cliente pelas regras do Firestore — só este Worker
// escreve). O plano do usuário (users_xp.premiumTier / premiumExpiresAt) é
// SEMPRE derivado dessas compras, então renovação, cancelamento,
// reembolso e expiração convergem para o mesmo cálculo.

import { HttpError, requireString, sha256Hex } from './util.js';

// IDs de produto = os mesmos do Play Console e do app (PremiumProductIds).
export const PRODUCT_TIERS = {
  premium_pro_mensal: 'pro',
  premium_ultra_mensal: 'ultra',
};

const TIER_RANK = { none: 0, pro: 1, ultra: 2 };
// Estados em que o usuário mantém o benefício (até o fim do período pago).
const ENTITLED_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_CANCELED',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

// Prazo máximo em que uma assinatura "em espera" (pagamento falhou) ainda
// pode ser recuperada pelo usuário na Google Play.
const ON_HOLD_MAX_MS = 30 * 86_400_000;

const ANDROID_PUBLISHER = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const PLAY_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

/** Extrai da resposta `subscriptionsv2` o que importa para o benefício. */
export function parseSubscription(sub, nowMs) {
  const items = Array.isArray(sub?.lineItems) ? sub.lineItems : [];
  const item = items.find((li) => PRODUCT_TIERS[li?.productId]);
  if (!item) return null;
  const expiresAt = item.expiryTime ? new Date(item.expiryTime) : null;
  const state = String(sub.subscriptionState || '');
  const validExpiry = expiresAt && !Number.isNaN(expiresAt.getTime());
  const active = ENTITLED_STATES.has(state) && !!validExpiry && expiresAt.getTime() > nowMs;
  // "Ocupa a vaga": enquanto a assinatura existir (ativa, cancelada mas paga,
  // carência ou em espera) nenhuma OUTRA assinatura pode ser contratada.
  const onHold = state === 'SUBSCRIPTION_STATE_ON_HOLD' && !!validExpiry && nowMs < expiresAt.getTime() + ON_HOLD_MAX_MS;
  const holdUntil = active ? expiresAt : onHold ? new Date(expiresAt.getTime() + ON_HOLD_MAX_MS) : null;
  const started = sub.startTime ? new Date(sub.startTime) : null;
  return {
    startedAt: started && !Number.isNaN(started.getTime()) ? started : null,
    holdsSlot: holdUntil !== null,
    holdUntil,
    productId: item.productId,
    tier: PRODUCT_TIERS[item.productId],
    state,
    expiresAt: validExpiry ? expiresAt : null,
    active,
    autoRenewing: item.autoRenewingPlan?.autoRenewEnabled === true,
    acknowledged: sub.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
    obfuscatedAccountId: sub.externalAccountIdentifiers?.obfuscatedExternalAccountId || null,
    orderId: sub.latestOrderId || null,
    testPurchase: !!sub.testPurchase,
  };
}

export function createPlayClient({ packageName, getToken, fetchImpl = fetch }) {
  async function authed(method, url) {
    const token = await getToken([PLAY_SCOPE]);
    return fetchImpl(url, {
      method,
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: method === 'POST' ? '{}' : undefined,
    });
  }

  return {
    async getSubscription(purchaseToken) {
      const url = `${ANDROID_PUBLISHER}/${packageName}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
      const res = await authed('GET', url);
      if (res.ok) return res.json();
      if (res.status === 400) throw new HttpError(400, 'invalid_purchase_token', 'Compra inválida.');
      if (res.status === 404 || res.status === 410) {
        throw new HttpError(404, 'purchase_not_found', 'Compra não encontrada no Google Play.');
      }
      if (res.status === 401 || res.status === 403) {
        throw new HttpError(502, 'play_permission_denied', 'A conta de serviço não tem acesso ao Google Play (ver README).');
      }
      throw new HttpError(502, 'play_unavailable', `Google Play indisponível (${res.status}).`);
    },

    async acknowledge(productId, purchaseToken) {
      const url = `${ANDROID_PUBLISHER}/${packageName}/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
      try {
        const res = await authed('POST', url);
        return res.ok;
      } catch {
        return false;
      }
    },
  };
}

export function createBilling({ fs, play, now = () => Date.now() }) {
  const rank = (tier) => TIER_RANK[tier] ?? 0;
  const isDate = (d) => d instanceof Date && !Number.isNaN(d.getTime());

  function toRecord(uid, ent, { acknowledged, voided = false, blocked = null, fetchedAt }) {
    const holds = ent.holdsSlot && !voided && !blocked;
    return {
      uid,
      productId: ent.productId,
      tier: ent.tier,
      state: voided ? 'SUBSCRIPTION_STATE_VOIDED' : ent.state,
      active: ent.active && !voided && !blocked,
      expiresAt: ent.expiresAt,
      startedAt: ent.startedAt,
      orderId: ent.orderId,
      autoRenewing: ent.autoRenewing,
      acknowledged,
      testPurchase: ent.testPurchase,
      holdsSlot: holds,
      holdUntil: holds ? ent.holdUntil : null,
      voided,
      blocked,
      fetchedAt,
      lastVerifiedAt: new Date(now()),
    };
  }

  /** Grava a compra. Um evento ATRASADO (buscado antes do que já está salvo) nunca sobrescreve um mais novo. */
  async function savePurchase(hash, record, isNew) {
    const path = `billing_purchases/${hash}`;
    if (isNew) {
      try {
        await fs.create('billing_purchases', hash, { ...record, createdAt: new Date(now()) });
        return;
      } catch (e) {
        if (!(e instanceof HttpError) || e.status !== 409) throw e;
        const other = await fs.get(path);
        if (other && other.uid !== record.uid) {
          throw new HttpError(409, 'purchase_belongs_to_other_account', 'Esta compra pertence a outra conta.');
        }
      }
    }
    await fs.runTransaction([path], (docs) => {
      const cur = docs[path];
      if (cur && isDate(cur.fetchedAt) && cur.fetchedAt.getTime() > record.fetchedAt.getTime()) return [];
      // compra reembolsada/revogada nunca volta a valer
      const data = cur?.voided === true ? { ...record, active: false, holdsSlot: false, holdUntil: null, voided: true, state: 'SUBSCRIPTION_STATE_VOIDED' } : record;
      return [{ type: 'update', path, data }];
    });
  }

  /**
   * Vaga única de assinatura por usuário (billing_slots/{uid}), reservada em
   * TRANSAÇÃO: duas compras simultâneas não conseguem ocupar a vaga juntas.
   */
  async function claimSlot(uid, hash, ent) {
    const path = `billing_slots/${uid}`;
    for (let attempt = 0; attempt < 3; attempt++) {
      let holderTier = null;
      const data = { hash, tier: ent.tier, holdUntil: ent.holdUntil, updatedAt: new Date(now()) };
      try {
        await fs.runTransaction([path], (docs) => {
          const slot = docs[path];
          if (!slot) return [{ type: 'create', path, data }];
          const taken = slot.hash !== hash && isDate(slot.holdUntil) && slot.holdUntil.getTime() > now();
          if (taken) {
            holderTier = slot.tier || 'pro';
            return [];
          }
          return [{ type: 'update', path, data }];
        });
      } catch (e) {
        if (e instanceof HttpError && e.status === 409) continue; // outra requisição criou antes: reavalia
        throw e;
      }
      return holderTier ? { granted: false, holderTier } : { granted: true };
    }
    return { granted: false, holderTier: 'pro' };
  }

  async function releaseSlot(uid, hash) {
    const slot = await fs.get(`billing_slots/${uid}`);
    if (slot && slot.hash === hash && isDate(slot.holdUntil) && slot.holdUntil.getTime() > now()) {
      await fs.patch(`billing_slots/${uid}`, { holdUntil: new Date(now()), updatedAt: new Date(now()) });
    }
  }

  /** Decide se a compra pode valer (vaga única), grava e recalcula o plano. */
  async function applyPurchase({ uid, hash, token, ent, existing, voided, fetchedAt, enforce }) {
    let blocked = null;
    let holderTier = null;
    if (ent.holdsSlot && !voided) {
      const r = await claimSlot(uid, hash, ent);
      // Compras antigas já registradas (legado) não são bloqueadas; só as novas
      // ou as que já tinham sido recusadas antes.
      if (!r.granted && (enforce || existing?.blocked)) {
        blocked = 'exclusive_subscription';
        holderTier = r.holderTier;
      }
    } else {
      await releaseSlot(uid, hash);
    }

    let acknowledged = ent.acknowledged;
    // Compra recusada NÃO é reconhecida: o Google a estorna sozinho em até 3 dias.
    if (!acknowledged && ent.active && !voided && !blocked) acknowledged = await play.acknowledge(ent.productId, token);

    const record = toRecord(uid, ent, { acknowledged, voided, blocked, fetchedAt });
    await savePurchase(hash, record, !existing);
    const applied = await syncUserEntitlement(uid);
    return { record, blocked, holderTier, acknowledged, applied };
  }

  /**
   * Recalcula o plano do usuário a partir das compras dele e grava em
   * users_xp. Nunca rebaixa uma concessão manual (cortesia/admin) melhor.
   */
  async function syncUserEntitlement(uid) {
    const user = await fs.get(`users_xp/${uid}`);
    if (!user) return { applied: false, reason: 'user_missing' };

    const t = now();
    const purchases = await fs.query('billing_purchases', [['uid', uid]], 50);
    const live = purchases
      .filter((p) => p.active === true && !p.blocked && !p.voided && isDate(p.expiresAt) && p.expiresAt.getTime() > t)
      .sort((a, b) => rank(b.tier) - rank(a.tier) || b.expiresAt.getTime() - a.expiresAt.getTime());
    const best = live[0] || null;

    const curTier = rank(user.premiumTier) > 0 ? user.premiumTier : 'none';
    const curExp = isDate(user.premiumExpiresAt) ? user.premiumExpiresAt : null;
    const curActive = curTier !== 'none' && curExp !== null && curExp.getTime() > t;
    const fromPlay = user.premiumSource === 'play';

    if (best) {
      if (curActive && !fromPlay) {
        const better =
          rank(best.tier) > rank(curTier) ||
          (rank(best.tier) === rank(curTier) && best.expiresAt.getTime() > curExp.getTime());
        if (!better) return { applied: false, reason: 'manual_grant_kept' };
      }
      await fs.patch(
        `users_xp/${uid}`,
        {
          premiumTier: best.tier,
          premiumExpiresAt: best.expiresAt,
          premiumSource: 'play',
          premiumPurchaseHash: best.id,
        },
        { deleteFields: ['premiumTrial'], mustExist: true },
      );
      return { applied: true, tier: best.tier, expiresAt: best.expiresAt };
    }

    if (fromPlay) {
      await fs.patch(
        `users_xp/${uid}`,
        {},
        {
          deleteFields: ['premiumTier', 'premiumExpiresAt', 'premiumSource', 'premiumPurchaseHash', 'premiumTrial'],
          mustExist: true,
        },
      );
      return { applied: true, revoked: true };
    }
    return { applied: false, reason: 'nothing_to_do' };
  }

  return {
    syncUserEntitlement,

    /** Chamado pelo app logo após a compra / restauração / reinício. */
    async verifyForUser({ uid, productId, purchaseToken }) {
      if (!PRODUCT_TIERS[productId]) throw new HttpError(400, 'unknown_product', 'Produto desconhecido.');
      requireString(purchaseToken, 'purchaseToken', { min: 10, max: 1500 });

      const hash = await sha256Hex(purchaseToken);
      const existing = await fs.get(`billing_purchases/${hash}`);
      if (existing && existing.uid !== uid) {
        throw new HttpError(409, 'purchase_belongs_to_other_account', 'Esta compra pertence a outra conta.');
      }

      const fetchedAt = new Date(now());
      const sub = await play.getSubscription(purchaseToken);
      const ent = parseSubscription(sub, now());
      if (!ent) throw new HttpError(400, 'unknown_product', 'Compra de outro produto.');
      if (ent.productId !== productId) throw new HttpError(400, 'product_mismatch', 'Produto não confere.');
      if (ent.obfuscatedAccountId && ent.obfuscatedAccountId !== uid) {
        throw new HttpError(403, 'purchase_account_mismatch', 'Esta compra foi feita por outra conta.');
      }

      const r = await applyPurchase({
        uid, hash, token: purchaseToken, ent, existing,
        voided: existing?.voided === true, fetchedAt, enforce: !existing,
      });
      if (r.blocked) {
        throw new HttpError(
          409,
          'subscription_already_active',
          `Você já tem uma assinatura ${String(r.holderTier).toUpperCase()} em vigor. Esta nova compra não foi ativada e será estornada pelo Google Play.`,
        );
      }
      const entitled = r.record.active;
      return {
        ok: true,
        entitled,
        tier: entitled ? ent.tier : 'none',
        expiresAt: ent.expiresAt ? ent.expiresAt.toISOString() : null,
        state: r.record.state,
        acknowledged: r.acknowledged,
        applied: r.applied.applied === true,
      };
    },

    /** Notificação do Google (RTDN): renovação, cancelamento, reembolso, expiração… */
    async processToken({ purchaseToken, forceRevoke = false }) {
      const hash = await sha256Hex(purchaseToken);
      const existing = await fs.get(`billing_purchases/${hash}`);
      const fetchedAt = new Date(now());
      const sub = await play.getSubscription(purchaseToken);
      const ent = parseSubscription(sub, now());
      if (!ent) return { handled: false, reason: 'unknown_product' };

      let uid = existing?.uid || null;
      if (!uid && ent.obfuscatedAccountId) {
        const u = await fs.get(`users_xp/${ent.obfuscatedAccountId}`);
        if (u) uid = ent.obfuscatedAccountId;
      }
      if (!uid) return { handled: false, reason: 'unknown_account' };

      const voided = forceRevoke || existing?.voided === true;
      const r = await applyPurchase({ uid, hash, token: purchaseToken, ent, existing, voided, fetchedAt, enforce: !existing });
      return { handled: true, uid, state: r.record.state, active: r.record.active, blocked: r.blocked, applied: r.applied.applied === true };
    },

    /** Estado da assinatura do usuário para o app ("Minha assinatura" e trava de compra). */
    async statusForUser(uid) {
      const t = now();
      const user = await fs.get(`users_xp/${uid}`);
      const purchases = await fs.query('billing_purchases', [['uid', uid]], 50);
      const holds = (p) =>
        !p.blocked && !p.voided &&
        (p.holdsSlot === true ? isDate(p.holdUntil) && p.holdUntil.getTime() > t
          : p.holdsSlot === undefined && p.active === true && isDate(p.expiresAt) && p.expiresAt.getTime() > t);
      const cur = purchases
        .filter(holds)
        .sort((a, b) => rank(b.tier) - rank(a.tier) || (b.expiresAt?.getTime() || 0) - (a.expiresAt?.getTime() || 0))[0];

      const iso = (d) => (isDate(d) ? d.toISOString() : null);
      let subscription = null;
      if (cur) {
        const live = cur.active === true && isDate(cur.expiresAt) && cur.expiresAt.getTime() > t;
        subscription = {
          tier: cur.tier,
          state: cur.state,
          benefitsActive: live,
          startedAt: iso(cur.startedAt),
          expiresAt: iso(cur.expiresAt),
          autoRenewing: cur.autoRenewing === true,
          cancelScheduled: live && (cur.state === 'SUBSCRIPTION_STATE_CANCELED' || cur.autoRenewing === false),
          inGracePeriod: cur.state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
          onHold: cur.state === 'SUBSCRIPTION_STATE_ON_HOLD',
        };
      }
      const manual =
        user && user.premiumSource !== 'play' && rank(user.premiumTier) > 0 && isDate(user.premiumExpiresAt) && user.premiumExpiresAt.getTime() > t
          ? { tier: user.premiumTier, expiresAt: iso(user.premiumExpiresAt), trial: user.premiumTrial === true }
          : null;
      return { ok: true, blocksPurchase: !!cur, subscription, manualGrant: manual };
    },
  };
}