// Testes das regras do Firestore (atendimento + permissões revisadas).
// Rodar a partir desta pasta, com firebase-tools instalado:
//   npm install && npm test
// (usa o emulador do Firestore; nada toca o banco de produção)
//
// Contas: userA e userB (comuns), adminUid (ADM) e sem login.

const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');

const ts = () => firebase.firestore.FieldValue.serverTimestamp();
const inc = (n) => firebase.firestore.FieldValue.increment(n);
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-horizonte',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
    },
  });
});
after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('admins/adminUid').set({ role: 'admin' });
  });
});

const userDb = (uid) => env.authenticatedContext(uid).firestore();
const anonDb = () => env.unauthenticatedContext().firestore();

const profile = (uid) => ({
  userName: 'Maria',
  username: 'maria',
  usernameLower: 'maria',
  searchName: 'maria',
  photoUrl: null,
});

/** Primeira mensagem do usuário: cria a conversa + a mensagem no mesmo batch. */
async function userFirstMessage(db, uid, msgId = 'm1', text = 'Olá') {
  const conv = db.doc(`support_conversations/${uid}`);
  const msg = conv.collection('messages').doc(msgId);
  const batch = db.batch();
  batch.set(msg, { senderId: uid, senderRole: 'user', text, createdAt: ts() });
  batch.set(conv, {
    userId: uid,
    ...profile(uid),
    status: 'open',
    pinned: false,
    blocked: false,
    awaitingReply: true,
    unreadUser: 0,
    unreadAgent: 1,
    lastMessageText: text,
    lastMessageSenderRole: 'user',
    lastMessageAt: ts(),
    lastMessageId: msgId,
    lastActivityAt: ts(),
    lastUserSendAt: ts(),
    createdAt: ts(),
  });
  return batch.commit();
}

async function agentReply(db, convId, msgId = 'a1', text = 'Oi!') {
  const conv = db.doc(`support_conversations/${convId}`);
  const msg = conv.collection('messages').doc(msgId);
  const batch = db.batch();
  batch.set(msg, { senderId: 'adminUid', senderRole: 'agent', text, createdAt: ts() });
  batch.update(conv, {
    lastMessageText: text,
    lastMessageSenderRole: 'agent',
    lastMessageAt: ts(),
    lastMessageId: msgId,
    lastActivityAt: ts(),
    lastAgentId: 'adminUid',
    unreadUser: inc(1),
    awaitingReply: false,
    status: 'open',
  });
  return batch.commit();
}

// ── Atendimento: acesso ──────────────────────────────────────────

test('sem login não lê nem escreve no atendimento', async () => {
  await assertSucceeds(userFirstMessage(userDb('userA'), 'userA'));
  await assertFails(anonDb().doc('support_conversations/userA').get());
  await assertFails(
    anonDb().doc('support_conversations/userA/messages/m1').get());
});

test('usuário cria e lê a própria conversa', async () => {
  const a = userDb('userA');
  await assertSucceeds(userFirstMessage(a, 'userA'));
  await assertSucceeds(a.doc('support_conversations/userA').get());
  await assertSucceeds(
    a.collection('support_conversations/userA/messages').limit(10).get());
});

test('outro usuário comum NÃO lê nem escreve na conversa alheia', async () => {
  await assertSucceeds(userFirstMessage(userDb('userA'), 'userA'));
  const b = userDb('userB');
  await assertFails(b.doc('support_conversations/userA').get());
  await assertFails(
    b.collection('support_conversations/userA/messages').limit(10).get());
  await assertFails(userFirstMessage(b, 'userA', 'x1', 'invasão'));
});

test('ADM lê qualquer conversa e responde; usuário comum não finge ser ADM', async () => {
  await assertSucceeds(userFirstMessage(userDb('userA'), 'userA'));
  const admin = userDb('adminUid');
  await assertSucceeds(admin.doc('support_conversations/userA').get());
  await assertSucceeds(agentReply(admin, 'userA'));

  // userB tenta responder como agente na conversa de userA
  await assertFails(agentReply(userDb('userB'), 'userA', 'a2', 'sou admin'));
  // userA tenta se passar por agente na própria conversa
  await assertFails(agentReply(userDb('userA'), 'userA', 'a3', 'sou admin'));
});

