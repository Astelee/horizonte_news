import { test } from 'node:test';
import assert from 'node:assert/strict';
import { COMMENT_LIKE_XP, LEVEL_THRESHOLDS, createXpHandlers, levelFromXp } from '../src/xp.js';
import { createFirestore } from '../src/firestore.js';
import { sha256Hex } from '../src/util.js';
import { fakeFirestore } from './helpers.js';

const as = (uid) => ({ uid, claims: {} });
const code = (c) => (e) => e.code === c;

test('tabela de níveis do Worker = fórmula do app (round(35 × (n-1)^2.15))', () => {
  assert.equal(LEVEL_THRESHOLDS.length, 30);
  for (let level = 1; level <= 30; level++) {
    const expected = level <= 1 ? 0 : Math.round(35 * Math.pow(level - 1, 2.15));
    assert.equal(LEVEL_THRESHOLDS[level - 1], expected, `nível ${level}`);
  }
});

test('levelFromXp: limites de cada nível e teto em 30', () => {
  assert.equal(levelFromXp(0), 1);
  assert.equal(levelFromXp(34), 1);
  assert.equal(levelFromXp(35), 2);
  assert.equal(levelFromXp(154), 2);
  assert.equal(levelFromXp(155), 3);
  assert.equal(levelFromXp(689), 5);
  assert.equal(levelFromXp(48777), 29);
  assert.equal(levelFromXp(48778), 30);
  assert.equal(levelFromXp(10_000_000), 30);
});

function setup(extra = {}) {
  const fs = fakeFirestore({
    'comments/p1/postComments/c1': { userId: 'autor', text: 'oi' },
    'comments/p1/postComments/c1/replies/r1': { userId: 'autor', text: 'resp' },
    'comments/p1/postComments/c1/likes/curtidor': { likerUid: 'curtidor' },
    'comments/p1/postComments/c1/replies/r1/likes/curtidor': { likerUid: 'curtidor' },
    'users_xp/autor': { totalXp: 33, level: 1 },
    ...extra,
  });
  return { fs, h: createXpHandlers({ fs, now: () => Date.parse('2026-11-03T12:00:00Z') }) };
}

test('curtida recebida: +5 XP, nível recalculado junto e registro no livro-razão', async () => {
  const { fs, h } = setup();
  const r = await h.like(as('curtidor'), { postId: 'p1', commentId: 'c1' });
  assert.deepEqual(r, { ok: true, credited: true, xp: COMMENT_LIKE_XP });
  const author = fs.docs.get('users_xp/autor');
  assert.equal(author.totalXp, 38);
  assert.equal(author.level, 2); // 33 → 38 cruza o nível 2 (35 XP)
  const ledgerId = await sha256Hex('likexp|p1|c1|-|curtidor');
  assert.equal(fs.docs.get(`xp_ledger/${ledgerId}`).likerUid, 'curtidor');
});

test('mesma curtida nunca paga duas vezes — nem curtir, descurtir e curtir de novo', async () => {
  const { fs, h } = setup();
  await h.like(as('curtidor'), { postId: 'p1', commentId: 'c1' });
  const again = await h.like(as('curtidor'), { postId: 'p1', commentId: 'c1' });
  assert.deepEqual(again, { ok: true, credited: false, reason: 'already_credited' });
  fs.docs.delete('comments/p1/postComments/c1/likes/curtidor'); // descurtiu
  fs.docs.set('comments/p1/postComments/c1/likes/curtidor', { likerUid: 'curtidor' }); // curtiu de novo
  await h.like(as('curtidor'), { postId: 'p1', commentId: 'c1' });
  assert.equal(fs.docs.get('users_xp/autor').totalXp, 38);
});

test('curtida em resposta usa o autor da resposta e uma trava própria', async () => {
  const { fs, h } = setup();
  const r = await h.like(as('curtidor'), { postId: 'p1', commentId: 'c1', replyId: 'r1' });
  assert.equal(r.credited, true);
  // a curtida no comentário-raiz é OUTRA curtida: também paga uma vez
  await h.like(as('curtidor'), { postId: 'p1', commentId: 'c1' });
  assert.equal(fs.docs.get('users_xp/autor').totalXp, 43);
});

test('recusa: sem curtida real, auto-curtida, comentário inexistente, ids inválidos', async () => {
  const { fs, h } = setup();
  await assert.rejects(() => h.like(as('intruso'), { postId: 'p1', commentId: 'c1' }), code('like_not_found'));
  await assert.rejects(() => h.like(as('curtidor'), { postId: 'p1', commentId: 'nao-existe' }), code('not_found'));
  await assert.rejects(() => h.like(as('curtidor'), { postId: 'p1/../x', commentId: 'c1' }), code('invalid_request'));
  await assert.rejects(() => h.like(as('curtidor'), {}), code('invalid_request'));
  fs.docs.set('comments/p1/postComments/c1/likes/autor', {});
  assert.deepEqual(await h.like(as('autor'), { postId: 'p1', commentId: 'c1' }), { ok: true, credited: false, reason: 'self' });
  assert.equal(fs.docs.get('users_xp/autor').totalXp, 33);
});

