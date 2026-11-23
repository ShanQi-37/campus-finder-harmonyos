const test = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const { createApp } = require('./server.cjs');
const { photoFunnel } = require('./search.cjs');

test('描述找物返回可编辑条件并按实际发生日期搜索', async t => {
  let reply;
  let received;
  const server = createApp({ memory: true, delay: 0, interpretSearch: async (query, today) => {
    received = { query, today };
    return reply;
  } });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  const get = async path => fetch(base + path);
  const post = async (path, body) => fetch(base + path, { method: 'POST', body: JSON.stringify(body) });
  const today = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' });
  const yesterday = new Date(Date.parse(today) - 86400000).toISOString().slice(0, 10);
  reply = { keyword: '透明 收纳夹', location: '图书馆', category: '学习文具', occurredFrom: yesterday, occurredTo: yesterday };
  const interpreted = await post('/api/search/interpret', { query: '昨天在图书馆遗失了透明收纳夹' });
  assert.equal(interpreted.status, 200);
  assert.deepEqual((await interpreted.json()).data, reply);
  assert.equal(received.today, today);
  assert.equal(received.query, '昨天在图书馆遗失了透明收纳夹');
  const fixture = { kind: 'found', category: '学习文具', title: '拾到透明收纳夹', location: '图书馆一楼',
    description: '整理时发现一个带贴纸的透明收纳夹。', contact: '服务台核对', occurredAt: yesterday };
  const inRange = await post('/api/items', fixture);
  assert.equal(inRange.status, 201);
  const id = (await inRange.json()).data.id;
  assert.equal((await post('/api/items', { ...fixture, occurredAt: today })).status, 201);
  assert.equal((await post('/api/items', { ...fixture, location: '志愿服务台' })).status, 201);
  const filtered = await get('/api/items?' + new URLSearchParams({ ...reply, kind: 'found', status: 'open' }));
  assert.equal(filtered.status, 200);
  assert.deepEqual((await filtered.json()).data.items.map(item => item.id), [id]);
  assert.equal((await get('/api/items?occurredTo=' + today)).status, 400);
  assert.equal((await post('/api/search/interpret', { query: 'x'.repeat(161) })).status, 400);
  reply = { ...reply, occurredFrom: '2026-02-31' };
  assert.equal((await post('/api/search/interpret', { query: '昨天的收纳夹' })).status, 422);
});

test('拍照统计按查找日期筛选、按查找次数去重', () => {
  const searches = [
    { id: 'one', day: '2026-11-17', candidateIds: ['item'] },
    { id: 'two', day: '2026-11-23', candidateIds: [] },
    { id: 'old', day: '2026-11-16', candidateIds: ['item'] },
    { id: 'future', day: '2026-11-24', candidateIds: ['item'] }
  ];
  const claims = [
    { photoSearchId: 'one', status: 'rejected' },
    { photoSearchId: 'one', status: 'accepted' },
    { photoSearchId: 'two', status: 'accepted' },
    { photoSearchId: 'old', status: 'accepted' },
    { status: 'accepted' }
  ];
  assert.deepEqual(photoFunnel(searches, claims, 7, '2026-11-23'), {
    days: 7, start: '2026-11-17', end: '2026-11-23', recognized: 2, matched: 1, applied: 1, recovered: 1
  });
});
