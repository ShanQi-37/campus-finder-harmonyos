const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createApp } = require('./server.cjs');
test('HTTP业务闭环、校验、容错和持久化', async t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'campusfinder-test-'));
  const file = path.join(dir, 'items.json');
  let server = createApp({ file, delay: 0 });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let base = `http://127.0.0.1:${server.address().port}`;
  const get = async p => (await fetch(base + p)).json();
  const post = async (p, body) => fetch(base + p, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  try {
    await t.test('列表、类型、关键词、分类和本人记录筛选', async () => {
      assert.equal((await get('/api/items')).data.total, 12);
      assert.ok((await get('/api/items?kind=lost')).data.items.every(i => i.kind === 'lost'));
      assert.equal((await get('/api/items?keyword=' + encodeURIComponent('保温杯'))).data.total, 1);
      assert.equal((await get('/api/items?keyword=___missing___')).data.total, 0);
      assert.equal((await get('/api/items?category=' + encodeURIComponent('电子数码'))).data.total, 3);
      assert.equal((await get('/api/items?owner=demo-user')).data.total, 3);
    });
    await t.test('拒绝不合法发布、畸形JSON、越权寻回与不存在详情', async () => {
      assert.equal((await post('/api/items', {})).status, 400);
      assert.equal((await post('/api/items/seed-1/resolve', {})).status, 403);
      assert.equal((await get('/api/items/missing')).code, 404);
      assert.equal((await fetch(base + '/api/items', { method: 'POST', body: '{bad' })).status, 400);
    });
    await t.test('拒绝非对象JSON与畸形物品标识，服务继续可用', async () => {
      for (const body of [null, [], 7, 'invalid']) {
        assert.equal((await post('/api/items', body)).status, 400);
        assert.equal((await post('/__test/mode', body)).status, 400);
      }
      assert.equal((await get('/api/items/%ZZ')).code, 400);
      assert.equal((await get('/api/items')).data.total, 12);
    });
    await t.test('发布后列表和三个统计指标同步更新，重复寻回幂等', async () => {
      const before = (await get('/api/statistics')).data;
      const response = await post('/api/items', { title: '测试物品校园卡', location: '测试服务台', description: '这是用于验证网络数据变化的演示物品。', contact: '校园服务台', kind: 'found', category: '证件卡片' });
      assert.equal(response.status, 201);
      const item = (await response.json()).data;
      assert.equal((await get('/api/items/' + item.id)).data.title, '测试物品校园卡');
      let stats = (await get('/api/statistics')).data;
      assert.equal(stats.total, before.total + 1);
      assert.equal(stats.categories[0].count, before.categories[0].count + 1);
      assert.equal(stats.trend.at(-1).count, before.trend.at(-1).count + 1);
      assert.equal((await post(`/api/items/${item.id}/resolve`, {})).status, 200);
      await post(`/api/items/${item.id}/resolve`, {});
      stats = (await get('/api/statistics')).data;
      assert.equal(stats.resolved, before.resolved + 1);
      assert.equal(stats.recoveryRate, Math.round(stats.resolved / stats.total * 100));
    });
    await t.test('服务异常、空数据、无效JSON与恢复', async () => {
      await post('/__test/mode', { mode: 'error' }); assert.equal((await get('/api/items')).code, 503);
      await post('/__test/mode', { mode: 'empty' }); assert.equal((await get('/api/items')).data.total, 0);
      assert.equal((await get('/api/statistics')).data.recoveryRate, 0);
      await post('/__test/mode', { mode: 'malformed' }); await assert.rejects(get('/api/items'));
      await post('/__test/mode', { mode: 'normal' }); assert.equal((await get('/api/items')).data.total, 13);
    });
    await t.test('重启后发布和寻回状态仍存在', async () => {
      await new Promise(resolve => server.close(resolve));
      server = createApp({ file, delay: 0 }); await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
      base = `http://127.0.0.1:${server.address().port}`;
      assert.equal((await get('/api/items')).data.total, 13);
      assert.equal((await get('/api/statistics')).data.resolved, 5);
    });
    await t.test('持久化失败不会新增记录或提前标记寻回', async () => {
      const blockedParent = path.join(dir, 'blocked-parent');
      fs.writeFileSync(blockedParent, 'This file deliberately blocks a data directory.');
      const failing = createApp({ file: path.join(blockedParent, 'items.json'), delay: 0 });
      await new Promise(resolve => failing.listen(0, '127.0.0.1', resolve));
      const failedBase = `http://127.0.0.1:${failing.address().port}`;
      try {
        const failedPost = async (p, body) => fetch(failedBase + p, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
        assert.equal((await failedPost('/api/items', { title: '未保存物品', location: '测试地点', description: '这条记录应因磁盘写入失败而不产生。', contact: '测试服务台', kind: 'lost', category: '证件卡片' })).status, 500);
        assert.equal((await (await fetch(failedBase + '/api/items')).json()).data.total, 12);
        assert.equal((await failedPost('/api/items/seed-2/resolve', {})).status, 500);
        assert.equal((await (await fetch(failedBase + '/api/items/seed-2')).json()).data.status, 'open');
        const statistics = (await (await fetch(failedBase + '/api/statistics')).json()).data;
        assert.equal(statistics.resolved, 4);
        assert.equal(statistics.recoveryRate, 33);
      } finally { await new Promise(resolve => failing.close(resolve)); }
    });
  } finally {
    await new Promise(resolve => server.close(resolve));
    // Remove only this test's unique temp directory after resolving its bounds.
    assert.ok(path.resolve(dir).startsWith(path.resolve(os.tmpdir()) + path.sep));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
