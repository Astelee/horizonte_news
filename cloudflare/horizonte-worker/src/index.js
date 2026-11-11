// Horizonte News — API segura (Cloudflare Workers).
//
//   POST /v1/notify/news | comment | support | subscription-request |
//                admin | tier-tag | premium-expiry   (push via OneSignal)
//   POST /v1/xp/like                                   (XP de curtida recebida)
//   POST /v1/billing/verify                            (compra do Google Play)
//   POST /v1/billing/rtdn?secret=...                   (avisos do Google Play via Pub/Sub)
//   GET  /v1/health
//
// O app envia o ID token do Firebase em `Authorization: Bearer ...`.
// Nenhum segredo (OneSignal, conta de serviço) existe no app.

import { createIdTokenVerifier } from './firebaseAuth.js';
import { createGoogleAuth } from './googleAuth.js';
import { createFirestore } from './firestore.js';
import { createOneSignal } from './onesignal.js';
import { createNotifyHandlers } from './notify.js';
import { createBilling, createPlayClient } from './billing.js';
import { createXpHandlers } from './xp.js';
import { createRateLimiter } from './ratelimit.js';
import { HttpError, jsonResponse, timingSafeEqual, base64ToBytes } from './util.js';

const MAX_BODY_CHARS = 20_000;

const NOTIFY_ROUTES = {
  news: 'news',
  comment: 'comment',
  support: 'support',
  'subscription-request': 'subscriptionRequest',
  admin: 'admin',
  'tier-tag': 'tierTag',
  'premium-expiry': 'premiumExpiry',
};

async function readJson(request) {
  const text = await request.text();
  if (text.length > MAX_BODY_CHARS) throw new HttpError(413, 'too_large', 'Corpo grande demais.');
  if (!text.trim()) return {};
  try {
    const parsed = JSON.parse(text);
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('x');
    return parsed;
  } catch {
    throw new HttpError(400, 'invalid_json', 'JSON inválido.');
  }
}

export function createApp({ env, verifyIdToken, notify, billing, xp = {}, now = () => Date.now() }) {
  const limitNotify = createRateLimiter({ max: 60, windowMs: 60_000, now });
  const limitBilling = createRateLimiter({ max: 20, windowMs: 60_000, now });

  async function authenticate(request) {
    const header = request.headers.get('authorization') || '';
    const match = /^Bearer\s+(.+)$/i.exec(header);
    if (!match) throw new HttpError(401, 'unauthorized', 'Faça login novamente.');
    return verifyIdToken(match[1].trim());
  }

  async function handleRtdn(request, url) {
    if (!env.RTDN_SHARED_SECRET) throw new HttpError(503, 'not_configured', 'RTDN_SHARED_SECRET não configurado.');
    const secret = url.searchParams.get('secret') || '';
    if (!timingSafeEqual(secret, env.RTDN_SHARED_SECRET)) throw new HttpError(401, 'unauthorized', 'Segredo inválido.');

    const envelope = await readJson(request);
    const b64 = envelope?.message?.data;
    if (typeof b64 !== 'string') throw new HttpError(400, 'invalid_request', 'Mensagem ausente.');
    let message;
    try {
      message = JSON.parse(new TextDecoder().decode(base64ToBytes(b64)));
    } catch {
      throw new HttpError(400, 'invalid_request', 'Mensagem ilegível.');
    }
    if (message.packageName && env.ANDROID_PACKAGE_NAME && message.packageName !== env.ANDROID_PACKAGE_NAME) {
      return { ok: true, ignored: 'other_package' };
    }
    if (message.testNotification) return { ok: true, test: true };

    if (message.subscriptionNotification?.purchaseToken) {
      const r = await billing.processToken({ purchaseToken: message.subscriptionNotification.purchaseToken });
      return { ok: true, ...r };
    }
    if (message.voidedPurchaseNotification?.purchaseToken && Number(message.voidedPurchaseNotification.productType) === 1) {
      const r = await billing.processToken({
        purchaseToken: message.voidedPurchaseNotification.purchaseToken,
        forceRevoke: true,
      });
      return { ok: true, ...r };
    }
    return { ok: true, ignored: 'unsupported_notification' };
  }

  return async function handle(request) {
    try {
      const url = new URL(request.url);
      const path = url.pathname.replace(/\/+$/, '');

      if (request.method === 'GET' && path === '/v1/health') {
        return jsonResponse({
          ok: true,
          configured: {
            onesignal: !!env.ONESIGNAL_REST_API_KEY,
            googleServiceAccount: !!env.GOOGLE_SERVICE_ACCOUNT_JSON,
            rtdn: !!env.RTDN_SHARED_SECRET,
          },
        });
      }
      if (request.method !== 'POST') throw new HttpError(405, 'method_not_allowed', 'Método não permitido.');

      if (path === '/v1/billing/rtdn') return jsonResponse(await handleRtdn(request, url));

      if (path === '/v1/billing/verify') {
        const caller = await authenticate(request);
        limitBilling(caller.uid);
        const body = await readJson(request);
        const result = await billing.verifyForUser({
          uid: caller.uid,
          productId: body.productId,
          purchaseToken: body.purchaseToken,
        });
        return jsonResponse(result);
      }

      if (path === '/v1/xp/like') {
        const caller = await authenticate(request);
        limitNotify(caller.uid);
        return jsonResponse(await xp.like(caller, await readJson(request)));
      }

      const notifyMatch = /^\/v1\/notify\/([a-z-]+)$/.exec(path);
      if (notifyMatch && NOTIFY_ROUTES[notifyMatch[1]]) {
        const caller = await authenticate(request);
        limitNotify(caller.uid);
        const body = await readJson(request);
        const result = await notify[NOTIFY_ROUTES[notifyMatch[1]]](caller, body);
        return jsonResponse(result);
      }

      throw new HttpError(404, 'not_found', 'Rota inexistente.');
    } catch (e) {
      if (e instanceof HttpError) {
        return jsonResponse({ ok: false, error: e.code, message: e.message }, e.status);
      }
      // Erro inesperado: não vaza detalhes internos.
      console.error('Erro inesperado', e);
      return jsonResponse({ ok: false, error: 'internal_error', message: 'Erro interno.' }, 500);
    }
  };
}

function createDefaultApp(env) {
  const getToken = createGoogleAuth({ serviceAccountJson: env.GOOGLE_SERVICE_ACCOUNT_JSON });
  const fs = createFirestore({ projectId: env.FIREBASE_PROJECT_ID, getToken });
  const onesignal = createOneSignal({ appId: env.ONESIGNAL_APP_ID, apiKey: env.ONESIGNAL_REST_API_KEY });
  const play = createPlayClient({ packageName: env.ANDROID_PACKAGE_NAME, getToken });
  return createApp({
    env,
    verifyIdToken: createIdTokenVerifier({ projectId: env.FIREBASE_PROJECT_ID }),
    notify: createNotifyHandlers({ fs, onesignal }),
    billing: createBilling({ fs, play }),
    xp: createXpHandlers({ fs }),
  });
}

let cachedApp = null;

export default {
  async fetch(request, env) {
    if (!cachedApp) cachedApp = createDefaultApp(env);
    return cachedApp(request);
  },
};