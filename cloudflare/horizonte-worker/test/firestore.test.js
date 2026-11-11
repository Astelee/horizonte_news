import { test } from 'node:test';
import assert from 'node:assert/strict';
import { decodeFields, encodeFields, createFirestore } from '../src/firestore.js';
import { deterministicUuid, sha256Hex, timingSafeEqual, truncate, requireDocId } from '../src/util.js';

test('codifica e decodifica tipos do Firestore (ida e volta)', () => {
  const original = {
    s: 'texto', i: 42, d: 1.5, b: true, n: null,
    t: new Date('2026-03-01T12:00:00.000Z'),
    a: ['x', 2, { k: 'v' }], vazio: [], m: { dentro: { fundo: 1 } },
  };
  const back = decodeFields(encodeFields(original));
  assert.deepEqual(back, original);
  assert.equal(encodeFields({ i: 7 }).i.integerValue, '7');
});

test('patch envia updateMask só com os campos informados + campos apagados', async () => {
  let seen;
  const fs = createFirestore({
    projectId: 'p',
    getToken: async () => 'tok',
    fetchImpl: async (url, init) => {
      seen = { url, init };
      return { ok: true, status: 200, json: async () => ({}) };
    },
  });
  await fs.patch('users_xp/u1', { premiumTier: 'pro' }, { deleteFields: ['premiumTrial'], mustExist: true });
  assert.match(seen.url, /updateMask\.fieldPaths=premiumTier/);
  assert.match(seen.url, /updateMask\.fieldPaths=premiumTrial/);
  assert.match(seen.url, /currentDocument\.exists=true/);
  assert.equal(seen.init.method, 'PATCH');
  assert.equal(JSON.parse(seen.init.body).fields.premiumTier.stringValue, 'pro');
  assert.equal(seen.init.headers.authorization, 'Bearer tok');
});

test('get devolve null em 404 e create converte 409', async () => {
  const fs404 = createFirestore({ projectId: 'p', getToken: async () => 't', fetchImpl: async () => ({ ok: false, status: 404 }) });
  assert.equal(await fs404.get('a/b'), null);
  const fs409 = createFirestore({ projectId: 'p', getToken: async () => 't', fetchImpl: async () => ({ ok: false, status: 409, text: async () => '' }) });
  await assert.rejects(() => fs409.create('a', 'b', {}), (e) => e.status === 409);
});

test('utilitários: uuid determinístico, hash, comparação segura, truncar e ids', async () => {
  assert.equal(await deterministicUuid('x'), await deterministicUuid('x'));
  assert.notEqual(await deterministicUuid('x'), await deterministicUuid('y'));
  assert.match(await deterministicUuid('x'), /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.equal((await sha256Hex('abc')).length, 64);
  assert.ok(timingSafeEqual('segredo', 'segredo'));
  assert.ok(!timingSafeEqual('segredo', 'segredO'));
  assert.ok(!timingSafeEqual('a', 'ab'));
  assert.equal(truncate('a   b\n c', 100), 'a b c');
  assert.equal(truncate('x'.repeat(10), 4), 'xxxx…');
  assert.throws(() => requireDocId('a/b', 'x'));
  assert.throws(() => requireDocId('..', 'x'));
  assert.equal(requireDocId('abc_123', 'x'), 'abc_123');
});