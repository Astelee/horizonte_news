import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBilling, parseSubscription } from '../src/billing.js';
import { sha256Hex } from '../src/util.js';
import { fakeFirestore } from './helpers.js';

const NOW = Date.parse('2026-11-03T12:00:00Z');
const DAY = 86_400_000;
const iso = (ms) => new Date(ms).toISOString();
const TOKEN_PRO = 'token-pro-0123456789abcdef';
const TOKEN_ULTRA = 'token-ultra-0123456789abcdef';

const sub = ({ productId = 'premium_pro_mensal', state = 'SUBSCRIPTION_STATE_ACTIVE', expiry = NOW + 20 * DAY, acked = false, account = 'userA' } = {}) => ({
  subscriptionState: state,
  acknowledgementState: acked ? 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED' : 'ACKNOWLEDGEMENT_STATE_PENDING',
  latestOrderId: 'GPA.1',
  lineItems: [{ productId, expiryTime: iso(expiry), autoRenewingPlan: { autoRenewEnabled: true } }],
  ...(account ? { externalAccountIdentifiers: { obfuscatedExternalAccountId: account } } : {}),
});

function setup(subs, seed = {}) {
  const fs = fakeFirestore({ 'users_xp/userA': { totalXp: 100 }, 'users_xp/userB': {}, ...seed });
  const acks = [];
  const play = {
    async getSubscription(token) {
      if (!subs[token]) {
        const { HttpError } = await import('../src/util.js');
        throw new HttpError(404, 'purchase_not_found', 'x');
      }
      return subs[token];
    },
    async acknowledge(productId, token) {
      acks.push([productId, token]);
      return true;
    },
  };
  return { fs, acks, billing: createBilling({ fs, play, now: () => NOW }) };
}
const code = (c) => (e) => e.code === c;

test('parseSubscription: estados que dão benefício e estados que não dão', () => {
  assert.equal(parseSubscription(sub(), NOW).active, true);
  assert.equal(parseSubscription(sub({ state: 'SUBSCRIPTION_STATE_CANCELED' }), NOW).active, true); // cancelou, mas pagou até o fim
  assert.equal(parseSubscription(sub({ state: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' }), NOW).active, true);
  assert.equal(parseSubscription(sub({ state: 'SUBSCRIPTION_STATE_ON_HOLD' }), NOW).active, false);
  assert.equal(parseSubscription(sub({ state: 'SUBSCRIPTION_STATE_PAUSED' }), NOW).active, false);
  assert.equal(parseSubscription(sub({ state: 'SUBSCRIPTION_STATE_EXPIRED' }), NOW).active, false);
  assert.equal(parseSubscription(sub({ state: 'SUBSCRIPTION_STATE_PENDING' }), NOW).active, false);
  assert.equal(parseSubscription(sub({ expiry: NOW - 1000 }), NOW).active, false); // venceu
  assert.equal(parseSubscription(sub({ productId: 'outro_produto' }), NOW), null);
  assert.equal(parseSubscription(sub({ productId: 'premium_ultra_mensal' }), NOW).tier, 'ultra');
});

test('compra válida: confirma no Google, reconhece (acknowledge) e libera o Premium', async () => {
  const { billing, fs, acks } = setup({ [TOKEN_PRO]: sub() });
  const r = await billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });
  assert.equal(r.ok, true);
  assert.equal(r.entitled, true);
  assert.equal(r.tier, 'pro');
  assert.deepEqual(acks, [['premium_pro_mensal', TOKEN_PRO]]);

  const user = fs.docs.get('users_xp/userA');
  assert.equal(user.premiumTier, 'pro');
  assert.equal(user.premiumExpiresAt.getTime(), NOW + 20 * DAY);
  assert.equal(user.premiumSource, 'play');
  assert.equal(user.totalXp, 100); // não mexe no XP

  const hash = await sha256Hex(TOKEN_PRO);
  const rec = fs.docs.get(`billing_purchases/${hash}`);
  assert.equal(rec.uid, 'userA');
  assert.equal(rec.active, true);
  assert.equal(JSON.stringify(rec).includes(TOKEN_PRO), false); // o token em si não é guardado
});

test('repetir a verificação (reinício do app / restaurar) não duplica nada', async () => {
  const { billing, fs, acks } = setup({ [TOKEN_PRO]: sub({ acked: true }) });
  await billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });
  const again = await billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });
  assert.equal(again.entitled, true);
  assert.equal(acks.length, 0); // já estava reconhecida
  assert.equal([...fs.docs.keys()].filter((k) => k.startsWith('billing_purchases/')).length, 1);
});

