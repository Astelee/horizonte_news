// Utilidades pequenas e sem dependências (rodam no Workers e no Node 20+).

export class HttpError extends Error {
  constructor(status, code, message) {
    super(message || code);
    this.status = status;
    this.code = code;
  }
}

const encoder = new TextEncoder();

export function utf8(text) {
  return encoder.encode(text);
}

export function bytesToBase64(bytes) {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

export function base64ToBytes(b64) {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export function bytesToBase64Url(bytes) {
  return bytesToBase64(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function base64UrlToBytes(b64url) {
  let b64 = b64url.replace(/-/g, '+').replace(/_/g, '/');
  while (b64.length % 4) b64 += '=';
  return base64ToBytes(b64);
}

export function base64UrlToJson(b64url) {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(b64url)));
}

export function jsonToBase64Url(obj) {
  return bytesToBase64Url(utf8(JSON.stringify(obj)));
}

export async function sha256Hex(text) {
  const digest = await crypto.subtle.digest('SHA-256', utf8(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** UUID (formato v4) sempre igual para a mesma entrada — usado como
 *  idempotency_key do OneSignal para nunca duplicar um push. */
export async function deterministicUuid(input) {
  const hex = (await sha256Hex(input)).slice(0, 32).split('');
  hex[12] = '4';
  hex[16] = '89ab'[parseInt(hex[16], 16) & 3];
  const h = hex.join('');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
}

/** Comparação de texto em tempo constante (segredos). */
export function timingSafeEqual(a, b) {
  const x = utf8(String(a));
  const y = utf8(String(b));
  let diff = x.length ^ y.length;
  const len = Math.max(x.length, y.length);
  for (let i = 0; i < len; i++) diff |= (x[i] || 0) ^ (y[i] || 0);
  return diff === 0;
}

export function truncate(text, max) {
  const clean = String(text ?? '').replace(/\s+/g, ' ').trim();
  return clean.length > max ? `${clean.slice(0, max)}…` : clean;
}

export function requireString(value, name, { min = 1, max = 200 } = {}) {
  if (typeof value !== 'string' || value.length < min || value.length > max) {
    throw new HttpError(400, 'invalid_request', `Campo inválido: ${name}`);
  }
  return value;
}

/** Ids de documento do Firestore usados em caminhos: sem barras nem pontos soltos. */
export function requireDocId(value, name) {
  requireString(value, name, { min: 1, max: 1500 });
  if (/[\/\\]/.test(value) || value === '.' || value === '..' || value.startsWith('__')) {
    throw new HttpError(400, 'invalid_request', `Campo inválido: ${name}`);
  }
  return value;
}

export function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}