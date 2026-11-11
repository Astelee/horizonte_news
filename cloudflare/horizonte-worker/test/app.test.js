import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/index.js';
import { makeTokenIssuer } from './helpers.js';
import { bytesToBase64, utf8 } from '../src/util.js';

async function setup(envOverrides = {}) {
  const { issue, verifier } = await makeTokenIssuer();
  const calls = { notify: [], billing: [], rtdn: [], xp: [] };
  const notify = new Proxy({}, {
    get: (_t, name) => async (caller, body) => {
      calls.notify.push([String(name), caller.uid, body]);
      return { ok: true };
    },
  });
  const billing = {
    async verifyForUser(args) {
      calls.billing.push(args);
      return { ok: true, entitled: true, tier: 'pro' };
    },
    async processToken(args) {
      calls.rtdn.push(args);
      return { handled: true };
    },
  };
  const xp = { async like(caller, body) { calls.xp.push([caller.uid, body]); return { ok: true, credited: true }; } };
  const env = { ANDROID_PACKAGE_NAME: 'com.astelee.horizonte_news', RTDN_SHARED_SECRET: 's3gredo', ...envOverrides };
  const app = createApp({ env, verifyIdToken: verifier, notify, billing, xp });
  const post = (path, body, headers = {}) =>
    app(new Request(`https://api.test${path}`, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: typeof body === 'string' ? body : JSON.stringify(body ?? {}) }));
  const authed = async (path, body, uid = 'userA') => post(path, body, { authorization: `Bearer ${await issue({ sub: uid })}` });
  return { app, post, authed, calls, issue };
}
const pubsub = (obj) => ({ message: { data: bytesToBase64(utf8(JSON.stringify(obj))) } });

test('health informa o que está configurado, sem vazar valores', async () => {
  const { app } = await setup({ ONESIGNAL_REST_API_KEY: 'segredo-os' });
  const res = await app(new Request('https://api.test/v1/health'));
  const body = await res.json();
  assert.equal(res.status, 200);
  assert.deepEqual(body.configured, { onesignal: true, googleServiceAccount: false, rtdn: true });
  assert.equal(JSON.stringify(body).includes('segredo-os'), false);
});

test('sem token → 401; token inválido → 401; rota inexistente → 404; método errado → 405', async () => {
  const { post, app } = await setup();
  assert.equal((await post('/v1/notify/news', { postId: 'x' })).status, 401);
  assert.equal((await post('/v1/notify/news', { postId: 'x' }, { authorization: 'Bearer lixo' })).status, 401);
  assert.equal((await post('/v1/billing/verify', {})).status, 401);
  assert.equal((await post('/v1/nada', {})).status, 404);
  assert.equal((await app(new Request('https://api.test/v1/notify/news'))).status, 405);
});

test('o uid vem do TOKEN — um uid enviado no corpo é ignorado', async () => {
  const { authed, calls } = await setup();
  const res = await authed('/v1/notify/comment', { kind: 'like', postId: 'p', commentId: 'c', uid: 'adminUid', callerUid: 'adminUid' }, 'userA');
  assert.equal(res.status, 200);
  assert.equal(calls.notify[0][0], 'comment');
  assert.equal(calls.notify[0][1], 'userA');
  const v = await authed('/v1/billing/verify', { productId: 'premium_pro_mensal', purchaseToken: 'x'.repeat(20), uid: 'adminUid' }, 'userB');
  assert.equal(v.status, 200);
  assert.equal(calls.billing[0].uid, 'userB');
});

test('todas as rotas de notificação estão ligadas ao handler certo', async () => {
  const { authed, calls } = await setup();
  for (const route of ['news', 'comment', 'support', 'subscription-request', 'admin', 'tier-tag', 'premium-expiry']) {
    assert.equal((await authed(`/v1/notify/${route}`, {})).status, 200);
  }
  assert.deepEqual(calls.notify.map((c) => c[0]), ['news', 'comment', 'support', 'subscriptionRequest', 'admin', 'tierTag', 'premiumExpiry']);
});

test('JSON inválido → 400 e corpo gigante → 413', async () => {
  const { post, issue } = await setup();
  const headers = { authorization: `Bearer ${await issue({})}` };
  assert.equal((await post('/v1/notify/news', '{nao-json', headers)).status, 400);
  assert.equal((await post('/v1/notify/news', '[1,2]', headers)).status, 400);
  assert.equal((await post('/v1/notify/news', JSON.stringify({ x: 'a'.repeat(30000) }), headers)).status, 413);
});

