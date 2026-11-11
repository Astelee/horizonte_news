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
  return {
    productId: item.productId,
    tier: PRODUCT_TIERS[item.productId],
    state,
    expiresAt: validExpiry ? expiresAt : null,
    active: ENTITLED_STATES.has(state) && !!validExpiry && expiresAt.getTime() > nowMs,
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

  async function savePurchase(hash, record, isNew) {
    if (isNew) {
      try {
        await fs.create('billing_purchases', hash, { ...record, createdAt: new Date(now()) });
        return;
      } catch (e) {
        if (!(e instanceof HttpError) || e.status !== 409) throw e;
        const other = await fs.get(`billing_purchases/${hash}`);
        if (other && other.uid !== record.uid) {
          throw new HttpError(409, 'purchase_belongs_to_other_account', 'Esta compra pertence a outra conta.');
        }
      }
    }
    await fs.patch(`billing_purchases/${hash}`, record);
  }

  function toRecord(uid, ent, acknowledged) {
    return {
      uid,
      productId: ent.productId,
      tier: ent.tier,
      state: ent.state,
      active: ent.active,
      expiresAt: ent.expiresAt,
      orderId: ent.orderId,
      autoRenewing: ent.autoRenewing,
      acknowledged,
      testPurchase: ent.testPurchase,
      lastVerifiedAt: new Date(now()),
    };
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
      .filter((p) => p.active === true && p.expiresAt instanceof Date && p.expiresAt.getTime() > t)
      .sort((a, b) => rank(b.tier) - rank(a.tier) || b.expiresAt.getTime() - a.expiresAt.getTime());
    const best = live[0] || null;

    const curTier = rank(user.premiumTier) > 0 ? user.premiumTier : 'none';
    const curExp = user.premiumExpiresAt instanceof Date ? user.premiumExpiresAt : null;
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

      const sub = await play.getSubscription(purchaseToken);
      const ent = parseSubscription(sub, now());
      if (!ent) throw new HttpError(400, 'unknown_product', 'Compra de outro produto.');
      if (ent.productId !== productId) throw new HttpError(400, 'product_mismatch', 'Produto não confere.');
      if (ent.obfuscatedAccountId && ent.obfuscatedAccountId !== uid) {
        throw new HttpError(403, 'purchase_account_mismatch', 'Esta compra foi feita por outra conta.');
      }

      let acknowledged = ent.acknowledged;
      if (!acknowledged && ent.active) acknowledged = await play.acknowledge(ent.productId, purchaseToken);

      await savePurchase(hash, toRecord(uid, ent, acknowledged), !existing);
      const applied = await syncUserEntitlement(uid);

      return {
        ok: true,
        entitled: ent.active,
        tier: ent.active ? ent.tier : 'none',
        expiresAt: ent.expiresAt ? ent.expiresAt.toISOString() : null,
        state: ent.state,
        acknowledged,
        applied: applied.applied === true,
      };
    },

    /** Notificação do Google (RTDN): renovação, cancelamento, reembolso, expiração… */
    async processToken({ purchaseToken, forceRevoke = false }) {
      const hash = await sha256Hex(purchaseToken);
      const existing = await fs.get(`billing_purchases/${hash}`);
      const sub = await play.getSubscription(purchaseToken);
      const ent = parseSubscription(sub, now());
      if (!ent) return { handled: false, reason: 'unknown_product' };

      let uid = existing?.uid || null;
      if (!uid && ent.obfuscatedAccountId) {
        const u = await fs.get(`users_xp/${ent.obfuscatedAccountId}`);
        if (u) uid = ent.obfuscatedAccountId;
      }
      if (!uid) return { handled: false, reason: 'unknown_account' };

      const effective = forceRevoke ? { ...ent, active: false, state: 'SUBSCRIPTION_STATE_VOIDED' } : ent;
      await savePurchase(hash, toRecord(uid, effective, effective.acknowledged), !existing);
      const applied = await syncUserEntitlement(uid);
      return { handled: true, uid, state: effective.state, active: effective.active, applied: applied.applied === true };
    },
  };
}