test('fraude: token de outra conta, outro usuário usando o mesmo token e produto trocado', async () => {
  const { billing } = setup({ [TOKEN_PRO]: sub({ account: 'userA' }) });
  // comprado pela conta A, mas B tenta ativar
  await assert.rejects(() => billing.verifyForUser({ uid: 'userB', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO }), code('purchase_account_mismatch'));
  // A ativa; depois B tenta reusar o mesmo token já vinculado
  await billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });
  await assert.rejects(() => billing.verifyForUser({ uid: 'userB', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO }), code('purchase_belongs_to_other_account'));
  // diz que comprou ULTRA mas o token é de PRO
  await assert.rejects(() => billing.verifyForUser({ uid: 'userA', productId: 'premium_ultra_mensal', purchaseToken: TOKEN_PRO }), code('product_mismatch'));
  // produto inexistente / token inventado
  await assert.rejects(() => billing.verifyForUser({ uid: 'userA', productId: 'premium_gratis', purchaseToken: TOKEN_PRO }), code('unknown_product'));
  await assert.rejects(() => billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: 'token-inventado-123456' }), code('purchase_not_found'));
  await assert.rejects(() => billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: 'curto' }), code('invalid_request'));
});

test('compra pendente / em espera NÃO libera Premium e não é reconhecida', async () => {
  const { billing, fs, acks } = setup({ [TOKEN_PRO]: sub({ state: 'SUBSCRIPTION_STATE_PENDING' }) });
  const r = await billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });
  assert.equal(r.entitled, false);
  assert.equal(r.tier, 'none');
  assert.equal(acks.length, 0);
  assert.equal(fs.docs.get('users_xp/userA').premiumTier, undefined);
});

test('compra sem applicationUserName (sem conta no Google) é vinculada a quem confirmou primeiro', async () => {
  const { billing } = setup({ [TOKEN_PRO]: sub({ account: null }) });
  await billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });
  await assert.rejects(() => billing.verifyForUser({ uid: 'userB', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO }), code('purchase_belongs_to_other_account'));
});

test('concessão manual melhor (ULTRA do admin) não é rebaixada por uma compra PRO', async () => {
  const { billing, fs } = setup({ [TOKEN_PRO]: sub() }, {
    'users_xp/userA': { premiumTier: 'ultra', premiumExpiresAt: new Date(NOW + 60 * DAY) },
  });
  await billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });
  assert.equal(fs.docs.get('users_xp/userA').premiumTier, 'ultra');
  assert.equal(fs.docs.get('users_xp/userA').premiumSource, undefined);
});

test('cortesia de teste (PRO 3 dias) é substituída por assinatura paga e perde a marca de teste', async () => {
  const { billing, fs } = setup({ [TOKEN_ULTRA]: sub({ productId: 'premium_ultra_mensal' }) }, {
    'users_xp/userA': { premiumTier: 'pro', premiumExpiresAt: new Date(NOW + 2 * DAY), premiumTrial: true },
  });
  await billing.verifyForUser({ uid: 'userA', productId: 'premium_ultra_mensal', purchaseToken: TOKEN_ULTRA });
  const u = fs.docs.get('users_xp/userA');
  assert.equal(u.premiumTier, 'ultra');
  assert.equal(u.premiumTrial, undefined);
});

test('RTDN — renovação estende a validade', async () => {
  const subs = { [TOKEN_PRO]: sub() };
  const { billing, fs } = setup(subs);
  await billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });
  subs[TOKEN_PRO] = sub({ expiry: NOW + 50 * DAY, acked: true });
  const r = await billing.processToken({ purchaseToken: TOKEN_PRO });
  assert.equal(r.handled, true);
  assert.equal(fs.docs.get('users_xp/userA').premiumExpiresAt.getTime(), NOW + 50 * DAY);
});