test('ADM inicia conversa com usuário que nunca escreveu', async () => {
  const admin = userDb('adminUid');
  const conv = admin.doc('support_conversations/userC');
  const msg = conv.collection('messages').doc('a1');
  const batch = admin.batch();
  batch.set(msg, { senderId: 'adminUid', senderRole: 'agent', text: 'Olá!', createdAt: ts() });
  batch.set(conv, {
    userId: 'userC',
    ...profile('userC'),
    status: 'open',
    pinned: false,
    blocked: false,
    awaitingReply: false,
    unreadUser: 1,
    unreadAgent: 0,
    lastMessageText: 'Olá!',
    lastMessageSenderRole: 'agent',
    lastMessageAt: ts(),
    lastMessageId: 'a1',
    lastActivityAt: ts(),
    lastAgentId: 'adminUid',
    createdAt: ts(),
  });
  await assertSucceeds(batch.commit());
  await assertSucceeds(userDb('userC').doc('support_conversations/userC').get());
});

// ── Atendimento: validações ──────────────────────────────────────

test('mensagem acima de 2000 caracteres é recusada', async () => {
  await assertFails(
    userFirstMessage(userDb('userA'), 'userA', 'm1', 'x'.repeat(2001)));
});

test('mensagem sem o resumo da conversa no mesmo batch é recusada', async () => {
  const a = userDb('userA');
  await assertSucceeds(userFirstMessage(a, 'userA'));
  await assertFails(
    a.doc('support_conversations/userA/messages/solta').set({
      senderId: 'userA', senderRole: 'user', text: 'sem resumo', createdAt: ts(),
    }));
});

test('mensagens são imutáveis (sem editar nem apagar)', async () => {
  const a = userDb('userA');
  await assertSucceeds(userFirstMessage(a, 'userA'));
  const ref = a.doc('support_conversations/userA/messages/m1');
  await assertFails(ref.update({ text: 'editada' }));
  await assertFails(ref.delete());
});

test('usuário não altera bloqueio, fixação, status nem contador alheio', async () => {
  const a = userDb('userA');
  await assertSucceeds(userFirstMessage(a, 'userA'));
  const ref = a.doc('support_conversations/userA');
  await assertFails(ref.update({ blocked: false }));
  await assertFails(ref.update({ pinned: true }));
  await assertFails(ref.update({ status: 'resolved' }));
  await assertFails(ref.update({ unreadAgent: 0 }));
  await assertFails(ref.update({ userId: 'outro' }));
});

test('envio em menos de 2 segundos é recusado (limite de frequência)', async () => {
  const a = userDb('userA');
  await assertSucceeds(userFirstMessage(a, 'userA', 'm1'));
  const conv = a.doc('support_conversations/userA');
  const batch = a.batch();
  batch.set(conv.collection('messages').doc('m2'), {
    senderId: 'userA', senderRole: 'user', text: 'rápido demais', createdAt: ts(),
  });
  batch.update(conv, {
    ...profile('userA'),
    status: 'open', awaitingReply: true, unreadAgent: inc(1),
    lastMessageText: 'rápido demais', lastMessageSenderRole: 'user',
    lastMessageAt: ts(), lastMessageId: 'm2', lastActivityAt: ts(), lastUserSendAt: ts(),
  });
  await assertFails(batch.commit());
});

test('conversa bloqueada impede o envio do usuário (e o ADM bloqueia)', async () => {
  const a = userDb('userA');
  await assertSucceeds(userFirstMessage(a, 'userA'));
  await assertSucceeds(
    userDb('adminUid').doc('support_conversations/userA').update({ blocked: true }));
  await new Promise((r) => setTimeout(r, 2200)); // passa o intervalo mínimo
  const conv = a.doc('support_conversations/userA');
  const batch = a.batch();
  batch.set(conv.collection('messages').doc('m2'), {
    senderId: 'userA', senderRole: 'user', text: 'bloqueado?', createdAt: ts(),
  });
  batch.update(conv, {
    ...profile('userA'),
    status: 'open', awaitingReply: true, unreadAgent: inc(1),
    lastMessageText: 'bloqueado?', lastMessageSenderRole: 'user',
    lastMessageAt: ts(), lastMessageId: 'm2', lastActivityAt: ts(), lastUserSendAt: ts(),
  });
  await assertFails(batch.commit());
});