test('limite de requisições por usuário (429)', async () => {
  const { authed } = await setup();
  let last;
  for (let i = 0; i < 61; i++) last = await authed('/v1/notify/news', {});
  assert.equal(last.status, 429);
  assert.equal((await authed('/v1/notify/news', {}, 'outroUsuario')).status, 200);
});

test('erros do handler viram JSON com o status certo; erro inesperado não vaza detalhes', async () => {
  const { HttpError } = await import('../src/util.js');
  const { verifier, issue } = await makeTokenIssuer();
  const app = createApp({
    env: {},
    verifyIdToken: verifier,
    notify: {
      news: async () => { throw new HttpError(403, 'forbidden', 'Apenas administradores.'); },
      comment: async () => { throw new Error('senha do banco: 1234'); },
    },
    billing: {},
  });
  const headers = { authorization: `Bearer ${await issue({})}`, 'content-type': 'application/json' };
  const call = (route) => app(new Request(`https://api.test/v1/notify/${route}`, { method: 'POST', headers, body: '{}' }));

  const r1 = await call('news');
  assert.equal(r1.status, 403);
  assert.deepEqual(await r1.json(), { ok: false, error: 'forbidden', message: 'Apenas administradores.' });

  const origError = console.error;
  console.error = () => {};
  const r2 = await call('comment');
  console.error = origError;
  assert.equal(r2.status, 500);
  assert.equal(JSON.stringify(await r2.json()).includes('1234'), false);
});

test('RTDN: segredo errado → 401; sem segredo configurado → 503; teste → ok', async () => {
  const { post } = await setup();
  assert.equal((await post('/v1/billing/rtdn?secret=errado', pubsub({ testNotification: {} }))).status, 401);
  assert.equal((await post('/v1/billing/rtdn', pubsub({ testNotification: {} }))).status, 401);
  const ok = await post('/v1/billing/rtdn?secret=s3gredo', pubsub({ packageName: 'com.astelee.horizonte_news', testNotification: { version: '1.0' } }));
  assert.equal(ok.status, 200);
  assert.equal((await ok.json()).test, true);
  const semConfig = await setup({ RTDN_SHARED_SECRET: '' });
  assert.equal((await semConfig.post('/v1/billing/rtdn?secret=', pubsub({ testNotification: {} }))).status, 503);
});

test('RTDN: assinatura vai para processToken; reembolso usa forceRevoke; outro pacote é ignorado', async () => {
  const { post, calls } = await setup();
  await post('/v1/billing/rtdn?secret=s3gredo', pubsub({ packageName: 'com.astelee.horizonte_news', subscriptionNotification: { notificationType: 2, purchaseToken: 'tok-1', subscriptionId: 'premium_pro_mensal' } }));
  assert.deepEqual(calls.rtdn[0], { purchaseToken: 'tok-1' });

  await post('/v1/billing/rtdn?secret=s3gredo', pubsub({ packageName: 'com.astelee.horizonte_news', voidedPurchaseNotification: { purchaseToken: 'tok-2', productType: 1 } }));
  assert.deepEqual(calls.rtdn[1], { purchaseToken: 'tok-2', forceRevoke: true });

  const outro = await post('/v1/billing/rtdn?secret=s3gredo', pubsub({ packageName: 'com.outro.app', subscriptionNotification: { purchaseToken: 'tok-3' } }));
  assert.equal((await outro.json()).ignored, 'other_package');
  assert.equal(calls.rtdn.length, 2);

  const compra = await post('/v1/billing/rtdn?secret=s3gredo', pubsub({ packageName: 'com.astelee.horizonte_news', voidedPurchaseNotification: { purchaseToken: 'tok-4', productType: 2 } }));
  assert.equal((await compra.json()).ignored, 'unsupported_notification');
  assert.equal(calls.rtdn.length, 2);
});

test('rota de XP de curtida exige login e usa o uid do token', async () => {
  const { post, authed, calls } = await setup();
  assert.equal((await post('/v1/xp/like', { postId: 'p', commentId: 'c' })).status, 401);
  const res = await authed('/v1/xp/like', { postId: 'p', commentId: 'c', uid: 'alguem' }, 'curtidor');
  assert.equal(res.status, 200);
  assert.equal(calls.xp[0][0], 'curtidor');
});