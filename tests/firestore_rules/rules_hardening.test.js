// Testes das regras endurecidas: XP, check-in, dados pessoais, comentários,
// notificações, contadores, assinaturas. Rodar a partir desta pasta:
//   npm install && npm test   (usa o emulador do Firestore)
//
// Cada teste usa as MESMAS formas de escrita que o app faz (ver
// XpService, CheckinService, CommentsSection, AdminViewsService...).

const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');

// Silencia o log do SDK: cada negação esperada (PERMISSION_DENIED) virava
// uma linha de erro e escondia o resultado real dos testes no CI.
try {
  firebase.firestore.setLogLevel('silent');
} catch (_) {
  /* sem efeito se a versão do SDK não expuser setLogLevel */
}

const ts = () => firebase.firestore.FieldValue.serverTimestamp();
const inc = (n) => firebase.firestore.FieldValue.increment(n);
const del = () => firebase.firestore.FieldValue.delete();
const union = (...v) => firebase.firestore.FieldValue.arrayUnion(...v);
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-horizonte-hardening',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
    },
  });
});
after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (db) => {
    await db.doc('admins/adminUid').set({ role: 'admin' });
    await db.doc('users_xp/userA').set(xpDoc());
    await db.doc('users_xp/userB').set(xpDoc());
  });
});

const seed = (fn) => env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));
const userDb = (uid, claims = { email: `${uid}@teste.com` }) => env.authenticatedContext(uid, claims).firestore();
const anonDb = () => env.unauthenticatedContext().firestore();

/** Documento de XP "normal" de um usuário nível 2 (35 XP). */
function xpDoc(extra = {}) {
  return {
    uid: 'x', username: 'maria', displayName: 'Maria', totalXp: 100, level: 2,
    totalSecondsOnline: 600, achievements: ['first_login'],
    stats: { articlesRead: 3, articlesShared: 0, commentsPosted: 0 },
    dailyMissions: { articlesRead: 0, commentsPosted: 0, articlesShared: 0, minutesOnline: 0, rewardsCollected: [] },
    ...extra,
  };
}

// ── XP e nível ───────────────────────────────────────────────────────

test('XP: ganho normal passa; salto absurdo, queda e nível inflado são negados', async () => {
  const a = userDb('userA');
  // +5 de leitura com nível coerente (100 XP → nível 2 ainda)
  await assertSucceeds(a.doc('users_xp/userA').update({ totalXp: inc(5), level: 2, lastActivity: ts(), 'stats.articlesRead': inc(1) }));
  // ganho acima de 1000 por gravação
  await assertFails(a.doc('users_xp/userA').update({ totalXp: 999999 }));
  await assertFails(a.doc('users_xp/userA').update({ totalXp: inc(1001) }));
  // perder XP
  await assertFails(a.doc('users_xp/userA').update({ totalXp: 10 }));
  // nível maior do que o XP permite (nível 30 com ~100 XP)
  await assertFails(a.doc('users_xp/userA').update({ level: 30 }));
  await assertFails(a.doc('users_xp/userA').update({ totalXp: inc(10), level: 5 }));
  // nível que o XP novo realmente permite (689 XP → nível 5)
  await assertSucceeds(a.doc('users_xp/userA').update({ totalXp: 689, level: 5 }));
  // nível desatualizado (menor) é tolerado — o app corrige sozinho
  await assertSucceeds(a.doc('users_xp/userA').update({ totalXp: inc(500), level: 5 }));
});

test('XP: cruzar o limite de nível exige o nível correto (35 XP = nível 2, 155 = nível 3)', async () => {
  await seed((db) => db.doc('users_xp/userC').set(xpDoc({ totalXp: 150, level: 2 })));
  const c = userDb('userC');
  await assertSucceeds(c.doc('users_xp/userC').update({ totalXp: 155, level: 3 }));
  await assertFails(c.doc('users_xp/userC').update({ totalXp: 160, level: 4 }));
});

test('XP: tempo online só cresce e em lotes razoáveis', async () => {
  const a = userDb('userA');
  await assertSucceeds(a.doc('users_xp/userA').update({ totalSecondsOnline: inc(3600) }));
  await assertFails(a.doc('users_xp/userA').update({ totalSecondsOnline: inc(99999) }));
  await assertFails(a.doc('users_xp/userA').update({ totalSecondsOnline: 5 }));
});

