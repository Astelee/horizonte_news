import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createNotifyHandlers } from '../src/notify.js';
import { fakeFirestore, fakeOneSignal } from './helpers.js';

const NOW = Date.parse('2026-11-03T12:00:00Z');

function setup(seed = {}, osOpts) {
  const fs = fakeFirestore({
    'admins/adminUid': { role: 'admin' },
    'admins/agent2': { role: 'admin' },
    ...seed,
  });
  const onesignal = fakeOneSignal(osOpts);
  const h = createNotifyHandlers({ fs, onesignal, now: () => NOW });
  return { fs, onesignal, h };
}
const as = (uid) => ({ uid, claims: {} });
const code = (c) => (e) => e.code === c;

test('news: usuário comum não dispara push para todos', async () => {
  const { h, onesignal } = setup({ 'noticias/p1': { titulo: 'T', status: 'publicado' } });
  await assert.rejects(() => h.news(as('userA'), { postId: 'p1' }), code('forbidden'));
  assert.equal(onesignal.sent.length, 0);
});

test('news: só notícia publicada; admin envia para o segmento All com título e categoria', async () => {
  const { h, onesignal } = setup({
    'noticias/rascunho': { titulo: 'X', status: 'rascunho' },
    'noticias/p1': { titulo: 'Obra na avenida', status: 'publicado', categoria: 'Cidade', capaUrl: 'https://img/x.jpg', publicadoEm: new Date('2026-11-03T10:00:00Z') },
  });
  await assert.rejects(() => h.news(as('adminUid'), { postId: 'rascunho' }), code('not_published'));
  await assert.rejects(() => h.news(as('adminUid'), { postId: 'nao-existe' }), code('not_found'));
  const r = await h.news(as('adminUid'), { postId: 'p1' });
  assert.equal(r.ok, true);
  const p = onesignal.sent[0];
  assert.deepEqual(p.included_segments, ['All']);
  assert.equal(p.headings.en, 'CIDADE');
  assert.equal(p.contents.en, 'Obra na avenida');
  assert.equal(p.big_picture, 'https://img/x.jpg');
  assert.deepEqual(p.data, { postId: 'p1' });
  // mesma publicação → mesma chave (OneSignal ignora o reenvio)
  await h.news(as('adminUid'), { postId: 'p1' });
  assert.equal(onesignal.sent[1].idempotency_key, p.idempotency_key);
});

test('news: sem capa usa imageUrl https enviada pelo admin; http é ignorado', async () => {
  const { h, onesignal } = setup({ 'noticias/p1': { titulo: 'T', status: 'publicado' } });
  await h.news(as('adminUid'), { postId: 'p1', imageUrl: 'http://inseguro/x.jpg' });
  assert.equal(onesignal.sent[0].big_picture, undefined);
  assert.equal(onesignal.sent[0].headings.en, 'HORIZONTE NEWS');
  await h.news(as('adminUid'), { postId: 'p1', imageUrl: 'https://ok/x.jpg' });
  assert.equal(onesignal.sent[1].big_picture, 'https://ok/x.jpg');
});

const commentSeed = {
  'comments/p1/postComments/c1': { userId: 'autorC', userName: 'Autor' },
  'comments/p1/postComments/c1/replies/r1': { userId: 'userA', userName: 'Maria', username: 'maria', text: 'Concordo totalmente', replyToUsername: 'autorc' },
  'users_xp/autorC': { username: 'autorC', displayName: 'Autor' },
  'users_xp/userA': { displayName: 'Maria Silva', username: 'maria' },
};

test('resposta: só o autor da resposta notifica e o destinatário tem que conferir', async () => {
  const { h, onesignal } = setup(commentSeed);
  const base = { kind: 'reply', postId: 'p1', commentId: 'c1', replyId: 'r1' };
  await assert.rejects(() => h.comment(as('userB'), { ...base, recipientUserId: 'autorC' }), code('forbidden'));
  await assert.rejects(() => h.comment(as('userA'), { ...base, recipientUserId: 'vitima' }), code('recipient_mismatch'));
  assert.equal(onesignal.sent.length, 0);
  const r = await h.comment(as('userA'), { ...base, recipientUserId: 'autorC' });
  assert.equal(r.ok, true);
  const p = onesignal.sent[0];
  assert.deepEqual(p.include_aliases, { external_id: ['autorC'] });
  assert.equal(p.headings.en, 'maria');
  assert.equal(p.contents.en, 'respondeu ao seu comentário: Concordo totalmente');
  assert.deepEqual(p.data, { kind: 'comment', postId: 'p1', commentId: 'c1', replyId: 'r1' });
});

