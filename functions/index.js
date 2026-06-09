const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.notifyNewPost = functions.firestore
  .document('noticias/{postId}')
  .onCreate(async (snap) => {
    const post = snap.data();

    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('fcmToken', '!=', null)
      .where('notifGeral', '==', true)
      .get();

    const tokens = usersSnapshot.docs
      .map(doc => doc.data().fcmToken)
      .filter(Boolean);

    if (tokens.length === 0) return null;

    // Envia em lotes de 500 (limite do FCM)
    const chunks = [];
    for (let i = 0; i < tokens.length; i += 500) {
      chunks.push(tokens.slice(i, i + 500));
    }

    for (const chunk of chunks) {
      await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: {
          title: '🔴 Horizonte News',
          body: post.titulo ?? 'Nova notícia publicada!',
        },
        data: { postId: snap.id },
        android: {
          priority: 'high',
        },
        apns: {
          payload: { aps: { sound: 'default' } },
        },
      });
    }

    return null;
  });