test('RTDN — cancelamento mantém o benefício até o fim do período pago', async () => {
  const subs = { [TOKEN_PRO]: sub() };
  const { billing, fs } = setup(subs);
  await billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });
  subs[TOKEN_PRO] = sub({ state: 'SUBSCRIPTION_STATE_CANCELED' });
  await billing.processToken({ purchaseToken: TOKEN_PRO });
  assert.equal(fs.docs.get('users_xp/userA').premiumTier, 'pro');
});

test('RTDN — expiração e reembolso (voided) removem o Premium comprado', async () => {
  const subs = { [TOKEN_PRO]: sub() };
  const { billing, fs } = setup(subs);
  await billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });

  subs[TOKEN_PRO] = sub({ state: 'SUBSCRIPTION_STATE_EXPIRED', expiry: NOW - DAY });
  await billing.processToken({ purchaseToken: TOKEN_PRO });
  let u = fs.docs.get('users_xp/userA');
  assert.equal(u.premiumTier, undefined);
  assert.equal(u.premiumExpiresAt, undefined);
  assert.equal(u.totalXp, 100);

  // reembolso: mesmo que a API ainda mostre ACTIVE, forceRevoke derruba
  const again = setup({ [TOKEN_PRO]: sub() });
  await again.billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });
  await again.billing.processToken({ purchaseToken: TOKEN_PRO, forceRevoke: true });
  u = again.fs.docs.get('users_xp/userA');
  assert.equal(u.premiumTier, undefined);
});

test('RTDN — expiração NÃO derruba concessão manual do admin', async () => {
  const subs = { [TOKEN_PRO]: sub({ state: 'SUBSCRIPTION_STATE_EXPIRED', expiry: NOW - DAY }) };
  const { billing, fs } = setup(subs, {
    'users_xp/userA': { premiumTier: 'pro', premiumExpiresAt: new Date(NOW + 30 * DAY) }, // sem premiumSource
    [`billing_purchases/${await sha256Hex(TOKEN_PRO)}`]: { uid: 'userA', active: true, expiresAt: new Date(NOW + DAY), tier: 'pro' },
  });
  await billing.processToken({ purchaseToken: TOKEN_PRO });
  assert.equal(fs.docs.get('users_xp/userA').premiumTier, 'pro');
});

test('PRO e ULTRA ao mesmo tempo: quando o ULTRA vence, o PRO continua valendo', async () => {
  const subs = { [TOKEN_PRO]: sub({ expiry: NOW + 25 * DAY }), [TOKEN_ULTRA]: sub({ productId: 'premium_ultra_mensal', expiry: NOW + 5 * DAY }) };
  const { billing, fs } = setup(subs);
  await billing.verifyForUser({ uid: 'userA', productId: 'premium_pro_mensal', purchaseToken: TOKEN_PRO });
  await billing.verifyForUser({ uid: 'userA', productId: 'premium_ultra_mensal', purchaseToken: TOKEN_ULTRA });
  assert.equal(fs.docs.get('users_xp/userA').premiumTier, 'ultra');
  subs[TOKEN_ULTRA] = sub({ productId: 'premium_ultra_mensal', state: 'SUBSCRIPTION_STATE_EXPIRED', expiry: NOW - 1000 });
  await billing.processToken({ purchaseToken: TOKEN_ULTRA });
  const u = fs.docs.get('users_xp/userA');
  assert.equal(u.premiumTier, 'pro');
  assert.equal(u.premiumExpiresAt.getTime(), NOW + 25 * DAY);
});

test('RTDN de compra desconhecida (sem conta) é ignorada sem erro', async () => {
  const { billing } = setup({ [TOKEN_PRO]: sub({ account: null }) });
  const r = await billing.processToken({ purchaseToken: TOKEN_PRO });
  assert.equal(r.handled, false);
  assert.equal(r.reason, 'unknown_account');
});

test('RTDN com obfuscatedAccountId conhecido cria o vínculo sozinho', async () => {
  const { billing, fs } = setup({ [TOKEN_PRO]: sub({ account: 'userA' }) });
  const r = await billing.processToken({ purchaseToken: TOKEN_PRO });
  assert.equal(r.handled, true);
  assert.equal(fs.docs.get('users_xp/userA').premiumTier, 'pro');
});