test('override de nível do admin: soma o XP mas não mexe no nível', async () => {
  const { fs, h } = setup({ 'users_xp/autor': { totalXp: 4944, level: 11, adminOverrideActive: true } });
  await h.like(as('curtidor'), { postId: 'p1', commentId: 'c1' });
  assert.equal(fs.docs.get('users_xp/autor').totalXp, 4949);
  assert.equal(fs.docs.get('users_xp/autor').level, 11);
});

test('autor sem documento de XP: não credita e não cria o livro-razão', async () => {
  const { fs, h } = setup();
  fs.docs.delete('users_xp/autor');
  const r = await h.like(as('curtidor'), { postId: 'p1', commentId: 'c1' });
  assert.deepEqual(r, { ok: true, credited: false, reason: 'author_missing' });
  assert.equal([...fs.docs.keys()].some((k) => k.startsWith('xp_ledger/')), false);
});

// ── Cliente REST da transação (Firestore real) ─────────────────────────

function restFirestore(handler) {
  const calls = [];
  const fsClient = createFirestore({
    projectId: 'p',
    getToken: async () => 'tok',
    fetchImpl: async (url, init) => {
      const body = init.body ? JSON.parse(init.body) : undefined;
      calls.push({ url, body });
      return handler(url, body, calls.length);
    },
  });
  return { fsClient, calls };
}
const jsonRes = (status, data) => ({ ok: status < 300, status, json: async () => data, text: async () => JSON.stringify(data) });

test('runTransaction REST: begin → batchGet → commit com pré-condições', async () => {
  const { fsClient, calls } = restFirestore((url) => {
    if (url.endsWith(':beginTransaction')) return jsonRes(200, { transaction: 'TX1' });
    if (url.endsWith(':batchGet')) {
      return jsonRes(200, [{ found: { name: 'projects/p/databases/(default)/documents/users_xp/a', fields: { totalXp: { integerValue: '10' } }, updateTime: 't' } }]);
    }
    if (url.endsWith(':commit')) return jsonRes(200, {});
    return jsonRes(500, {});
  });
  const r = await fsClient.runTransaction(['users_xp/a'], (docs) => {
    assert.equal(docs['users_xp/a'].totalXp, 10);
    return [
      { type: 'update', path: 'users_xp/a', data: { totalXp: 15 }, mustExist: true },
      { type: 'create', path: 'xp_ledger/x', data: { kind: 'k' } },
    ];
  });
  assert.equal(r.committed, true);
  const commit = calls.find((c) => c.url.endsWith(':commit')).body;
  assert.equal(commit.transaction, 'TX1');
  assert.deepEqual(commit.writes[0].updateMask, { fieldPaths: ['totalXp'] });
  assert.deepEqual(commit.writes[0].currentDocument, { exists: true });
  assert.deepEqual(commit.writes[1].currentDocument, { exists: false });
  assert.equal(commit.writes[0].update.name, 'projects/p/databases/(default)/documents/users_xp/a');
  assert.equal(commit.writes[0].update.fields.totalXp.integerValue, '15');
});

test('runTransaction REST: ALREADY_EXISTS vira 409; ABORTED tenta de novo', async () => {
  let commits = 0;
  const { fsClient } = restFirestore((url) => {
    if (url.endsWith(':beginTransaction')) return jsonRes(200, { transaction: 'TX' });
    if (url.endsWith(':batchGet')) return jsonRes(200, [{ missing: 'projects/p/databases/(default)/documents/users_xp/a' }]);
    commits++;
    return commits === 1
      ? jsonRes(409, { error: { status: 'ABORTED' } })
      : jsonRes(409, { error: { status: 'ALREADY_EXISTS' } });
  });
  await assert.rejects(
    () => fsClient.runTransaction(['users_xp/a'], () => [{ type: 'create', path: 'xp_ledger/x', data: {} }]),
    (e) => e.status === 409 && e.code === 'already_exists',
  );
  assert.equal(commits, 2);
});

test('runTransaction REST: sem escritas não faz commit', async () => {
  const { fsClient, calls } = restFirestore((url) => (url.endsWith(':beginTransaction') ? jsonRes(200, { transaction: 'T' }) : jsonRes(200, [])));
  const r = await fsClient.runTransaction(['users_xp/a'], () => null);
  assert.equal(r.committed, false);
  assert.equal(calls.some((c) => c.url.endsWith(':commit')), false);
});