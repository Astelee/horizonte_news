// Página de compartilhamento de notícia: GET /noticia/{id}
//
// O WhatsApp, o Telegram etc. montam a prévia do link (foto + título +
// resumo) lendo as tags Open Graph do HTML — e NÃO executam JavaScript.
// A página estática do Firebase Hosting é uma só para todas as matérias,
// então a prévia saía sem foto. Aqui cada matéria devolve o próprio HTML
// com as tags dela; o redirecionamento para a Play Store (com o postId no
// referrer, lido por DeepLinkService._checkInstallReferrer) continua igual.
//
// Quem já tem o app instalado nunca chega aqui: o Android abre o app
// direto pelo App Link verificado.

const DEFAULT_HOST = 'horizontenews.app.br';
const PACKAGE_FALLBACK = 'com.astelee.horizonte_news';
const POST_ID = /^[A-Za-z0-9_-]{1,100}$/;

export function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** Texto puro (sem tags HTML), em uma linha, com limite de tamanho. */
export function plainText(value, max) {
  const text = String(value ?? '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return text.length > max ? `${text.slice(0, max - 1).trimEnd()}…` : text;
}

/**
 * Imagem da prévia: a capa da matéria (ou um frame do vídeo). Imagens do
 * Cloudinary são reduzidas para 1200x630 — o WhatsApp descarta imagens
 * pesadas demais (~300 KB).
 */
export function previewImage(post, host) {
  const fallback = `https://${host}/noticia/icon.png`;
  const cover = typeof post.capaUrl === 'string' ? post.capaUrl.trim() : '';
  if (/^https:\/\//i.test(cover)) {
    return cover.includes('res.cloudinary.com') && cover.includes('/image/upload/')
      ? cover.replace('/image/upload/', '/image/upload/c_fill,w_1200,h_630,q_auto,f_jpg/')
      : cover;
  }
  const video = typeof post.videoUrl === 'string' ? post.videoUrl.trim() : '';
  if (/^https:\/\/res\.cloudinary\.com\//i.test(video) && video.includes('/video/upload/')) {
    return video
      .replace('/video/upload/', '/video/upload/so_1,c_fill,w_1200,h_630,q_auto/')
      .replace(/\.[A-Za-z0-9]+(\?.*)?$/, '.jpg');
  }
  return fallback;
}

export function renderPage({ post, postId, host, packageName }) {
  const title = escapeHtml(plainText(post?.titulo, 120) || 'Horizonte News');
  const description = escapeHtml(
    plainText(post?.resumo, 200) || plainText(post?.conteudo, 200) || 'Leia a matéria completa no Horizonte News.',
  );
  const image = escapeHtml(post ? previewImage(post, host) : `https://${host}/noticia/icon.png`);
  const pageUrl = escapeHtml(`https://${host}/noticia/${postId}`);
  const pkg = JSON.stringify(packageName).replace(/</g, '\\u003c');
  const id = JSON.stringify(postId).replace(/</g, '\\u003c');

  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${title} | Horizonte News</title>
<meta name="description" content="${description}" />
<meta property="og:type" content="article" />
<meta property="og:site_name" content="Horizonte News" />
<meta property="og:locale" content="pt_BR" />
<meta property="og:title" content="${title}" />
<meta property="og:description" content="${description}" />
<meta property="og:image" content="${image}" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:url" content="${pageUrl}" />
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="${title}" />
<meta name="twitter:description" content="${description}" />
<meta name="twitter:image" content="${image}" />
<style>
  body{margin:0;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;padding:24px;box-sizing:border-box;background:#000;color:#fff;font-family:system-ui,sans-serif;text-align:center}
  img.logo{width:84px;height:84px;border-radius:20px}
  h1{font-size:19px;margin:0;max-width:520px}
  p{margin:0;color:rgba(255,255,255,.65);font-size:14px}
  a.button{background:#ff6b00;color:#fff;text-decoration:none;font-weight:700;padding:13px 26px;border-radius:12px}
</style>
</head>
<body>
  <img class="logo" src="/noticia/icon.png" alt="Horizonte News" />
  <h1>${title}</h1>
  <p>Abrindo no Horizonte News… Se o app não abrir, baixe-o abaixo.</p>
  <a class="button" id="storeLink" href="#">Baixar na Play Store</a>
  <script>
    var postId = ${id};
    var referrer = postId ? '&referrer=' + encodeURIComponent('postId=' + postId) : '';
    var playStoreUrl = 'https://play.google.com/store/apps/details?id=' + ${pkg} + referrer;
    document.getElementById('storeLink').href = playStoreUrl;
    setTimeout(function () { window.location.replace(playStoreUrl); }, 300);
  </script>
</body>
</html>`;
}

const HTML_HEADERS = {
  'content-type': 'text/html; charset=utf-8',
  'cache-control': 'public, max-age=300',
};

export function createShareHandler({ fs, env = {} }) {
  const host = env.PUBLIC_HOST || DEFAULT_HOST;
  const packageName = env.ANDROID_PACKAGE_NAME || PACKAGE_FALLBACK;

  return async function handleShare(request, postId) {
    const head = request.method === 'HEAD';
    const respond = (body, status = 200, headers = HTML_HEADERS) =>
      new Response(head ? null : body, { status, headers });

    // Id inválido nem consulta o Firestore.
    if (!POST_ID.test(postId)) {
      return respond(renderPage({ post: null, postId: '', host, packageName }));
    }

    let post = null;
    try {
      const doc = await fs.get(`noticias/${postId}`);
      // Só matéria publicada vira prévia (rascunho/despublicada não vaza).
      if (doc && doc.status === 'publicado') post = doc;
    } catch (e) {
      console.error('share: falha ao ler notícia', e);
    }
    return respond(renderPage({ post, postId, host, packageName }), 200, post ? HTML_HEADERS : { ...HTML_HEADERS, 'cache-control': 'public, max-age=60' });
  };
}