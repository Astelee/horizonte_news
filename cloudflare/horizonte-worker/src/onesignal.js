// Cliente do OneSignal. A REST API Key só existe aqui (segredo do Worker).
// Mesmo endpoint e mesmo esquema de autorização ("Key ...") que o app usava
// antes, para o comportamento em produção continuar idêntico.

import { HttpError } from './util.js';

const SEND_URL = 'https://onesignal.com/api/v1/notifications';

export function createOneSignal({ appId, apiKey, fetchImpl = fetch }) {
  function requireConfig() {
    if (!appId || !apiKey) {
      throw new HttpError(503, 'not_configured', 'OneSignal não configurado no Worker.');
    }
  }

  return {
    /**
     * Envia um push. Devolve { ok, id, recipients, message }.
     * ok = HTTP 200 + id preenchido + ao menos 1 destinatário (mesma
     * leitura que o app fazia da resposta do OneSignal).
     */
    async send(payload) {
      requireConfig();
      let res;
      try {
        res = await fetchImpl(SEND_URL, {
          method: 'POST',
          headers: {
            'content-type': 'application/json; charset=utf-8',
            authorization: `Key ${apiKey}`,
          },
          body: JSON.stringify({ app_id: appId, ...payload }),
        });
      } catch (e) {
        throw new HttpError(502, 'onesignal_unreachable', `OneSignal inacessível: ${e.message}`);
      }
      const text = await res.text();
      let body = null;
      try {
        body = JSON.parse(text);
      } catch {
        /* resposta não-JSON */
      }
      if (!res.ok) {
        return { ok: false, id: null, recipients: null, message: `OneSignal ${res.status}: ${text.slice(0, 200)}` };
      }
      const id = typeof body?.id === 'string' ? body.id : '';
      const recipients = body?.recipients ?? null;
      if (!id) {
        return {
          ok: false,
          id: null,
          recipients,
          message: 'Nenhum aparelho disponível para receber (usuário sem push ativo).',
        };
      }
      if (recipients === 0) {
        return { ok: false, id, recipients, message: '0 destinatários — ninguém inscrito.' };
      }
      return { ok: true, id, recipients, message: null };
    },

    /** Atualiza a tag `tier` do usuário (External ID = uid do Firebase). */
    async setTierTag(externalId, tier) {
      requireConfig();
      const res = await fetchImpl(
        `https://api.onesignal.com/apps/${appId}/users/by/external_id/${encodeURIComponent(externalId)}`,
        {
          method: 'PATCH',
          headers: {
            'content-type': 'application/json; charset=utf-8',
            authorization: `Key ${apiKey}`,
          },
          body: JSON.stringify({ properties: { tags: { tier } } }),
        },
      );
      return res.status >= 200 && res.status < 300;
    },
  };
}