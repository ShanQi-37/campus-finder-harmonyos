const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createApp } = require('./server.cjs');
const draft = { title: '草稿管理演示', location: '校园服务台', description: '用于验证草稿舍弃和版本冲突的虚构内容。', contact: '服务台转接', kind: 'lost', category: '证件卡片', occurredAt: '', requestId: 'management-draft' };
async function fixture(work, options = { memory: true, delay: 0 }) {
  const server = createApp(options); await new Promise(r => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (url, body, actor = 'demo-user') => {
    const response = await fetch(base + url, { method: body === undefined ? 'GET' : 'POST', headers: { 'Content-Type': 'application/json', 'X-Demo-User': actor }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: response.status, ...(await response.json()) };
  };
  try { return await work(call); } finally { await new Promise(r => server.close(r)); }
}
const token = state => ({ requestId: state.input.requestId, updatedAt: state.updatedAt });
function temporary() { return fs.mkdtempSync(path.join(os.tmpdir(), 'campus-management-')); }
function cleanup(dir) { assert.ok(path.resolve(dir).startsWith(path.resolve(os.tmpdir()) + path.sep)); fs.rmSync(dir, { recursive: true, force: true }); }

test('管理升级：安全舍弃草稿与按状态处理任务', async t => {
  await t.test('确认版本后舍弃草稿、摘要清零，重复请求幂等且不影响启事', () => fixture(async call => {
    const saved = (await call('/api/draft', draft)).data; const before = (await call('/api/items')).data.total;
    assert.equal((await call('/api/draft/discard', token(saved))).status, 200);
    assert.equal((await call('/api/draft')).data.exists, false); assert.equal((await call('/api/me')).data.draftUpdatedAt, '');
    assert.equal((await call('/api/draft/discard', token(saved))).status, 200); assert.equal((await call('/api/items')).data.total, before);
  }));
  await t.test('同一草稿新保存和另一份新草稿均拒绝旧版本删除', () => fixture(async call => {
    const old = (await call('/api/draft', draft)).data;
    const newer = (await call('/api/draft', { ...draft, title: '新保存的草稿内容' })).data;
    assert.ok(Date.parse(newer.updatedAt) > Date.parse(old.updatedAt));
    assert.equal((await call('/api/draft/discard', token(old))).status, 409); assert.equal((await call('/api/draft')).data.input.title, '新保存的草稿内容');
    const latest = (await call('/api/draft', { ...draft, requestId: 'another-draft' })).data;
    assert.equal((await call('/api/draft/discard', token(newer))).status, 409);
    assert.equal((await call('/api/draft/discard', token(latest))).status, 200);
  }));
  await t.test('按身份隔离，版本与舍弃结果跨服务重启保持', async () => {
    const dir = temporary(), file = path.join(dir, 'data.json'); let own;
    try {
      await fixture(async call => { own = (await call('/api/draft', draft)).data; await call('/api/draft', { ...draft, requestId: 'peer-draft' }, 'peer-02'); }, { file, delay: 0 });
      await fixture(async call => {
        assert.equal((await call('/api/draft')).data.updatedAt, own.updatedAt);
        await call('/api/draft/discard', token(own)); assert.equal((await call('/api/draft', undefined, 'peer-02')).data.exists, true);
      }, { file, delay: 0 });
      await fixture(async call => { assert.equal((await call('/api/draft')).data.exists, false); assert.equal((await call('/api/draft', undefined, 'peer-02')).data.input.requestId, 'peer-draft'); }, { file, delay: 0 });
    } finally { cleanup(dir); }
  });
  await t.test('缺失或非法版本参数返回400，已保存草稿保留', () => fixture(async call => {
    const saved = (await call('/api/draft', draft)).data;
    for (const bad of [{}, { requestId: ' ', updatedAt: saved.updatedAt }, { requestId: draft.requestId, updatedAt: 'invalid' }, { requestId: 1, updatedAt: saved.updatedAt }]) assert.equal((await call('/api/draft/discard', bad)).status, 400);
    assert.equal((await call('/api/draft')).data.input.title, draft.title);
  }));
  await t.test('舍弃时磁盘失败回滚，草稿、摘要与其他对象均保留', async () => {
    const dir = temporary(), storage = path.join(dir, 'storage'), file = path.join(storage, 'data.json'); fs.mkdirSync(storage);
    try {
      await fixture(async call => {
        const saved = (await call('/api/draft', draft)).data; const before = (await call('/api/me')).data;
        fs.unlinkSync(file); fs.rmdirSync(storage); fs.writeFileSync(storage, 'blocked');
        assert.equal((await call('/api/draft/discard', token(saved))).status, 500);
        assert.equal((await call('/api/draft')).data.input.requestId, draft.requestId); assert.deepEqual((await call('/api/me')).data, before);
      }, { file, delay: 0 });
    } finally { cleanup(dir); }
  });
  await t.test('申请筛选覆盖待核对、拒绝、取消和通过，方向及身份仍隔离', () => fixture(async call => {
    const proof = { proof: '白色贴纸为虚构说明，请当面核实。', contact: '服务台演示转接' };
    let claim = (await call('/api/items/seed-1/claims', proof)).data;
    assert.equal((await call('/api/claims?direction=sent&status=pending')).data.pending, 1);
    await call('/api/claims/' + claim.id + '/reject', {}, 'peer-01');
    claim = (await call('/api/items/seed-1/claims', proof)).data; await call('/api/claims/' + claim.id + '/cancel', {});
    claim = (await call('/api/items/seed-1/claims', proof)).data; await call('/api/claims/' + claim.id + '/accept', {}, 'peer-01');
    for (const status of ['accepted', 'rejected', 'cancelled']) {
      const sent = (await call('/api/claims?direction=sent&status=' + status)).data;
      const received = (await call('/api/claims?direction=received&status=' + status, undefined, 'peer-01')).data;
      assert.equal(sent.claims.length, 1); assert.equal(sent.pending, 0); assert.equal(sent.claims[0].status, status); assert.deepEqual(received, sent);
      assert.equal((await call('/api/claims?direction=sent&status=' + status, undefined, 'peer-02')).data.claims.length, 0);
    }
    assert.equal((await call('/api/claims?direction=sent&status=pending')).data.claims.length, 0);
    assert.equal((await call('/api/claims?direction=sent&status=all')).data.claims.length, 3);
    assert.equal((await call('/api/claims?status=unknown')).status, 400);
  }));
  await t.test('本人可按已撤回筛选恢复启事，公共及他人列表不泄漏撤回记录', () => fixture(async call => {
    const own = (await call('/api/items?owner=demo-user&status=open')).data.items[0];
    await call('/api/items/' + own.id + '/withdraw', {});
    assert.ok((await call('/api/items?owner=demo-user&status=withdrawn')).data.items.some(i => i.id === own.id));
    assert.equal((await call('/api/items?owner=demo-user&status=withdrawn', undefined, 'peer-02')).data.total, 0);
    assert.equal((await call('/api/items?status=withdrawn')).data.total, 0);
    await call('/api/items/' + own.id + '/restore', {});
    assert.equal((await call('/api/items?owner=demo-user&status=withdrawn')).data.total, 0);
    assert.equal((await call('/api/items/' + own.id)).data.status, 'open');
  }));
});