test('conquistas: só crescem; remover é negado', async () => {
  const a = userDb('userA');
  await assertSucceeds(a.doc('users_xp/userA').update({ achievements: union('read_10') }));
  await assertFails(a.doc('users_xp/userA').update({ achievements: ['read_10'] })); // tirou first_login
});

test('campos de premium e de override de admin: usuário comum não escreve', async () => {
  const a = userDb('userA');
  for (const patch of [
    { premiumTier: 'ultra' },
    { premiumExpiresAt: new Date(Date.now() + 86400000 * 365) },
    { premiumTrial: true },
    { premiumSource: 'play' },
    { premiumPurchaseHash: 'abc' },
    { adminOverrideActive: true },
    { adminOverrideLevel: 30 },
    { adminOverrideTitleActive: true },
    { adminOverrideTitleLevel: 30 },
    { adminBackupTotalXp: 0 },
    { uid: 'outro' },
  ]) {
    await assertFails(a.doc('users_xp/userA').update(patch));
  }
  // admin pode tudo isso
  await assertSucceeds(userDb('adminUid').doc('users_xp/userA').update({ premiumTier: 'pro', adminOverrideActive: true, level: 10, totalXp: 4944 }));
});

test('perfil: campos de personalização continuam livres para o dono', async () => {
  const a = userDb('userA');
  await assertSucceeds(a.doc('users_xp/userA').update({
    username: 'maria2', displayName: 'Maria 2', showAge: true, avatarId: 'animais_02',
    equippedPetId: 'pet1', equippedPremiumAvatarId: 'av1', lastSeenAt: ts(),
    nameStyle: { color: 'red' }, equippedCheckinRewardId: 'r1',
  }));
  await assertSucceeds(a.doc('users_xp/userA').update({ nameStyle: del() }));
  // foto: o dono só remove
  await seed((db) => db.doc('users_xp/userA').update({ photoUrl: 'https://img/ok.jpg' }));
  await assertFails(a.doc('users_xp/userA').update({ photoUrl: 'https://img/outra.jpg' }));
  await assertSucceeds(a.doc('users_xp/userA').update({ photoUrl: del() }));
});

test('outro usuário NÃO escreve no XP de ninguém (nem +5 de curtida, nem nível)', async () => {
  const b = userDb('userB');
  await assertFails(b.doc('users_xp/userA').update({ totalXp: inc(5), level: 2 }));
  await assertFails(b.doc('users_xp/userA').update({ level: 1 }));
  await assertFails(b.doc('users_xp/userA').update({ displayName: 'hack' }));
  await assertFails(b.doc('users_xp/userA').delete());
  await assertFails(anonDb().doc('users_xp/userA').update({ totalXp: inc(5) }));
});

test('criação do documento de XP: nasce no nível 1 e sem premium/override/dados pessoais', async () => {
  const c = userDb('userNovo');
  const base = { uid: 'userNovo', username: 'novo', totalXp: 0, level: 1, totalSecondsOnline: 0, achievements: ['first_login'], createdAt: ts() };
  await assertFails(c.doc('users_xp/userNovo').set({ ...base, totalXp: 5000, level: 12 }));
  await assertFails(c.doc('users_xp/userNovo').set({ ...base, premiumTier: 'ultra' }));
  await assertFails(c.doc('users_xp/userNovo').set({ ...base, adminOverrideActive: true }));
  await assertFails(c.doc('users_xp/userNovo').set({ ...base, achievements: ['first_login', 'level_30'] }));
  await assertFails(c.doc('users_xp/userNovo').set({ ...base, email: 'novo@teste.com' }));
  await assertFails(c.doc('users_xp/userNovo').set({ ...base, birthDate: new Date('2000-01-01') }));
  await assertFails(userDb('outroUid').doc('users_xp/userNovo').set(base));
  await assertSucceeds(c.doc('users_xp/userNovo').set(base));
  // perfis continuam públicos para usuários logados (ranking), não para anônimos
  await assertSucceeds(userDb('userB').doc('users_xp/userNovo').get());
  await assertFails(anonDb().doc('users_xp/userNovo').get());
});

test('excluir a própria conta: dono apaga o XP; outro não', async () => {
  await assertFails(userDb('userB').doc('users_xp/userA').delete());
  await assertSucceeds(userDb('userA').doc('users_xp/userA').delete());
});

// ── Dados pessoais ───────────────────────────────────────────────────