test('resposta a outra resposta: destinatário identificado por replyToUsername', async () => {
  const { h, onesignal } = setup({
    ...commentSeed,
    'comments/p1/postComments/c1/replies/r2': { userId: 'userA', username: 'maria', text: 'e você?', replyToUsername: 'joao' },
    'users_xp/joaoUid': { username: 'joao' },
  });
  await h.comment(as('userA'), { kind: 'reply', postId: 'p1', commentId: 'c1', replyId: 'r2', recipientUserId: 'joaoUid' });
  assert.deepEqual(onesignal.sent[0].include_aliases.external_id, ['joaoUid']);
});

test('resposta a si mesmo não envia nada', async () => {
  const { h, onesignal } = setup(commentSeed);
  const r = await h.comment(as('userA'), { kind: 'reply', postId: 'p1', commentId: 'c1', replyId: 'r1', recipientUserId: 'userA' });
  assert.equal(r.skipped, 'self');
  assert.equal(onesignal.sent.length, 0);
});

test('curtida: exige a curtida real, notifica o autor e ignora auto-curtida', async () => {
  const { h, onesignal, fs } = setup(commentSeed);
  const base = { kind: 'like', postId: 'p1', commentId: 'c1' };
  await assert.rejects(() => h.comment(as('userA'), base), code('like_not_found'));
  fs.docs.set('comments/p1/postComments/c1/likes/userA', { likerUid: 'userA' });
  const r = await h.comment(as('userA'), base);
  assert.equal(r.ok, true);
  assert.deepEqual(onesignal.sent[0].include_aliases.external_id, ['autorC']);
  assert.equal(onesignal.sent[0].headings.en, 'Maria Silva');
  assert.equal(onesignal.sent[0].contents.en, 'curtiu seu comentário');

  fs.docs.set('comments/p1/postComments/c1/likes/autorC', {});
  const self = await h.comment(as('autorC'), base);
  assert.equal(self.skipped, 'self');
  assert.equal(onesignal.sent.length, 1);
});

test('curtida em resposta usa o autor da resposta', async () => {
  const { h, onesignal, fs } = setup(commentSeed);
  fs.docs.set('comments/p1/postComments/c1/replies/r1/likes/autorC', {});
  await h.comment(as('autorC'), { kind: 'like', postId: 'p1', commentId: 'c1', replyId: 'r1' });
  assert.deepEqual(onesignal.sent[0].include_aliases.external_id, ['userA']);
  assert.equal(onesignal.sent[0].data.replyId, 'r1');
});

const supportSeed = {
  'support_conversations/userA': { userName: 'Maria', hidePreview: false },
  'support_conversations/userA/messages/m1': { senderId: 'userA', senderRole: 'user', text: 'Preciso de ajuda com a assinatura' },
  'support_conversations/userA/messages/m2': { senderId: 'adminUid', senderRole: 'agent', text: 'Já resolvo!' },
  'support_config/agents': { agentUids: ['adminUid', 'agent2'], notifyUids: ['adminUid'] },
  'support_config/public': { hidePreviewAgent: false },
};

test('atendimento: mensagem do usuário vai SÓ para notifyUids (não por tag do aparelho)', async () => {
  const { h, onesignal } = setup(supportSeed);
  await assert.rejects(() => h.support(as('userB'), { conversationId: 'userA', messageId: 'm1' }), code('forbidden'));
  await h.support(as('userA'), { conversationId: 'userA', messageId: 'm1' });
  const p = onesignal.sent[0];
  assert.deepEqual(p.include_aliases.external_id, ['adminUid']);
  assert.equal(p.filters, undefined);
  assert.equal(p.headings.en, 'Maria · Atendimento');
  assert.equal(p.contents.en, 'Preciso de ajuda com a assinatura');
  assert.deepEqual(p.data, { kind: 'support', conversationId: 'userA', messageId: 'm1' });
  assert.equal(p.collapse_id, 'support_userA');
});

test('atendimento: prévia oculta quando a equipe pede', async () => {
  const { h, onesignal, fs } = setup(supportSeed);
  fs.docs.set('support_config/public', { hidePreviewAgent: true });
  await h.support(as('userA'), { conversationId: 'userA', messageId: 'm1' });
  assert.equal(onesignal.sent[0].headings.en, 'Atendimento Horizonte News');
  assert.equal(onesignal.sent[0].contents.en, 'Você tem uma nova mensagem no atendimento');
});

test('atendimento: resposta do atendente só por atendente e vai ao usuário da conversa', async () => {
  const { h, onesignal } = setup(supportSeed);
  await assert.rejects(() => h.support(as('userA'), { conversationId: 'userA', messageId: 'm2' }), code('forbidden'));
  await h.support(as('adminUid'), { conversationId: 'userA', messageId: 'm2' });
  assert.deepEqual(onesignal.sent[0].include_aliases.external_id, ['userA']);
  assert.equal(onesignal.sent[0].contents.en, 'Já resolvo!');
  // admin que NÃO está na lista de atendentes não envia
  const outro = setup({ ...supportSeed, 'support_config/agents': { agentUids: ['agent2'], notifyUids: [] }, 'support_conversations/userA/messages/m3': { senderId: 'adminUid', senderRole: 'agent', text: 'oi' } });
  await assert.rejects(() => outro.h.support(as('adminUid'), { conversationId: 'userA', messageId: 'm3' }), code('forbidden'));
});

