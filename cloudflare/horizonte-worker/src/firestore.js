// Cliente mínimo da REST API do Firestore usando a conta de serviço.
// A conta de serviço ignora as regras de segurança — por isso TODA
// checagem de permissão é feita no código dos handlers (notify/billing).

import { HttpError } from './util.js';

const SCOPE = 'https://www.googleapis.com/auth/datastore';

export function encodeValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: value.length ? { values: value.map(encodeValue) } : {} };
  }
  if (typeof value === 'object') return { mapValue: { fields: encodeFields(value) } };
  throw new Error(`Tipo não suportado: ${typeof value}`);
}

export function encodeFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) fields[k] = encodeValue(v);
  return fields;
}

export function decodeValue(v) {
  if (v === undefined || v === null) return null;
  if ('nullValue' in v) return null;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('stringValue' in v) return v.stringValue;
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(decodeValue);
  if ('mapValue' in v) return decodeFields(v.mapValue.fields || {});
  if ('referenceValue' in v) return v.referenceValue;
  if ('geoPointValue' in v) return v.geoPointValue;
  if ('bytesValue' in v) return v.bytesValue;
  return null;
}

export function decodeFields(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) out[k] = decodeValue(v);
  return out;
}

function decodeDoc(doc) {
  const id = doc.name.split('/').pop();
  return { id, ...decodeFields(doc.fields), __updateTime: doc.updateTime };
}

export function createFirestore({ projectId, getToken, fetchImpl = fetch }) {
  const base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

  async function call(method, url, body) {
    const token = await getToken([SCOPE]);
    const res = await fetchImpl(url, {
      method,
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return res;
  }

  async function fail(res, what) {
    let detail = '';
    try {
      detail = (await res.text()).slice(0, 300);
    } catch {
      /* ignora */
    }
    if (res.status === 409) throw new HttpError(409, 'already_exists', `${what}: já existe.`);
    throw new HttpError(502, 'firestore_error', `${what} falhou (${res.status}) ${detail}`);
  }

  const docName = (path) => `projects/${projectId}/databases/(default)/documents/${path}`;
  const pathOfName = (name) => name.split('/documents/')[1];

  async function readError(res) {
    let body = null;
    try {
      body = await res.json();
    } catch {
      /* sem corpo */
    }
    return { http: res.status, status: body?.error?.status || '', message: body?.error?.message || '' };
  }

  function toRestWrite(w) {
    if (w.type === 'create') {
      return {
        update: { name: docName(w.path), fields: encodeFields(w.data) },
        currentDocument: { exists: false },
      };
    }
    const mask = [...Object.keys(w.data), ...(w.deleteFields || [])];
    return {
      update: { name: docName(w.path), fields: encodeFields(w.data) },
      updateMask: { fieldPaths: mask },
      ...(w.mustExist ? { currentDocument: { exists: true } } : {}),
    };
  }

  return {
    /** Documento decodificado (campos + id + __updateTime) ou null. */
    async get(path) {
      const res = await call('GET', `${base}/${path}`);
      if (res.status === 404) return null;
      if (!res.ok) await fail(res, `Ler ${path}`);
      return decodeDoc(await res.json());
    },

    /** Lista (uma página) de uma coleção. */
    async list(collectionPath, pageSize = 100) {
      const res = await call('GET', `${base}/${collectionPath}?pageSize=${pageSize}`);
      if (res.status === 404) return [];
      if (!res.ok) await fail(res, `Listar ${collectionPath}`);
      const body = await res.json();
      return (body.documents || []).map(decodeDoc);
    },

    /** Consulta com filtros de igualdade: where = [[campo, valor], ...]. */
    async query(collectionId, where = [], limit = 50) {
      const filters = where.map(([field, value]) => ({
        fieldFilter: { field: { fieldPath: field }, op: 'EQUAL', value: encodeValue(value) },
      }));
      const structuredQuery = {
        from: [{ collectionId }],
        limit,
        ...(filters.length === 1
          ? { where: filters[0] }
          : filters.length > 1
            ? { where: { compositeFilter: { op: 'AND', filters } } }
            : {}),
      };
      const res = await call('POST', `${base}:runQuery`, { structuredQuery });
      if (!res.ok) await fail(res, `Consultar ${collectionId}`);
      const rows = await res.json();
      return rows.filter((r) => r.document).map((r) => decodeDoc(r.document));
    },

    /** Cria (falha com 409 se já existir). */
    async create(collectionPath, docId, data) {
      const res = await call(
        'POST',
        `${base}/${collectionPath}?documentId=${encodeURIComponent(docId)}`,
        { fields: encodeFields(data) },
      );
      if (!res.ok) await fail(res, `Criar ${collectionPath}/${docId}`);
    },

    /**
     * Atualiza SÓ os campos informados (updateMask) e apaga os de
     * deleteFields. Cria o documento se ainda não existir, a menos que
     * mustExist seja true.
     */
    async patch(path, data, { deleteFields = [], mustExist = false } = {}) {
      const mask = [...Object.keys(data), ...deleteFields];
      const params = mask.map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`);
      if (mustExist) params.push('currentDocument.exists=true');
      const res = await call('PATCH', `${base}/${path}?${params.join('&')}`, {
        fields: encodeFields(data),
      });
      if (!res.ok) await fail(res, `Gravar ${path}`);
    },

    /**
     * Transação de leitura-e-escrita (REST). Lê `readPaths`, chama
     * build(docs) — que devolve a lista de escritas — e confirma tudo de
     * uma vez. Escrita { type: 'create' } falha com 409 already_exists se o
     * documento já existir (usada como trava de "só uma vez"); { type:
     * 'update', mustExist } falha com 404 se o documento sumiu. Repete
     * sozinha se outra gravação concorrente abortar a transação.
     */
    async runTransaction(readPaths, build, { attempts = 3 } = {}) {
      for (let attempt = 1; attempt <= attempts; attempt++) {
        const begin = await call('POST', `${base}:beginTransaction`, { options: { readWrite: {} } });
        if (!begin.ok) await fail(begin, 'Iniciar transação');
        const { transaction } = await begin.json();

        const got = await call('POST', `${base}:batchGet`, {
          documents: readPaths.map(docName),
          transaction,
        });
        if (!got.ok) await fail(got, 'Ler na transação');
        const docs = {};
        for (const row of await got.json()) {
          if (row.found) docs[pathOfName(row.found.name)] = decodeDoc(row.found);
          else if (row.missing) docs[pathOfName(row.missing)] = null;
        }

        const writes = build(docs);
        if (!writes || writes.length === 0) return { committed: false };

        const res = await call('POST', `${base}:commit`, { transaction, writes: writes.map(toRestWrite) });
        if (res.ok) return { committed: true };

        const err = await readError(res);
        if (err.status === 'ABORTED' && attempt < attempts) continue;
        if (err.status === 'ALREADY_EXISTS') throw new HttpError(409, 'already_exists', 'Documento já existe.');
        if (err.status === 'NOT_FOUND') throw new HttpError(404, 'not_found', 'Documento não encontrado.');
        throw new HttpError(502, 'firestore_error', `Transação falhou (${err.http} ${err.status}) ${err.message}`.slice(0, 300));
      }
      throw new HttpError(502, 'firestore_error', 'Transação abortada várias vezes.');
    },
  };
}