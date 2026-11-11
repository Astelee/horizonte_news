// Token OAuth2 de uma conta de serviço do Google (fluxo JWT bearer),
// usado para falar com Firestore e Google Play Developer API.
// A chave privada vem do segredo GOOGLE_SERVICE_ACCOUNT_JSON — nunca do app.

import { HttpError, base64ToBytes, jsonToBase64Url, bytesToBase64Url, utf8 } from './util.js';

const TOKEN_URL = 'https://oauth2.googleapis.com/token';

function pemToPkcs8(pem) {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\\n/g, '')
    .replace(/\s+/g, '');
  return base64ToBytes(body);
}

export function createGoogleAuth({ serviceAccountJson, fetchImpl = fetch, now = () => Date.now() }) {
  let account = null;
  let signingKey = null;
  const tokens = new Map(); // scope -> { token, expiresAt }

  function loadAccount() {
    if (account) return account;
    if (!serviceAccountJson) {
      throw new HttpError(503, 'not_configured', 'GOOGLE_SERVICE_ACCOUNT_JSON não configurado.');
    }
    try {
      account =
        typeof serviceAccountJson === 'string' ? JSON.parse(serviceAccountJson) : serviceAccountJson;
    } catch {
      throw new HttpError(503, 'not_configured', 'GOOGLE_SERVICE_ACCOUNT_JSON inválido.');
    }
    if (!account.client_email || !account.private_key) {
      throw new HttpError(503, 'not_configured', 'Conta de serviço incompleta.');
    }
    return account;
  }

  async function getSigningKey() {
    if (signingKey) return signingKey;
    const acc = loadAccount();
    signingKey = await crypto.subtle.importKey(
      'pkcs8',
      pemToPkcs8(acc.private_key),
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    return signingKey;
  }

  /** @param {string[]} scopes */
  return async function getAccessToken(scopes) {
    const scope = scopes.join(' ');
    const cached = tokens.get(scope);
    if (cached && now() < cached.expiresAt - 60_000) return cached.token;

    const acc = loadAccount();
    const iat = Math.floor(now() / 1000);
    const header = jsonToBase64Url({ alg: 'RS256', typ: 'JWT' });
    const claims = jsonToBase64Url({
      iss: acc.client_email,
      scope,
      aud: TOKEN_URL,
      iat,
      exp: iat + 3600,
    });
    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      await getSigningKey(),
      utf8(`${header}.${claims}`),
    );
    const assertion = `${header}.${claims}.${bytesToBase64Url(new Uint8Array(signature))}`;

    const res = await fetchImpl(TOKEN_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }).toString(),
    });
    if (!res.ok) {
      throw new HttpError(502, 'google_auth_failed', `OAuth do Google falhou (${res.status}).`);
    }
    const data = await res.json();
    tokens.set(scope, {
      token: data.access_token,
      expiresAt: now() + (Number(data.expires_in) || 3600) * 1000,
    });
    return data.access_token;
  };
}