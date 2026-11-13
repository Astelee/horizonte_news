import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/index.js';
import { createShareHandler, escapeHtml, plainText, previewImage } from '../src/share.js';
import { fakeFirestore } from './helpers.js';

const POST = {
  status: 'publicado',
  titulo: 'Ataque "hacker" <b>expõe</b> dados',
  resumo: '<p>Segundo o órgão, não houve impacto.</p>',
  capaUrl: 'https://res.cloudinary.com/demo/image/upload/v1/pasta/capa.jpg',
};
const ID = 'abc123';
const get = (share, id = ID, method = 'GET') =>
  share(new Request(`https://x.test/noticia/${id}`, { method }), id);

test('matéria publicada: devolve og:title, og:description e og:image da própria matéria', async () => {
  const share = createShareHandler({ fs: fakeFirestore({ [`noticias/${ID}`]: POST }) });
  const res = await get(share);
  const html = await res.text();
  assert.equal(res.status, 200);
  assert.match(html, /<meta property="og:title" content="Ataque &quot;hacker&quot; expõe dados" \/>/);
  assert.match(html, /og:description" content="Segundo o órgão, não houve impacto\." \/>/);
  assert.match(html, /og:image" content="https:\/\/res\.cloudinary\.com\/demo\/image\/upload\/c_fill,w_1200,h_630,q_auto,f_jpg\/v1\/pasta\/capa\.jpg"/);
  assert.match(html, /og:url" content="https:\/\/horizontenews\.app\.br\/noticia\/abc123"/);
  assert.match(html, /referrer=/); // o fluxo de instalação com postId continua
  assert.equal(html.includes('<b>'), false); // sem HTML cru do título
});

test('rascunho, despublicada ou inexistente: página genérica, sem vazar o conteúdo', async () => {
  for (const doc of [{ ...POST, status: 'rascunho' }, { ...POST, status: 'despublicado' }, null]) {
    const share = createShareHandler({ fs: fakeFirestore(doc ? { [`noticias/${ID}`]: doc } : {}) });
    const html = await (await get(share)).text();
    assert.equal(html.includes('hacker'), false);
    assert.match(html, /og:image" content="https:\/\/horizontenews\.app\.br\/noticia\/icon\.png"/);
  }
});

test('id inválido não consulta o Firestore; falha do Firestore não derruba a página', async () => {
  const fs = fakeFirestore({});
  let reads = 0;
  const share = createShareHandler({ fs: { get: async () => { reads++; return null; } } });
  await get(share, '../../etc/passwd');
  assert.equal(reads, 0);
  const broken = createShareHandler({ fs: { get: async () => { throw new Error('boom'); } } });
  assert.equal((await get(broken)).status, 200);
  assert.ok(fs);
});

test('HEAD não devolve corpo; sem capa usa frame do vídeo ou o ícone', async () => {
  const share = createShareHandler({ fs: fakeFirestore({ [`noticias/${ID}`]: POST }) });
  const res = await get(share, ID, 'HEAD');
  assert.equal(res.status, 200);
  assert.equal(await res.text(), '');
  assert.match(previewImage({ videoUrl: 'https://res.cloudinary.com/demo/video/upload/v1/a/v.mp4' }, 'h'), /video\/upload\/so_1,c_fill,w_1200,h_630,q_auto\/v1\/a\/v\.jpg$/);
  assert.equal(previewImage({}, 'h.com'), 'https://h.com/noticia/icon.png');
  assert.equal(previewImage({ capaUrl: 'http://inseguro/x.jpg' }, 'h.com'), 'https://h.com/noticia/icon.png');
});

test('escapeHtml/plainText', () => {
  assert.equal(escapeHtml(`<a href="x">'&`), '&lt;a href=&quot;x&quot;&gt;&#39;&amp;');
  assert.equal(plainText('<p>a</p>  <p>b&nbsp;c</p>', 100), 'a b c');
  assert.equal(plainText('x'.repeat(50), 10).length, 10);
});

test('rota /noticia/{id} do Worker responde GET e não aceita POST', async () => {
  const share = createShareHandler({ fs: fakeFirestore({ [`noticias/${ID}`]: POST }) });
  const app = createApp({ env: {}, verifyIdToken: async () => ({}), notify: {}, billing: {}, share });
  const ok = await app(new Request(`https://api.test/noticia/${ID}`));
  assert.equal(ok.status, 200);
  assert.match(ok.headers.get('content-type'), /text\/html/);
  const post = await app(new Request(`https://api.test/noticia/${ID}`, { method: 'POST' }));
  assert.equal(post.status, 404);
});