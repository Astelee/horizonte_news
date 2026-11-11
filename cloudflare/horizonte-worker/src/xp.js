// XP creditado pelo servidor. Hoje: "curtida recebida" (+5 XP ao autor).
//
// Por que aqui e não no app: o crédito de XP para OUTRA pessoa não pode ser
// uma escrita liberada a qualquer usuário (era possível somar XP e trocar o
// nível de qualquer conta). O Worker confere que a curtida existe, que quem
// pede é quem curtiu e grava o XP + um registro em `xp_ledger` na MESMA
// transação — o registro impede pagar de novo se a pessoa descurtir e
// curtir outra vez (farm de XP).

import { HttpError, requireDocId, sha256Hex } from './util.js';

export const COMMENT_LIKE_XP = 5;

// Espelha XpService.xpRequiredForLevel: round(35 * (n-1)^2.15), nível 30 no máximo.
export const LEVEL_THRESHOLDS = [
  0, 35, 155, 371, 689, 1114, 1649, 2296, 3060, 3942, 4944, 6068, 7317, 8691, 10192,
  11821, 13581, 15472, 17495, 19651, 21942, 24369, 26933, 29633, 32473, 35452, 38571,
  41831, 45233, 48778,
];

export function levelFromXp(xp) {
  let level = 1;
  for (let i = 0; i < LEVEL_THRESHOLDS.length; i++) {
    if (xp >= LEVEL_THRESHOLDS[i]) level = i + 1;
  }
  return level;
}

export function createXpHandlers({ fs, now = () => Date.now() }) {
  return {
    /** Body: { postId, commentId, replyId? } — commentId é SEMPRE o comentário-raiz. */
    async like(caller, body) {
      const postId = requireDocId(body.postId, 'postId');
      const commentId = requireDocId(body.commentId, 'commentId');
      const replyId = body.replyId ? requireDocId(body.replyId, 'replyId') : null;

      const targetPath = replyId
        ? `comments/${postId}/postComments/${commentId}/replies/${replyId}`
        : `comments/${postId}/postComments/${commentId}`;

      const target = await fs.get(targetPath);
      if (!target) throw new HttpError(404, 'not_found', 'Comentário não encontrado.');
      const authorUid = String(target.userId ?? '');
      if (!authorUid) throw new HttpError(404, 'not_found', 'Autor não encontrado.');
      if (authorUid === caller.uid) return { ok: true, credited: false, reason: 'self' };

      const like = await fs.get(`${targetPath}/likes/${caller.uid}`);
      if (!like) throw new HttpError(403, 'like_not_found', 'Curtida não encontrada.');

      const ledgerId = await sha256Hex(`likexp|${postId}|${commentId}|${replyId ?? '-'}|${caller.uid}`);
      const authorPath = `users_xp/${authorUid}`;

      try {
        const result = await fs.runTransaction([authorPath], (docs) => {
          const author = docs[authorPath];
          if (!author) return null;
          const newXp = (Number(author.totalXp) || 0) + COMMENT_LIKE_XP;
          const data = { totalXp: newXp };
          // Com "override de nível" do admin ativo o nível não acompanha o XP.
          if (author.adminOverrideActive !== true) data.level = levelFromXp(newXp);
          return [
            { type: 'update', path: authorPath, data, mustExist: true },
            {
              type: 'create',
              path: `xp_ledger/${ledgerId}`,
              data: { kind: 'comment_like', authorUid, likerUid: caller.uid, xp: COMMENT_LIKE_XP, createdAt: new Date(now()) },
            },
          ];
        });
        return result.committed
          ? { ok: true, credited: true, xp: COMMENT_LIKE_XP }
          : { ok: true, credited: false, reason: 'author_missing' };
      } catch (e) {
        if (e instanceof HttpError && e.status === 409) {
          return { ok: true, credited: false, reason: 'already_credited' };
        }
        throw e;
      }
    },
  };
}