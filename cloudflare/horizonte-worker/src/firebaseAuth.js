// Verificação do ID token do Firebase Auth (JWT RS256) sem SDK.
// Regras oficiais: https://firebase.google.com/docs/auth/admin/verify-id-tokens
//  • alg = RS256 e kid presente nas chaves públicas do Google;
//  • aud = ID do projeto; iss = https://securetoken.google.com/<projeto>;
//  • exp no futuro, iat/auth_time no passado; sub (uid) não vazio.

import { HttpError, base64UrlToBytes, base64UrlToJson, utf8 } from './util.js';

const JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const CLOCK_SKEW_SECONDS = 60;

export function createIdTokenVerifier({ projectId, fetchImpl = fetch, now = () => Date.now() }) {
  let cache = { keys: null, expiresAt: 0 };
  const importedKeys = new Map();

  async function loadKeys(force = false) {
    if (!force && cache.keys && now() < cache.expiresAt) return cache.keys;
    const res = await fetchImpl(JWKS_URL);
    if (!res.ok) throw new HttpError(502, 'auth_keys_unavailable', 'Falha ao obter chaves do Firebase Auth.');
    const body = await res.json();
    const cacheControl = res.headers?.get?.('cache-control') || '';
    const match = /max-age=(\d+)/.exec(cacheControl);
    const ttlMs = (match ? Number(match[1]) : 3600) * 1000;
    cache = { keys: body.keys || [], expiresAt: now() + ttlMs };
    importedKeys.clear();
    return cache.keys;
  }

  async function keyFor(kid) {
    let keys = await loadKeys();
    let jwk = keys.find((k) => k.kid === kid);
    if (!jwk) {
      // Chave nova pode ter sido publicada: uma releitura forçada.
      keys = await loadKeys(true);
      jwk = keys.find((k) => k.kid === kid);
    }
    if (!jwk) return null;
    if (!importedKeys.has(kid)) {
      importedKeys.set(
        kid,
        await crypto.subtle.importKey(
          'jwk',
          jwk,
          { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
          false,
          ['verify'],
        ),
      );
    }
    return importedKeys.get(kid);
  }

  /** Devolve { uid, claims } ou lança HttpError 401. */
  return async function verify(token) {
    const unauthorized = (msg) => new HttpError(401, 'unauthorized', msg);
    if (typeof token !== 'string' || token.split('.').length !== 3) {
      throw unauthorized('Token ausente ou malformado.');
    }
    const [h, p, s] = token.split('.');
    let header;
    let payload;
    try {
      header = base64UrlToJson(h);
      payload = base64UrlToJson(p);
    } catch {
      throw unauthorized('Token ilegível.');
    }
    if (header.alg !== 'RS256' || !header.kid) throw unauthorized('Algoritmo inválido.');

    const key = await keyFor(header.kid);
    if (!key) throw unauthorized('Chave desconhecida.');

    const ok = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      key,
      base64UrlToBytes(s),
      utf8(`${h}.${p}`),
    );
    if (!ok) throw unauthorized('Assinatura inválida.');

    const nowSec = Math.floor(now() / 1000);
    if (payload.aud !== projectId) throw unauthorized('Projeto inválido.');
    if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
      throw unauthorized('Emissor inválido.');
    }
    if (typeof payload.exp !== 'number' || payload.exp <= nowSec - CLOCK_SKEW_SECONDS) {
      throw unauthorized('Token expirado.');
    }
    if (typeof payload.iat !== 'number' || payload.iat > nowSec + CLOCK_SKEW_SECONDS) {
      throw unauthorized('Token emitido no futuro.');
    }
    if (typeof payload.sub !== 'string' || payload.sub.length === 0 || payload.sub.length > 128) {
      throw unauthorized('Usuário inválido.');
    }
    return { uid: payload.sub, claims: payload };
  };
}