import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeTokenIssuer } from './helpers.js';

const unauthorized = (msg) => (e) => e.status === 401 && e.code === 'unauthorized' && e.message === msg;

test('token válido devolve o uid', async () => {
  const { issue, verifier } = await makeTokenIssuer();
  const r = await verifier(await issue({ sub: 'abc123' }));
  assert.equal(r.uid, 'abc123');
});

test('token expirado é recusado (pelo motivo certo)', async () => {
  const { issue, verifier } = await makeTokenIssuer();
  const old = Math.floor(Date.now() / 1000) - 7200;
  const token = await issue({}, { nowSec: old });
  await assert.rejects(() => verifier(token), unauthorized('Token expirado.'));
});

test('token emitido no futuro é recusado', async () => {
  const { issue, verifier } = await makeTokenIssuer();
  const token = await issue({}, { nowSec: Math.floor(Date.now() / 1000) + 3600 });
  await assert.rejects(() => verifier(token), unauthorized('Token emitido no futuro.'));
});

test('projeto (aud) e emissor (iss) errados são recusados', async () => {
  const { issue, verifier } = await makeTokenIssuer();
  await assert.rejects(async () => verifier(await issue({ aud: 'outro-projeto' })), unauthorized('Projeto inválido.'));
  await assert.rejects(async () => verifier(await issue({ iss: 'https://evil.example' })), unauthorized('Emissor inválido.'));
});

test('uid vazio é recusado', async () => {
  const { issue, verifier } = await makeTokenIssuer();
  await assert.rejects(async () => verifier(await issue({ sub: '' })), unauthorized('Usuário inválido.'));
});

test('payload adulterado (assinatura não confere) é recusado', async () => {
  const { issue, verifier } = await makeTokenIssuer();
  const t = await issue({ sub: 'userA' });
  const [h, , s] = t.split('.');
  const now = Math.floor(Date.now() / 1000);
  const forgedPayload = Buffer.from(
    JSON.stringify({ sub: 'adminUid', aud: 'horizontenews-6b48f', iss: 'https://securetoken.google.com/horizontenews-6b48f', iat: now, exp: now + 3600 }),
  ).toString('base64url');
  await assert.rejects(() => verifier([h, forgedPayload, s].join('.')), unauthorized('Assinatura inválida.'));
});

test('assinado por outra chave, alg diferente, lixo e ausência são recusados', async () => {
  const { issue, verifier } = await makeTokenIssuer();
  const other = await makeTokenIssuer(); // mesma "kid", mas outra chave privada
  await assert.rejects(async () => verifier(await other.issue({})), unauthorized('Assinatura inválida.'));
  await assert.rejects(async () => verifier(await issue({}, { alg: 'none' })), unauthorized('Algoritmo inválido.'));
  await assert.rejects(() => verifier('lixo'), unauthorized('Token ausente ou malformado.'));
  await assert.rejects(() => verifier(undefined), unauthorized('Token ausente ou malformado.'));
  await assert.rejects(() => verifier('a.b.c'), unauthorized('Token ilegível.'));
});

test('kid desconhecido é recusado', async () => {
  const { issue, verifier } = await makeTokenIssuer();
  await assert.rejects(async () => verifier(await issue({}, { kid: 'nao-existe' })), unauthorized('Chave desconhecida.'));
});