const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Node 20 (runtime declarado no package.json) já tem fetch nativo —
// não precisamos da dependência node-fetch.

// ═══════════════════════════════════════════════════════════════════
// OneSignal — notificação de nova notícia publicada
//
// A REST API Key do OneSignal NUNCA fica no app nem neste arquivo.
// Ela é lida de uma variável de ambiente da própria Cloud Function,
// configurada assim antes do deploy:
//
//   firebase functions:secrets:set ONESIGNAL_REST_API_KEY
//
// e referenciada abaixo via `secrets: ['ONESIGNAL_REST_API_KEY']` na
// definição da function (2ª geração). Se estiver usando functions de
// 1ª geração, use `firebase functions:config:set onesignal.key="..."`
// e troque `process.env.ONESIGNAL_REST_API_KEY` por
// `functions.config().onesignal.key`.
// ═══════════════════════════════════════════════════════════════════

const ONESIGNAL_APP_ID = '999de6a2-1965-4cb0-9558-a0cc8ed39828';
const ONESIGNAL_API_URL = 'https://onesignal.com/api/v1/notifications';

/**
 * Envia uma notificação push via OneSignal REST API para todos os
 * usuários inscritos, com additionalData.postId para deep-link.
 */
async function sendOneSignalNotification(post, postId) {
  if (!post) return;

  const restApiKey = process.env.ONESIGNAL_REST_API_KEY;
  if (!restApiKey) {
    console.error(
      'ONESIGNAL_REST_API_KEY não configurada — notificação não enviada.'
    );
    return;
  }

  const body = {
    app_id: ONESIGNAL_APP_ID,
    included_segments: ['Subscribed Users'],
    headings: { en: '🔴 Horizonte News', pt: '🔴 Horizonte News' },
    contents: {
      en: post.titulo || 'Nova notícia publicada!',
      pt: post.titulo || 'Nova notícia publicada!',
    },
    // Lido pelo listener de clique no app (NotificationService) para
    // navegar direto até a notícia.
    data: { postId },
    ios_badgeType: 'Increase',
    ios_badgeCount: 1,
  };

  const response = await fetch(ONESIGNAL_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      Authorization: `Basic ${restApiKey}`,
    },
    body: JSON.stringify(body),
  });

  const result = await response.json();
  if (!response.ok) {
    console.error('Falha ao enviar notificação OneSignal:', result);
  } else {
    console.log('Notificação OneSignal enviada:', result.id);
  }
}

// ── Notícia criada já publicada (publicar direto, sem passar por rascunho) ──
exports.notifyNewPost = functions
  .runWith({ secrets: ['ONESIGNAL_REST_API_KEY'] })
  .firestore.document('noticias/{postId}')
  .onCreate(async (snap, context) => {
    const post = snap.data();
    if (post.status !== 'publicado') return null;

    await sendOneSignalNotification(post, context.params.postId);
    return null;
  });

// ── Rascunho/despublicada que passa a 'publicado' (publicar depois) ──
exports.notifyPostPublished = functions
  .runWith({ secrets: ['ONESIGNAL_REST_API_KEY'] })
  .firestore.document('noticias/{postId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    const justPublished =
      before.status !== 'publicado' && after.status === 'publicado';
    if (!justPublished) return null;

    await sendOneSignalNotification(after, context.params.postId);
    return null;
  });