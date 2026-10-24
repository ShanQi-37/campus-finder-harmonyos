const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createApp } = require('./server.cjs');

test('草稿、任务摘要与可解释线索的完整HTTP行为', async t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'campus-experience-'));
  const file = path.join(dir, 'store.json'); let server, base;
  async function start() { server = createApp({ file, delay: 0 }); await new Promise(r => server.listen(0, '127.0.0.1', r)); base = `http://127.0.0.1:${server.address().port}`; }
  async function call(url, body, actor = 'demo-user', target = base) {
    const response = await fetch(target + url, { method: body === undefined ? 'GET' : 'POST', headers: { 'Content-Type': 'application/json', 'X-Demo-User': actor }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: response.status, ...(await response.json()) };
  }
  const partial = { title: '校园卡草稿', location: '', description: '', contact: '', occurredAt: '', kind: 'lost', category: '证件卡片', requestId: 'draft-partial' };
  const full = { ...partial, title: '寻找蓝色校园卡', location: '图书馆一楼', description: '蓝色卡套，背面有白色贴纸，演示信息。', contact: '服务台核对（演示）', occurredAt: new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' }) };
  await start();
  try {
    await t.test('保存不完整草稿、身份隔离、重启恢复与字段边界', async () => {
      assert.equal((await call('/api/draft')).data.exists, false);
      assert.equal((await call('/api/draft', partial)).status, 200);
      assert.deepEqual((await call('/api/draft')).data.input, partial);
      assert.equal((await call('/api/draft', undefined, 'peer-01')).data.exists, false);
      for (const invalid of [{ ...partial, title: '长'.repeat(37) }, { ...partial, requestId: '' }, { ...partial, category: '未知' }, { ...partial, title: 12 }]) assert.equal((await call('/api/draft', invalid)).status, 400);
      await new Promise(r => server.close(r)); await start();
      assert.deepEqual((await call('/api/draft')).data.input, partial);
      assert.equal((await call('/api/me')).data.draftTitle, partial.title);
    });
    let published;
    await t.test('成功发布原子清理对应草稿，失败不丢草稿，重复提交不清理其他新草稿', async () => {
      assert.equal((await call('/api/items', partial)).status, 400);
      assert.equal((await call('/api/draft')).data.exists, true);
      published = (await call('/api/items', full)).data;
      assert.equal((await call('/api/draft')).data.exists, false);
      await call('/api/draft', { ...partial, requestId: 'newer-draft' });
      assert.equal((await call('/api/items', full)).data.id, published.id);
      assert.equal((await call('/api/draft')).data.input.requestId, 'newer-draft');
    });
    await t.test('线索只返回开放、相反类型、同类、不同发布者；理由和排序可解释且不泄露联系人', async () => {
      const matching = (await call('/api/items', { ...full, requestId: 'candidate-best', kind: 'found', title: '拾到蓝色校园卡', location: full.location }, 'peer-01')).data;
      const own = (await call('/api/items', { ...full, requestId: 'candidate-own', kind: 'found' })).data;
      const closed = (await call('/api/items', { ...full, requestId: 'candidate-closed', kind: 'found' }, 'peer-02')).data;
      await call(`/api/items/${closed.id}/resolve`, {}, 'peer-02');
      const withdrawn = (await call('/api/items', { ...full, requestId: 'candidate-withdrawn', kind: 'found' }, 'peer-02')).data;
      await call(`/api/items/${withdrawn.id}/withdraw`, {}, 'peer-02');
      const matches = (await call(`/api/items/${published.id}/matches`)).data.matches;
      assert.equal(matches[0].item.id, matching.id);
      assert.deepEqual(matches[0].reasons, ['同类物品', '同一地点', '日期相近']);
      assert.equal(matches[0].item.contactVisible, false); assert.notEqual(matches[0].item.contact, full.contact);
      assert.ok(matches.every(m => m.item.kind === 'found' && m.item.category === full.category && m.item.status === 'open' && m.item.owner !== 'demo-user'));
      assert.ok(!matches.some(m => [own.id, closed.id, withdrawn.id, published.id].includes(m.item.id)));
      assert.deepEqual((await call(`/api/items/${closed.id}/matches`)).data.matches, []);
      assert.equal((await call(`/api/items/${withdrawn.id}/matches`)).status, 404);
    });
    await t.test('任务摘要随收藏和核对申请变化，且与列表保持一致', async () => {
      await call('/api/items/seed-3/favorite', { saved: true });
      await call('/api/items/seed-3/claims', { proof: '白色充电盒，内侧有一枚贴纸（演示）。', contact: '服务台转接（演示）' });
      const summary = (await call('/api/me')).data;
      assert.equal(summary.posted, (await call('/api/items?owner=demo-user')).data.total);
      assert.equal(summary.saved, (await call('/api/items?saved=true')).data.total);
      assert.equal(summary.outgoingPending, (await call('/api/claims?direction=sent')).data.pending);
      assert.equal((await call('/api/me', undefined, 'peer-02')).data.incomingPending, 1);
      await call('/__test/mode', { mode: 'empty' });
      assert.equal((await call('/api/me')).data.posted, 0); assert.equal((await call('/api/draft')).data.exists, false);
      await call('/__test/mode', { mode: 'normal' });
    });
    await t.test('列表删除或筛选后越界分页自动回到有效末页', async () => {
      const page = (await call('/api/items?page=999&pageSize=2&owner=demo-user')).data;
      assert.equal(page.page, Math.ceil(page.total / 2)); assert.ok(page.items.length); assert.equal(page.hasMore, false);
      const empty = (await call('/api/items?page=999&pageSize=2&keyword=does-not-exist')).data;
      assert.equal(empty.page, 1); assert.equal(empty.total, 0);
    });
    await t.test('磁盘失败时草稿和发布一起回滚，旧快照兼容新增草稿字段', async () => {
      const atomicDir = path.join(dir, 'atomic'); fs.mkdirSync(atomicDir);
      const atomicFile = path.join(atomicDir, 'store.json');
      const raw = JSON.parse(fs.readFileSync(file)); raw.drafts = [{ actor: 'demo-user', input: { ...full, requestId: 'atomic' }, updatedAt: new Date().toISOString() }];
      fs.writeFileSync(atomicFile, JSON.stringify(raw));
      const failing = createApp({ file: atomicFile, delay: 0 });
      fs.unlinkSync(atomicFile); fs.rmdirSync(atomicDir); fs.writeFileSync(atomicDir, 'block');
      await new Promise(r => failing.listen(0, '127.0.0.1', r)); const target = `http://127.0.0.1:${failing.address().port}`;
      try {
        assert.equal((await call('/api/draft', partial, 'demo-user', target)).status, 500);
        assert.equal((await call('/api/draft', undefined, 'demo-user', target)).data.input.requestId, 'atomic');
        const before = (await call('/api/me', undefined, 'demo-user', target)).data.posted;
        assert.equal((await call('/api/items', { ...full, requestId: 'atomic' }, 'demo-user', target)).status, 500);
        assert.equal((await call('/api/draft', undefined, 'demo-user', target)).data.exists, true);
        assert.equal((await call('/api/me', undefined, 'demo-user', target)).data.posted, before);
      } finally { await new Promise(r => failing.close(r)); }
      const legacy = JSON.parse(fs.readFileSync(file)); delete legacy.drafts;
      const legacyFile = path.join(dir, 'legacy.json'); fs.writeFileSync(legacyFile, JSON.stringify(legacy));
      const migrated = createApp({ file: legacyFile, delay: 0 }); await new Promise(r => migrated.listen(0, '127.0.0.1', r));
      try { assert.equal((await call('/api/draft', partial, 'demo-user', `http://127.0.0.1:${migrated.address().port}`)).status, 200); } finally { await new Promise(r => migrated.close(r)); }
    });
  } finally {
    await new Promise(r => server.close(r));
    assert.ok(path.resolve(dir).startsWith(path.resolve(os.tmpdir()) + path.sep)); fs.rmSync(dir, { recursive: true, force: true });
  }
});
