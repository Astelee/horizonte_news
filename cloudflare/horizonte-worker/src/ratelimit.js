// Limite simples de requisições por usuário (melhor esforço: vale por
// instância do Worker). Para um limite global, crie uma regra de Rate
// Limiting no painel da Cloudflare (ver README.md).

import { HttpError } from './util.js';

export function createRateLimiter({ max, windowMs, now = () => Date.now() }) {
  const hits = new Map();
  return function check(key) {
    const t = now();
    const recent = (hits.get(key) || []).filter((ts) => t - ts < windowMs);
    if (recent.length >= max) {
      hits.set(key, recent);
      throw new HttpError(429, 'rate_limited', 'Muitas solicitações. Tente novamente em instantes.');
    }
    recent.push(t);
    hits.set(key, recent);
    if (hits.size > 5000) {
      for (const [k, list] of hits) {
        if (!list.some((ts) => t - ts < windowMs)) hits.delete(k);
      }
    }
  };
}