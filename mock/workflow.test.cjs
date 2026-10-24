const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createApp, seed } = require('./server.cjs');

test('第二版：多角色业务状态机及原子持久化', async t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'campusfinder-workflow-'));
  const file = path.join(dir, 'items.json');
  // Start from the first-version file format, not an empty v2 database.
  fs.writeFileSync(file, JSON.stringify(seed()));
  let server, base;
  const start = async () => {
    server = createApp({ file, delay: 0 });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    base = `http://127.0.0.1:${server.address().port}`;
  };
  const call = async (route, body, actor = 'demo-user', target = base) => {
    const response = await fetch(target + route, { method: body === undefined ? 'GET' : 'POST', headers: { 'Content-Type': 'application/json', 'X-Demo-User': actor }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: response.status, ...(await response.json()) };
  };
  const input = { title: '蓝色演示耳机盒', category: '电子数码', kind: 'found', location: '校园服务台', description: '盒底有一枚月亮贴纸，请描述型号和外观特征。', contact: '服务台转接（虚构）' };
  const proof = { proof: '耳机盒底部贴有月亮贴纸，能够到服务台出示配对记录。', contact: '志愿服务台留言（虚构）' };
  let itemId, acceptedId;
  await start();
  try {
    await t.test('旧数组迁移保留记录，发布幂等且按身份持久化', async () => {
      assert.equal((await call('/api/items')).data.total, 12);
      const a = await call('/api/items', { ...input, requestId: 'stable-create-1' }, 'peer-01');
      const b = await call('/api/items', { ...input, requestId: 'stable-create-1' }, 'peer-01');
      assert.equal(a.status, 201); assert.equal(a.data.id, b.data.id); itemId = a.data.id;
      assert.equal((await call('/api/items')).data.total, 13);
      const disk = JSON.parse(fs.readFileSync(file));
      assert.equal(disk.version, 2); assert.equal(disk.items.length, 13); assert.deepEqual(disk.claims, []);
    });
    await t.test('标题、时间、身份及分页的边界输入被拒绝', async () => {
      for (const occurredAt of ['2099-01-01', '2026-02-30', 'invalid', 123]) assert.equal((await call('/api/items', { ...input, occurredAt })).status, 400);
      assert.equal((await call('/api/items', { ...input, title: 'a' })).status, 400);
      assert.equal((await call('/api/items', { ...input, requestId: 3 })).status, 400);
      assert.equal((await call('/api/items', input, 'unknown')).status, 400);
      for (const query of ['page=0', 'page=1.5', 'pageSize=101', 'pageSize=NaN']) assert.equal((await call('/api/items?' + query)).status, 400);
      assert.equal((await call('/api/statistics?days=8')).status, 400);
    });
    await t.test('分页、排序和组合筛选返回正确范围，收藏隔离且幂等', async () => {
      const p1 = (await call('/api/items?pageSize=3')).data, p2 = (await call('/api/items?pageSize=3&page=2')).data;
      assert.equal(p1.items.length, 3); assert.equal(p1.total, 13); assert.equal(p1.hasMore, true);
      assert.ok(p1.items.every(i => !p2.items.some(j => i.id === j.id)));
      const oldest = (await call('/api/items?sort=oldest')).data.items;
      assert.ok(oldest.every((row, i) => !i || row.createdAt >= oldest[i - 1].createdAt));
      assert.equal((await call('/api/items?kind=found&category=' + encodeURIComponent('电子数码') + '&keyword=' + encodeURIComponent('月亮'))).data.total, 1);
      await call(`/api/items/${itemId}/favorite`, { saved: true }); await call(`/api/items/${itemId}/favorite`, { saved: true });
      assert.equal((await call('/api/items?saved=true')).data.total, 1);
      assert.equal((await call('/api/items?saved=true', undefined, 'peer-02')).data.total, 0);
      await call(`/api/items/${itemId}/favorite`, { saved: false }); assert.equal((await call('/api/items?saved=true')).data.total, 0);
    });
    await t.test('本人编辑权限、待审核类别约束、重复申请与隐私保护', async () => {
      assert.equal((await call(`/api/items/${itemId}/update`, input)).status, 403);
      assert.equal((await call(`/api/items/${itemId}/update`, { ...input, title: '更新后的蓝色演示耳机盒' }, 'peer-01')).status, 200);
      assert.equal((await call(`/api/items/${itemId}`)).data.contactVisible, false);
      assert.equal((await call(`/api/items/${itemId}`)).data.myPending, false);
      assert.equal((await call(`/api/items/${itemId}`, undefined, 'peer-01')).data.contactVisible, true);
      assert.equal((await call(`/api/items/${itemId}/claims`, proof, 'peer-01')).status, 403);
      assert.equal((await call(`/api/items/${itemId}/claims`, { ...proof, proof: '短' })).status, 400);
      const claim = await call(`/api/items/${itemId}/claims`, proof); acceptedId = claim.data.id;
      assert.equal(claim.status, 201); assert.equal((await call(`/api/items/${itemId}/claims`, proof)).status, 409);
      assert.equal((await call(`/api/items/${itemId}`)).data.myPending, true);
      assert.equal((await call(`/api/items/${itemId}/update`, { ...input, category: '生活用品' }, 'peer-01')).status, 409);
      assert.equal((await call('/api/claims?direction=received')).data.claims.length, 0);
      assert.equal((await call('/api/claims?direction=sent')).data.claims[0].id, acceptedId);
      assert.equal((await call('/api/claims?direction=received', undefined, 'peer-01')).data.pending, 1);
    });
    await t.test('拒绝、取消、重新申请，越权审核返回403', async () => {
      const c = (await call(`/api/items/${itemId}/claims`, proof, 'peer-02')).data;
      assert.equal((await call(`/api/claims/${c.id}/accept`, {})).status, 403);
      assert.equal((await call(`/api/claims/${c.id}/reject`, {}, 'peer-01')).status, 200);
      assert.equal((await call(`/api/claims/${c.id}/cancel`, {}, 'peer-02')).status, 409);
      const d = (await call(`/api/items/${itemId}/claims`, proof, 'peer-02')).data;
      assert.equal((await call(`/api/claims/${d.id}/cancel`, {}, 'peer-01')).status, 403);
      assert.equal((await call(`/api/claims/${d.id}/cancel`, {}, 'peer-02')).status, 200);
      assert.equal((await call(`/api/claims/${d.id}/cancel`, {}, 'peer-02')).status, 200);
    });
    await t.test('接受联动寻回、关闭其他待核对申请、联系人解锁且统计只加一次', async () => {
      const other = (await call(`/api/items/${itemId}/claims`, proof, 'peer-02')).data;
      const before = (await call('/api/statistics?days=30')).data;
      assert.equal((await call(`/api/claims/${acceptedId}/accept`, {}, 'peer-01')).status, 200);
      await call(`/api/claims/${acceptedId}/accept`, {}, 'peer-01');
      const item = (await call(`/api/items/${itemId}`)).data;
      assert.equal(item.status, 'resolved'); assert.equal(item.contactVisible, true); assert.equal(item.contact, input.contact);
      assert.equal(item.myPending, false);
      assert.ok(item.resolvedAt); assert.equal(item.history.at(-1).label, '核对申请通过，确认完成交接');
      assert.equal((await call(`/api/items/${itemId}`, undefined, 'peer-02')).data.contactVisible, false);
      assert.equal((await call('/api/claims?direction=sent', undefined, 'peer-02')).data.claims.find(c => c.id === other.id).status, 'rejected');
      assert.equal((await call('/api/statistics?days=30')).data.resolved, before.resolved + 1);
      assert.equal((await call(`/api/items/${itemId}/claims`, proof)).status, 409);
      assert.equal((await call(`/api/items/${itemId}/update`, input, 'peer-01')).status, 409);
    });
    await t.test('撤回隔离展示和详情，取消待核对申请，恢复后可继续操作', async () => {
      const id = 'seed-2';
      const c = (await call(`/api/items/${id}/claims`, proof, 'peer-01')).data;
      const before = (await call('/api/statistics')).data.total;
      assert.equal((await call(`/api/items/${id}/withdraw`, {})).status, 200);
      assert.equal((await call(`/api/items/${id}`, undefined, 'peer-01')).status, 404);
      assert.equal((await call('/api/items?owner=demo-user')).data.items.find(i => i.id === id).status, 'withdrawn');
      assert.equal((await call('/api/claims?direction=sent', undefined, 'peer-01')).data.claims.find(i => i.id === c.id).status, 'cancelled');
      assert.equal((await call('/api/statistics')).data.total, before - 1);
      assert.equal((await call(`/api/items/${id}/resolve`, {})).status, 409);
      assert.equal((await call(`/api/items/${id}/restore`, {})).status, 200);
      assert.equal((await call('/api/statistics')).data.total, before);
    });
    await t.test('7/14/30日和类别统计遵守总数恒等式，不产生NaN', async () => {
      for (const days of [7, 14, 30]) {
        const s = (await call(`/api/statistics?days=${days}&category=` + encodeURIComponent('电子数码'))).data;
        assert.equal(s.trend.length, days); assert.equal(s.total, s.open + s.resolved);
        assert.equal(s.total, s.lost + s.found); assert.equal(s.total, s.categories.reduce((n, p) => n + p.count, 0));
        assert.equal(s.total, s.trend.reduce((n, p) => n + p.count, 0)); assert.ok(Number.isFinite(s.recoveryRate));
        assert.ok(s.categories.filter(p => p.label !== '电子数码').every(p => p.count === 0));
      }
    });
    await t.test('重启保留完整申请、收藏、编辑、历史与结果', async () => {
      await call(`/api/items/${itemId}/favorite`, { saved: true });
      await new Promise(resolve => server.close(resolve)); await start();
      assert.equal((await call('/api/items?saved=true')).data.items[0].id, itemId);
      assert.equal((await call('/api/claims?direction=sent')).data.claims.find(c => c.id === acceptedId).status, 'accepted');
      const item = (await call(`/api/items/${itemId}`)).data;
      assert.equal(item.status, 'resolved'); assert.equal(item.title, '更新后的蓝色演示耳机盒'); assert.equal(item.history.length, 3);
    });
    await t.test('磁盘失败时申请、收藏、审核与启事状态同时回滚', async () => {
      const blocked = path.join(dir, 'blocked'); fs.writeFileSync(blocked, 'block');
      const failing = createApp({ file: path.join(blocked, 'data.json'), delay: 0 });
      await new Promise(resolve => failing.listen(0, '127.0.0.1', resolve));
      const target = `http://127.0.0.1:${failing.address().port}`;
      try {
        assert.equal((await call('/api/items/seed-1/claims', proof, 'demo-user', target)).status, 500);
        assert.equal((await call('/api/claims?direction=sent', undefined, 'demo-user', target)).data.claims.length, 0);
        assert.equal((await call('/api/items/seed-1/favorite', { saved: true }, 'demo-user', target)).status, 500);
        assert.equal((await call('/api/items?saved=true', undefined, 'demo-user', target)).data.total, 0);
        assert.equal((await call('/api/items/seed-2/withdraw', {}, 'demo-user', target)).status, 500);
        assert.equal((await call('/api/items/seed-2', undefined, 'demo-user', target)).data.status, 'open');
      } finally { await new Promise(resolve => failing.close(resolve)); }
      // A pre-existing pending claim is loaded, then the storage directory is blocked.
      const atomicDir = path.join(dir, 'atomic'); fs.mkdirSync(atomicDir);
      const atomicFile = path.join(atomicDir, 'data.json');
      const loaded = JSON.parse(fs.readFileSync(file));
      loaded.claims.push({ id: 'atomic-pending', itemId: 'seed-1', owner: 'peer-01', sender: 'demo-user', proof: proof.proof, contact: proof.contact, status: 'pending', createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
      fs.writeFileSync(atomicFile, JSON.stringify(loaded));
      const atomic = createApp({ file: atomicFile, delay: 0 });
      fs.unlinkSync(atomicFile); fs.rmdirSync(atomicDir); fs.writeFileSync(atomicDir, 'block');
      await new Promise(resolve => atomic.listen(0, '127.0.0.1', resolve));
      const at = `http://127.0.0.1:${atomic.address().port}`;
      try {
        assert.equal((await call('/api/claims/atomic-pending/accept', {}, 'peer-01', at)).status, 500);
        assert.equal((await call('/api/items/seed-1', undefined, 'peer-01', at)).data.status, 'open');
        assert.equal((await call('/api/claims?direction=received', undefined, 'peer-01', at)).data.claims.find(c => c.id === 'atomic-pending').status, 'pending');
      } finally { await new Promise(resolve => atomic.close(resolve)); }
    });
  } finally {
    await new Promise(resolve => server.close(resolve));
    assert.ok(path.resolve(dir).startsWith(path.resolve(os.tmpdir()) + path.sep));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