test('e-mail e nascimento: não ficam no perfil público; só dono/ADM leem users_private', async () => {
  await seed(async (db) => {
    await db.doc('users_xp/userA').update({ email: 'a@teste.com', birthDate: new Date('1990-05-05') }); // legado
    await db.doc('users_private/userA').set({ email: 'userA@teste.com', birthDate: new Date('1990-05-05') });
  });
  const a = userDb('userA');
  // migração: o dono pode APAGAR os campos do perfil público
  await assertSucceeds(a.doc('users_xp/userA').update({ email: del(), birthDate: del() }));
  // e não pode recolocar
  await assertFails(a.doc('users_xp/userA').update({ email: 'a@teste.com' }));
  await assertFails(a.doc('users_xp/userA').update({ birthDate: new Date('1990-05-05') }));

  await assertSucceeds(a.doc('users_private/userA').get());
  await assertSucceeds(userDb('adminUid').doc('users_private/userA').get());
  await assertFails(userDb('userB').doc('users_private/userA').get());
  await assertFails(anonDb().doc('users_private/userA').get());
});

test('users_private: dono grava só e-mail/nascimento e o e-mail precisa ser o da conta', async () => {
  const a = userDb('userA');
  await assertSucceeds(a.doc('users_private/userA').set({ email: 'userA@teste.com', birthDate: new Date('1990-05-05'), updatedAt: ts() }));
  await assertFails(a.doc('users_private/userA').set({ email: 'falso@outro.com' }));
  await assertFails(a.doc('users_private/userA').set({ email: 'userA@teste.com', extra: 1 }));
  await assertFails(userDb('userB').doc('users_private/userA').set({ email: 'userB@teste.com' }));
  await assertSucceeds(a.doc('users_private/userA').delete());
});

test('coleção legada users: não é mais pública; suspensões só do próprio/ADM', async () => {
  await seed(async (db) => {
    await db.doc('users/userA').set({ email: 'a@teste.com' });
    await db.doc('suspensions/userA').set({ suspended: true, reason: 'spam' });
  });
  await assertFails(userDb('userB').doc('users/userA').get());
  await assertSucceeds(userDb('userA').doc('users/userA').delete());
  await assertFails(userDb('userB').doc('suspensions/userA').get());
  await assertSucceeds(userDb('userA').doc('suspensions/userA').get());
  await assertSucceeds(userDb('adminUid').doc('suspensions/userA').get());
  await assertFails(userDb('userA').doc('suspensions/userA').delete());
});

// ── Check-in ─────────────────────────────────────────────────────────