test('marcar como lida: cada lado só zera o próprio contador', async () => {
  const a = userDb('userA');
  await assertSucceeds(userFirstMessage(a, 'userA'));
  await assertSucceeds(agentReply(userDb('adminUid'), 'userA'));
  await assertSucceeds(a.doc('support_conversations/userA')
    .update({ unreadUser: 0, userReadAt: ts() }));
  await assertFails(a.doc('support_conversations/userA')
    .update({ unreadAgent: 0, agentReadAt: ts() }));
  await assertSucceeds(userDb('adminUid').doc('support_conversations/userA')
    .update({ unreadAgent: 0, agentReadAt: ts() }));
});

test('configuração do atendimento: só ADM escreve; usuário lê só a pública', async () => {
  const admin = userDb('adminUid');
  await assertSucceeds(admin.doc('support_config/agents').set({
    agentUids: ['adminUid'], notifyUids: ['adminUid'],
  }));
  await assertSucceeds(admin.doc('support_config/public').set({
    enabled: true, welcomeMessage: 'Oi', offHoursMessage: '', hours: { enabled: false },
  }));
  const a = userDb('userA');
  await assertSucceeds(a.doc('support_config/public').get());
  await assertFails(a.doc('support_config/agents').get());
  await assertFails(a.doc('support_config/public').set({ enabled: false }));
  await assertFails(a.collection('support_quick_replies').get());
});

// ── Regras revisadas (fora do atendimento) ───────────────────────

test('coleção sem regra explícita é negada (inclusive leitura sem login)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('qualquer_coisa/x').set({ a: 1 });
  });
  await assertFails(anonDb().doc('qualquer_coisa/x').get());
  await assertFails(userDb('userA').doc('qualquer_coisa/x').get());
});

test('notícias continuam públicas para leitura; só ADM escreve', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('noticias/n1').set({ titulo: 'T', status: 'publicado' });
  });
  await assertSucceeds(anonDb().doc('noticias/n1').get());
  await assertFails(userDb('userA').doc('noticias/n1').update({ titulo: 'X' }));
  await assertSucceeds(userDb('adminUid').doc('noticias/n1').update({ titulo: 'X' }));
});

test('comentários: leitura pública, inclusive consulta de grupo', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('comments/p1').set({ x: 1 });
    await ctx.firestore().doc('comments/p1/postComments/c1').set({ userId: 'userA', text: 'oi' });
  });
  await assertSucceeds(anonDb().collection('comments').get());
  await assertSucceeds(anonDb().collectionGroup('postComments').limit(5).get());
});

test('post_views: criar com 1/1 ok; adulterar contador negado', async () => {
  const a = userDb('userA');
  await assertSucceeds(a.doc('post_views/p1').set({
    postId: 'p1', postTitle: 'T', totalViews: 1, uniqueViewers: 1, lastViewedAt: ts(),
  }, { merge: true }));
  await assertSucceeds(userDb('userB').doc('post_views/p1').set({
    postId: 'p1', postTitle: 'T', totalViews: inc(1), uniqueViewers: inc(1), lastViewedAt: ts(),
  }, { merge: true }));
  await assertFails(a.doc('post_views/p1').set({ totalViews: 99999 }, { merge: true }));
  await assertFails(a.doc('post_views/p1').delete());
});

test('banned_users: dono não cria o próprio banimento, mas pode apagar', async () => {
  await assertFails(userDb('userA').doc('banned_users/userA').set({ banned: true }));
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('banned_users/userA').set({ banned: true });
  });
  await assertSucceeds(userDb('userA').doc('banned_users/userA').delete());
});