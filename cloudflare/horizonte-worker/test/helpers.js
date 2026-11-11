// Dublês de teste: Firestore em memória, OneSignal falso e geração de ID tokens assinados.
import { createIdTokenVerifier } from '../src/firebaseAuth.js';
import { bytesToBase64Url, jsonToBase64Url, utf8 } from '../src/util.js';

export const PROJECT_ID = 'horizontenews-6b48f';

/** Firestore falso com a mesma interface de createFirestore (get/list/query/create/patch). */
export function fakeFirestore(seed = {}) {
  const docs = new Map(Object.entries(seed).map(([k, v]) => [k, { ...v }]));
  const calls = [];
  const idOf = (path) => path.split('/').pop();
  const withId = (path) => ({ id: idOf(path), ...docs.get(path) });
  return {
    docs,
    calls,
    async get(path) {
      return docs.has(path) ? withId(path) : null;
    },
    async list(col) {
      return [...docs.keys()].filter((p) => p.startsWith(`${col}/`) && p.split('/').length === 2).map(withId);
    },
    async query(col, where) {
      return [...docs.keys()]
        .filter((p) => p.startsWith(`${col}/`) && p.split('/').length === 2)
        .map(withId)
        .filter((d) => where.every(([f, v]) => d[f] === v));
    },
    async create(col, id, data) {
      const path = `${col}/${id}`;
      calls.push(['create', path]);
      if (docs.has(path)) {
        const { HttpError } = await import('../src/util.js');
        throw new HttpError(409, 'already_exists', 'já existe');
      }
      docs.set(path, { ...data });
    },
    async runTransaction(readPaths, build) {
      const { HttpError } = await import('../src/util.js');
      const read = {};
      for (const p of readPaths) read[p] = docs.has(p) ? withId(p) : null;
      const writes = build(read);
      if (!writes || writes.length === 0) return { committed: false };
      // valida TODAS as pré-condições antes de gravar (atomicidade)
      for (const w of writes) {
        if (w.type === 'create' && docs.has(w.path)) throw new HttpError(409, 'already_exists', 'já existe');
        if (w.type === 'update' && w.mustExist && !docs.has(w.path)) throw new HttpError(404, 'not_found', 'sumiu');
      }
      for (const w of writes) {
        calls.push(['tx-' + w.type, w.path]);
        if (w.type === 'create') docs.set(w.path, { ...w.data });
        else docs.set(w.path, { ...(docs.get(w.path) || {}), ...w.data });
      }
      return { committed: true };
    },
    async patch(path, data, { deleteFields = [], mustExist = false } = {}) {
      calls.push(['patch', path, Object.keys(data), deleteFields]);
      if (mustExist && !docs.has(path)) throw new Error(`mustExist: ${path}`);
      const cur = { ...(docs.get(path) || {}) };
      for (const f of deleteFields) delete cur[f];
      docs.set(path, { ...cur, ...data });
    },
  };
}

export function fakeOneSignal({ ok = true } = {}) {
  const sent = [];
  const tags = [];
  return {
    sent,
    tags,
    async send(payload) {
      sent.push(payload);
      return ok
        ? { ok: true, id: 'notif-1', recipients: 1, message: null }
        : { ok: false, id: null, recipients: 0, message: 'sem destinatários' };
    },
    async setTierTag(uid, tier) {
      tags.push([uid, tier]);
      return true;
    },
  };
}

/** Par de chaves RSA + emissor de ID tokens do Firebase para os testes. */
export async function makeTokenIssuer() {
  const pair = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  );
  const jwk = { ...(await crypto.subtle.exportKey('jwk', pair.publicKey)), kid: 'kid-1', alg: 'RS256', use: 'sig' };
  const jwksFetch = async () => ({
    ok: true,
    headers: { get: () => 'public, max-age=3600' },
    json: async () => ({ keys: [jwk] }),
  });

  async function issue(overrides = {}, { kid = 'kid-1', alg = 'RS256', key = pair.privateKey, nowSec } = {}) {
    const iat = nowSec ?? Math.floor(Date.now() / 1000);
    const payload = {
      iss: `https://securetoken.google.com/${PROJECT_ID}`,
      aud: PROJECT_ID,
      auth_time: iat,
      iat,
      exp: iat + 3600,
      sub: 'userA',
      ...overrides,
    };
    const header = jsonToBase64Url({ alg, kid, typ: 'JWT' });
    const body = jsonToBase64Url(payload);
    const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, utf8(`${header}.${body}`));
    return `${header}.${body}.${bytesToBase64Url(new Uint8Array(sig))}`;
  }

  const verifier = createIdTokenVerifier({ projectId: PROJECT_ID, fetchImpl: jwksFetch });
  return { issue, verifier, pair };
}