const pad = (n) => String(n).padStart(2, '0');
const keyOf = (d) => `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
const dayKey = (offsetDays) => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + offsetDays);
  return keyOf(d);
};
const checkin = (db, key, status = 'done', xp = 10) =>
  db.doc(`users_xp/userA/checkins/${key}`).set({ status, xpAwarded: xp, timestamp: ts() });

test('check-in de hoje: aceita o dia do servidor (±1 por fuso); recusa futuro, passado e datas inválidas', async () => {
  const a = userDb('userA');
  await assertSucceeds(checkin(a, dayKey(0)));
  await assertSucceeds(checkin(a, dayKey(1)));   // fuso à frente do UTC
  await assertSucceeds(checkin(a, dayKey(-1)));  // fuso atrás do UTC
  await assertFails(checkin(a, dayKey(2)));
  await assertFails(checkin(a, dayKey(30)));
  await assertFails(checkin(a, '2099-01-01'));
  await assertFails(checkin(a, dayKey(-2)));       // 'done' de dois dias atrás não existe
  await assertFails(checkin(a, '2026-02-30'));     // data inexistente
  await assertFails(checkin(a, '2026-13-01'));
  await assertFails(checkin(a, 'abc'));
  await assertFails(checkin(a, '2026-5-9'));       // formato fora do padrão yyyy-MM-dd
});

test('check-in: cada dia só uma vez; valor de XP só os oficiais; timestamp do servidor', async () => {
  const a = userDb('userA');
  await assertSucceeds(checkin(a, dayKey(0), 'done', 25));
  await assertFails(checkin(a, dayKey(0), 'done', 10));            // segundo registro do mesmo dia
  await assertFails(checkin(a, dayKey(1), 'done', 11));            // XP inventado
  await assertFails(checkin(a, dayKey(1), 'done', 9999));
  await assertFails(a.doc(`users_xp/userA/checkins/${dayKey(1)}`).set({ status: 'done', xpAwarded: 10, timestamp: new Date() })); // relógio do aparelho
  await assertFails(a.doc(`users_xp/userA/checkins/${dayKey(1)}`).set({ status: 'done', xpAwarded: 10, timestamp: ts(), extra: 1 }));
  await assertFails(a.doc(`users_xp/userA/checkins/${dayKey(0)}`).update({ xpAwarded: 360 })); // dono não edita
  await assertFails(userDb('userB').doc(`users_xp/userA/checkins/${dayKey(1)}`).set({ status: 'done', xpAwarded: 10, timestamp: ts() }));
});

test('recuperação: só dia passado do mês atual, sempre 10 XP', async () => {
  const a = userDb('userA');
  await assertSucceeds(checkin(a, dayKey(-1), 'recovered', 10));
  await assertFails(checkin(a, dayKey(-3), 'recovered', 25));       // XP de recuperação é fixo
  await assertFails(checkin(a, dayKey(-40), 'recovered', 10));      // mês anterior
  await assertFails(checkin(a, dayKey(-400), 'recovered', 10));
  await assertFails(checkin(a, dayKey(2), 'recovered', 10));        // futuro
  await assertFails(checkin(a, dayKey(30), 'recovered', 10));
  await assertFails(checkin(a, '2026-02-30', 'recovered', 10));
});

test('check-in: resumo com sequência impossível é negado; leitura só do dono/ADM', async () => {
  const a = userDb('userA');
  await assertFails(a.doc('users_xp/userA').update({ checkinStreak: 99 }));
  await assertFails(a.doc('users_xp/userA').update({ longestCheckinStreak: -1 }));
  await assertSucceeds(a.doc('users_xp/userA').update({ checkinStreak: 5, longestCheckinStreak: 7, lastCheckinDate: dayKey(0) }));
  await seed((db) => checkin(db, dayKey(0)));
  await assertSucceeds(a.doc(`users_xp/userA/checkins/${dayKey(0)}`).get());
  await assertSucceeds(userDb('adminUid').doc(`users_xp/userA/checkins/${dayKey(0)}`).get());
  await assertFails(userDb('userB').doc(`users_xp/userA/checkins/${dayKey(0)}`).get());
});

// ── Comentários ──────────────────────────────────────────────────────

const commentData = (uid, extra = {}) => ({
  userId: uid, userName: 'Maria', username: 'maria', text: 'Ótima matéria!', createdAt: ts(),
  userLevel: 2, userAchievements: ['first_login'], userAvatarId: 'animais_01', userPhotoUrl: null,
  userEquippedPremiumAvatarId: null, userEquippedPetId: null, likesCount: 0, repliesCount: 0,
  ...extra,
});

/** Comentário + marca anti-spam no mesmo batch (como _sendComment faz). */
function sendComment(db, uid, id = 'c1', extra = {}) {
  const b = db.batch();
  b.set(db.doc(`comments/p1/postComments/${id}`), commentData(uid, extra));
  b.update(db.doc(`users_xp/${uid}`), { lastCommentAt: ts() });
  return b.commit();
}

test('comentar: batch com a marca anti-spam passa; sem ela é negado', async () => {
  const a = userDb('userA');
  await assertSucceeds(sendComment(a, 'userA'));
  await assertFails(a.doc('comments/p1/postComments/c2').set(commentData('userA'))); // sem users_xp.lastCommentAt
});

test('comentar: duplo toque / spam (menos de 10 s) é recusado; depois do intervalo passa', async () => {
  const a = userDb('userA');
  await assertSucceeds(sendComment(a, 'userA', 'c1'));
  await assertFails(sendComment(a, 'userA', 'c2'));   // duplicata imediata
  await seed((db) => db.doc('users_xp/userA').update({ lastCommentAt: new Date(Date.now() - 60000) }));
  await assertSucceeds(sendComment(a, 'userA', 'c3'));
});

test('comentar: não dá para falsificar autor, nível, conquistas ou campos extras', async () => {
  const a = userDb('userA');
  await assertFails(sendComment(a, 'userA', 'c1', { userId: 'userB' }));
  await assertFails(sendComment(a, 'userA', 'c1', { userLevel: 30 }));
  await assertFails(sendComment(a, 'userA', 'c1', { userAchievements: ['first_login', 'level_30'] }));
  await assertFails(sendComment(a, 'userA', 'c1', { isPinned: true }));
  await assertFails(sendComment(a, 'userA', 'c1', { likesCount: 500 }));
  await assertFails(sendComment(a, 'userA', 'c1', { text: '' }));
  await assertFails(sendComment(a, 'userA', 'c1', { text: 'x'.repeat(10001) }));
  await assertFails(sendComment(a, 'userA', 'c1', { createdAt: new Date('2020-01-01') }));
  await assertFails(sendComment(a, 'userA', 'c1', { replyToUsername: 'x' })); // campo de resposta em comentário raiz
  await assertFails(anonDb().doc('comments/p1/postComments/c9').set(commentData('userA')));
  await assertSucceeds(sendComment(a, 'userA', 'c1', { username: null, userPhotoUrl: null }));
});

test('suspenso/banido não comenta, não responde e não edita; suspensão vencida libera', async () => {
  await seed((db) => db.doc('suspensions/userA').set({ suspended: true, reason: 'spam' })); // permanente
  const a = userDb('userA');
  await assertFails(sendComment(a, 'userA', 'c1'));

  await seed(async (db) => {
    await db.doc('suspensions/userA').set({ suspended: true, until: new Date(Date.now() + 86400000) });
    await db.doc('comments/p1/postComments/antigo').set(commentData('userA', { createdAt: new Date() }));
  });
  await assertFails(sendComment(a, 'userA', 'c2'));
  await assertFails(a.doc('comments/p1/postComments/antigo').update({ text: 'editado', edited: true, editedAt: ts() }));

  await seed((db) => db.doc('suspensions/userA').set({ suspended: true, until: new Date(Date.now() - 1000) })); // venceu
  await assertSucceeds(sendComment(a, 'userA', 'c3'));
  // quem está suspenso ainda pode APAGAR o próprio comentário
  await seed((db) => db.doc('suspensions/userA').set({ suspended: true }));
  await assertSucceeds(a.doc('comments/p1/postComments/antigo').delete());
});

test('editar/excluir: só o autor edita; autor ou ADM exclui; outro usuário não', async () => {
  await seed((db) => db.doc('comments/p1/postComments/c1').set(commentData('userA', { createdAt: new Date() })));
  const edit = { text: 'novo texto', edited: true, editedAt: ts() };
  await assertFails(userDb('userB').doc('comments/p1/postComments/c1').update(edit));
  await assertSucceeds(userDb('userA').doc('comments/p1/postComments/c1').update(edit));
  await assertFails(userDb('userA').doc('comments/p1/postComments/c1').update({ ...edit, userId: 'userB' }));
  await assertFails(userDb('userB').doc('comments/p1/postComments/c1').delete());
  await assertSucceeds(userDb('adminUid').doc('comments/p1/postComments/c1').delete());
});

// ── Curtidas e contadores ────────────────────────────────────────────

const like = (db, uid, base = 'comments/p1/postComments/c1') => {
  const b = db.batch();
  b.set(db.doc(`${base}/likes/${uid}`), { likerUid: uid, createdAt: ts() });
  b.update(db.doc(base), { likesCount: inc(1) });
  return b.commit();
};
const unlike = (db, uid, base = 'comments/p1/postComments/c1') => {
  const b = db.batch();
  b.delete(db.doc(`${base}/likes/${uid}`));
  b.update(db.doc(base), { likesCount: inc(-1) });
  return b.commit();
};

test('curtidas: +1 só com a curtida do próprio usuário; duplicada e inflada são negadas', async () => {
  await seed((db) => db.doc('comments/p1/postComments/c1').set(commentData('userA', { createdAt: new Date() })));
  const b = userDb('userB');
  await assertFails(b.doc('comments/p1/postComments/c1').update({ likesCount: inc(1) }));   // contador sem curtida
  await assertSucceeds(like(b, 'userB'));
  await assertFails(like(b, 'userB'));                                                     // curtir duas vezes
  await assertFails(b.doc('comments/p1/postComments/c1').update({ likesCount: inc(1) }));   // mais um +1 solto
  await assertFails(b.doc('comments/p1/postComments/c1').update({ likesCount: 999 }));
  await assertFails(userDb('userC').doc('comments/p1/postComments/c1/likes/userB').set({ likerUid: 'userB', createdAt: ts() })); // curtir como outro
  await assertSucceeds(unlike(b, 'userB'));
  await assertFails(b.doc('comments/p1/postComments/c1').update({ likesCount: inc(-1) })); // -1 sem remover curtida
  await assertSucceeds(like(userDb('userC'), 'userC'));                                    // outro usuário curte normalmente
});

test('curtidas em respostas seguem a mesma regra', async () => {
  await seed(async (db) => {
    await db.doc('comments/p1/postComments/c1').set(commentData('userA', { createdAt: new Date() }));
    const { repliesCount, ...reply } = commentData('userA', { createdAt: new Date() });
    await db.doc('comments/p1/postComments/c1/replies/r1').set(reply);
  });
  const b = userDb('userB');
  const base = 'comments/p1/postComments/c1/replies/r1';
  await assertFails(b.doc(base).update({ likesCount: inc(1) }));
  await assertSucceeds(like(b, 'userB', base));
  await assertFails(like(b, 'userB', base));
  await assertSucceeds(unlike(b, 'userB', base));
});

// ── Respostas e contador de respostas ────────────────────────────────

function sendReply(db, uid, replyId = 'r1', parent = 'c1') {
  const b = db.batch();
  const { repliesCount, ...replyBody } = commentData(uid, { replyToUsername: 'maria' });
  b.set(db.doc(`comments/p1/postComments/${parent}/replies/${replyId}`), replyBody);
  b.update(db.doc(`comments/p1/postComments/${parent}`), { repliesCount: inc(1), lastReplyId: replyId });
  b.update(db.doc(`users_xp/${uid}`), { lastCommentAt: ts() });
  return b.commit();
}

test('respostas: contador +1 só junto com a resposta nova do próprio usuário', async () => {
  await seed((db) => db.doc('comments/p1/postComments/c1').set(commentData('userA', { createdAt: new Date() })));
  const b = userDb('userB');
  await assertFails(b.doc('comments/p1/postComments/c1').update({ repliesCount: inc(1), lastReplyId: 'fantasma' })); // resposta inexistente
  await assertSucceeds(sendReply(b, 'userB', 'r1'));
  await assertFails(b.doc('comments/p1/postComments/c1').update({ repliesCount: inc(1), lastReplyId: 'r1' })); // r1 já existia
  await assertFails(b.doc('comments/p1/postComments/c1').update({ repliesCount: 50, lastReplyId: 'r1' }));
  // resposta sem incrementar o contador também é recusada pelo cliente — aqui só garantimos o spam
  await assertFails(sendReply(b, 'userB', 'r2')); // menos de 10 s depois
});

test('respostas: suspenso não responde; excluir resposta decrementa junto; alheia não', async () => {
  await seed(async (db) => {
    await db.doc('comments/p1/postComments/c1').set(commentData('userA', { createdAt: new Date(), repliesCount: 1 }));
    const { repliesCount, ...r } = commentData('userB', { createdAt: new Date() });
    await db.doc('comments/p1/postComments/c1/replies/r1').set({ ...r, replyToUsername: 'maria' });
  });
  const delReply = (db, id = 'r1') => {
    const b = db.batch();
    b.delete(db.doc(`comments/p1/postComments/c1/replies/${id}`));
    b.update(db.doc('comments/p1/postComments/c1'), { repliesCount: inc(-1), lastReplyId: id });
    return b.commit();
  };
  await assertFails(delReply(userDb('userC')));                       // não é dela
  await assertFails(userDb('userC').doc('comments/p1/postComments/c1').update({ repliesCount: inc(-1), lastReplyId: 'r1' })); // -1 sem apagar
  await assertSucceeds(delReply(userDb('userB')));
  await seed((db) => db.doc('suspensions/userB').set({ suspended: true }));
  await assertFails(sendReply(userDb('userB'), 'userB', 'r9'));
});

// ── Notificações ─────────────────────────────────────────────────────

const likeNotif = (uid, extra = {}) => ({
  recipientUserId: 'userA', type: 'comment_like', actorUserId: uid, actorUserName: 'B', actorPhotoUrl: null,
  postId: 'p1', postTitle: 'T', commentId: 'c1', replyId: null, createdAt: ts(), read: false, ...extra,
});

test('notificação de curtida: só com a curtida real e id determinístico; sem spam em massa', async () => {
  await seed((db) => db.doc('comments/p1/postComments/c1').set(commentData('userA', { createdAt: new Date() })));
  const b = userDb('userB');
  await assertFails(b.doc('notifications/like_p1_c1_userB').set(likeNotif('userB')));        // sem curtida
  await assertSucceeds(like(b, 'userB'));
  await assertSucceeds(b.doc('notifications/like_p1_c1_userB').set(likeNotif('userB')));
  await assertFails(b.doc('notifications/qualquer_id').set(likeNotif('userB')));              // id arbitrário
  await assertFails(b.doc('notifications/like_p1_c1_userB').set(likeNotif('userC')));         // ator falso
  await assertFails(b.doc('notifications/like_p1_c9_userB').set(likeNotif('userB', { commentId: 'c9' }))); // comentário que não curtiu
  // reabrir (curtir de novo) só mexe em read/createdAt
  await assertSucceeds(b.doc('notifications/like_p1_c1_userB').update({ read: false, createdAt: ts() }));
  await assertFails(b.doc('notifications/like_p1_c1_userB').update({ recipientUserId: 'userC' }));
  // destinatário lê e marca como lida; outro não lê
  await assertSucceeds(userDb('userA').doc('notifications/like_p1_c1_userB').get());
  await assertFails(userDb('userC').doc('notifications/like_p1_c1_userB').get());
  await assertSucceeds(userDb('userA').doc('notifications/like_p1_c1_userB').update({ read: true }));
});

test('notificação de resposta: só para resposta existente do próprio ator', async () => {
  await seed(async (db) => {
    await db.doc('comments/p1/postComments/c1').set(commentData('userA', { createdAt: new Date() }));
    const { repliesCount, ...r } = commentData('userB', { createdAt: new Date() });
    await db.doc('comments/p1/postComments/c1/replies/r1').set({ ...r, replyToUsername: 'maria' });
  });
  const notif = (uid, extra = {}) => ({
    recipientUserId: 'userA', type: 'comment_reply', actorUserId: uid, actorUserName: 'B', actorPhotoUrl: null,
    postId: 'p1', postTitle: 'T', commentId: 'c1', replyId: 'r1', previewText: 'oi', createdAt: ts(), read: false, ...extra,
  });
  await assertSucceeds(userDb('userB').doc('notifications/reply_p1_r1').set(notif('userB')));
  await assertFails(userDb('userC').doc('notifications/reply_p1_r1').set(notif('userC')));           // resposta não é dele
  await assertFails(userDb('userB').doc('notifications/reply_p1_rX').set(notif('userB', { replyId: 'rX' }))); // resposta inexistente
});

// ── Visualizações e compartilhamentos ────────────────────────────────

const viewBatch = (db, uid, counters = 1) => {
  const b = db.batch();
  b.set(db.doc(`post_views/p1/viewers/${uid}`), {
    userId: uid, userName: 'X', userEmail: `${uid}@teste.com`, postId: 'p1', postTitle: 'T',
    firstViewedAt: ts(), lastViewedAt: ts(),
  });
  b.set(db.doc('post_views/p1'), { postId: 'p1', postTitle: 'T', totalViews: counters, uniqueViewers: counters, lastViewedAt: ts() }, { merge: true });
  return b.commit();
};

test('visualização única: uma vez por usuário; repetir o batch ou somar sozinho é negado', async () => {
  const a = userDb('userA');
  await assertSucceeds(viewBatch(a, 'userA', 1));
  await assertFails(viewBatch(a, 'userA', inc(1)));                              // mesma pessoa de novo
  await assertFails(a.doc('post_views/p1').set({ totalViews: inc(1), uniqueViewers: inc(1), lastViewedAt: ts() }, { merge: true }));
  await assertSucceeds(a.doc('post_views/p1/viewers/userA').update({ lastViewedAt: ts() })); // revisita
  await assertFails(a.doc('post_views/p1/viewers/userA').update({ userEmail: 'outro@x.com' }));
  await assertSucceeds(viewBatch(userDb('userB'), 'userB', inc(1)));
  await assertFails(userDb('userB').doc('post_views/p1/viewers/userA').set({ userId: 'userA' })); // viewer de outro
});

test('visualização: e-mail do leitor só para ele mesmo e ADM', async () => {
  await assertSucceeds(viewBatch(userDb('userA'), 'userA', 1));
  await assertSucceeds(userDb('userA').doc('post_views/p1/viewers/userA').get());
  await assertSucceeds(userDb('adminUid').doc('post_views/p1/viewers/userA').get());
  await assertFails(userDb('userB').doc('post_views/p1/viewers/userA').get());
  await assertSucceeds(anonDb().doc('post_views/p1').get()); // contador continua público
});

const shareBatch = (db, uid, counters = 1) => {
  const b = db.batch();
  b.set(db.doc(`post_shares/p1/sharers/${uid}`), { userId: uid, lastSharedAt: ts() }, { merge: true });
  b.set(db.doc('post_shares/p1'), { postId: 'p1', postTitle: 'T', totalShares: counters, lastSharedAt: ts() }, { merge: true });
  return b.commit();
};

test('compartilhamento: marca por usuário, no máximo 1 a cada 30 s; contador solto é negado', async () => {
  const a = userDb('userA');
  await assertSucceeds(shareBatch(a, 'userA', 1));
  await assertFails(shareBatch(a, 'userA', inc(1)));                     // de novo em seguida
  await assertFails(a.doc('post_shares/p1').set({ totalShares: inc(1), lastSharedAt: ts() }, { merge: true })); // sem a marca
  await seed((db) => db.doc('post_shares/p1/sharers/userA').update({ lastSharedAt: new Date(Date.now() - 120000) }));
  await assertSucceeds(shareBatch(a, 'userA', inc(1)));
  await assertSucceeds(shareBatch(userDb('userB'), 'userB', inc(1)));
});

// ── Assinaturas e coleções internas ──────────────────────────────────

const subReq = (uid, extra = {}) => ({
  uid, userName: 'Maria', userEmail: 'a@teste.com', plan: 'pro', productId: 'premium_pro_mensal',
  requestedAt: ts(), status: 'pendente', ...extra,
});

test('solicitação de assinatura: só pendente, com plano/produto coerentes, do próprio usuário', async () => {
  const a = userDb('userA');
  await assertSucceeds(a.collection('subscriptionRequests').add(subReq('userA')));
  await assertSucceeds(a.collection('subscriptionRequests').add(subReq('userA', { plan: 'ultra', productId: 'premium_ultra_mensal' })));
  await assertFails(a.collection('subscriptionRequests').add(subReq('userA', { plan: 'ultra' })));               // plano ≠ produto
  await assertFails(a.collection('subscriptionRequests').add(subReq('userA', { productId: 'premium_gratis' })));
  await assertFails(a.collection('subscriptionRequests').add(subReq('userA', { status: 'aprovada' })));
  await assertFails(a.collection('subscriptionRequests').add(subReq('userB')));
  await assertFails(a.collection('subscriptionRequests').add(subReq('userA', { isPaid: true })));
  await assertFails(a.collection('subscriptionRequests').add(subReq('userA', { requestedAt: new Date('2020-01-01') })));
  const ref = await a.collection('subscriptionRequests').add(subReq('userA'));
  await assertFails(ref.update({ status: 'aprovada' }));
  await assertSucceeds(userDb('adminUid').doc(`subscriptionRequests/${ref.id}`).update({ status: 'aprovada' }));
  await assertFails(userDb('userB').doc(`subscriptionRequests/${ref.id}`).get());
});

test('compras validadas pelo backend e livro-razão de XP: nenhum cliente (nem ADM pelo app) lê ou escreve', async () => {
  await seed(async (db) => {
    await db.doc('billing_purchases/abc').set({ uid: 'userA', active: true });
    await db.doc('xp_ledger/abc').set({ uid: 'userA' });
  });
  for (const col of ['billing_purchases', 'xp_ledger']) {
    await assertFails(userDb('userA').doc(`${col}/abc`).get());
    await assertFails(userDb('adminUid').doc(`${col}/abc`).get());
    await assertFails(userDb('userA').doc(`${col}/novo`).set({ uid: 'userA', active: true }));
    await assertFails(userDb('adminUid').doc(`${col}/novo`).set({ uid: 'userA' }));
  }
});

test('o usuário não concede Premium a si mesmo por nenhum caminho', async () => {
  const a = userDb('userA');
  await assertFails(a.doc('users_xp/userA').update({ premiumTier: 'ultra', premiumExpiresAt: new Date(Date.now() + 86400000 * 365) }));
  await assertFails(a.doc('users_xp/userA').set({ premiumTier: 'ultra' }, { merge: true }));
  // apagar e recriar o documento já como premium também é negado
  await assertSucceeds(a.doc('users_xp/userA').delete());
  await assertFails(a.doc('users_xp/userA').set({ uid: 'userA', totalXp: 0, level: 1, premiumTier: 'ultra' }));
  await assertSucceeds(a.doc('users_xp/userA').set({ uid: 'userA', totalXp: 0, level: 1 }));
});