test('solicitação de assinatura: só o dono, só pendente, avisa os admins', async () => {
  const { h, onesignal, fs } = setup({ 'subscriptionRequests/s1': { uid: 'userA', status: 'pendente', plan: 'ultra', userName: 'Maria' } });
  await assert.rejects(() => h.subscriptionRequest(as('userB'), { requestId: 's1' }), code('forbidden'));
  const r = await h.subscriptionRequest(as('userA'), { requestId: 's1' });
  assert.equal(r.ok, true);
  assert.deepEqual(onesignal.sent[0].include_aliases.external_id.sort(), ['adminUid', 'agent2']);
  assert.equal(onesignal.sent[0].contents.en, 'Maria solicitou o plano ULTRA.');
  fs.docs.set('subscriptionRequests/s1', { uid: 'userA', status: 'aprovada', plan: 'ultra' });
  assert.equal((await h.subscriptionRequest(as('userA'), { requestId: 's1' })).skipped, 'not_pending');
});

test('push manual do painel e tag de plano: só administrador', async () => {
  const { h, onesignal } = setup();
  await assert.rejects(() => h.admin(as('userA'), { target: 'all', title: 'x', body: 'y' }), code('forbidden'));
  await assert.rejects(() => h.tierTag(as('userA'), { uid: 'u', tier: 'ultra' }), code('forbidden'));
  await assert.rejects(() => h.admin(as('adminUid'), { target: 'todos', title: 'x', body: 'y' }), code('invalid_request'));
  await assert.rejects(() => h.admin(as('adminUid'), { target: 'all', title: '', body: 'y' }), code('invalid_request'));
  await assert.rejects(() => h.tierTag(as('adminUid'), { uid: 'u', tier: 'deus' }), code('invalid_request'));

  await h.admin(as('adminUid'), { target: 'all', title: 'Aviso', body: 'Texto', data: { kind: 'premium_promo' } });
  assert.deepEqual(onesignal.sent[0].included_segments, ['All']);
  await h.admin(as('adminUid'), { target: 'user', uid: 'userA', title: 'Oi', body: 'Você' });
  assert.deepEqual(onesignal.sent[1].include_aliases.external_id, ['userA']);
  assert.equal((await h.tierTag(as('adminUid'), { uid: 'userA', tier: 'pro' })).ok, true);
  assert.deepEqual(onesignal.tags, [['userA', 'pro']]);
});

test('aviso de vencimento: só dentro de 3 dias, nunca em teste grátis, só para si', async () => {
  const day = 86_400_000;
  const mk = (extra) => setup({ 'users_xp/userA': { premiumTier: 'pro', premiumExpiresAt: new Date(NOW + 2 * day), ...extra } });

  const ok = mk({});
  const r = await ok.h.premiumExpiry(as('userA'));
  assert.equal(r.ok, true);
  assert.match(ok.onesignal.sent[0].contents.en, /Sua assinatura PRO vence em \d\d\/\d\d\./);
  assert.deepEqual(ok.onesignal.sent[0].data, { kind: 'premium_promo' });

  assert.equal((await mk({ premiumTrial: true }).h.premiumExpiry(as('userA'))).skipped, 'trial');
  assert.equal((await mk({ premiumExpiresAt: new Date(NOW + 10 * day) }).h.premiumExpiry(as('userA'))).skipped, 'outside_window');
  assert.equal((await mk({ premiumExpiresAt: new Date(NOW - day) }).h.premiumExpiry(as('userA'))).skipped, 'outside_window');
  assert.equal((await mk({ premiumTier: 'none' }).h.premiumExpiry(as('userA'))).skipped, 'no_subscription');
});

test('falha de entrega do OneSignal é reportada como ok:false', async () => {
  const { h } = setup({ 'noticias/p1': { titulo: 'T', status: 'publicado' } }, { ok: false });
  const r = await h.news(as('adminUid'), { postId: 'p1' });
  assert.equal(r.ok, false);
  assert.match(r.message, /destinat/);
});

test('atendimento: sem as chaves de prévia no Firestore, o padrão é OCULTAR (igual ao app)', async () => {
  const { h, onesignal } = setup({
    ...supportSeed,
    'support_conversations/userA': { userName: 'Maria' },
    'support_config/public': {},
  });
  await h.support(as('userA'), { conversationId: 'userA', messageId: 'm1' });
  assert.equal(onesignal.sent[0].headings.en, 'Atendimento Horizonte News');
  assert.equal(onesignal.sent[0].contents.en, 'Você tem uma nova mensagem no atendimento');
  await h.support(as('adminUid'), { conversationId: 'userA', messageId: 'm2' });
  assert.equal(onesignal.sent[1].contents.en, 'Você recebeu uma resposta do atendimento');
});