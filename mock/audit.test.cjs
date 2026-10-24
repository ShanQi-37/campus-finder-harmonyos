const { test } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createApp, aggregate } = require('./server.cjs');
const input = { title: '中文校园卡测试', location: '图书馆服务台', description: '卡套背面有白色贴纸，请当面核实，这是虚构测试内容。', contact: '校园服务台转接', kind: 'lost', category: '证件卡片', occurredAt: '2026-01-01', requestId: 'audit-request' };
async function withServer(work, options = { memory: true, delay: 0 }) {
  const server = createApp(options); await new Promise(r => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  async function call(url, body, actor = 'demo-user') {
    const response = await fetch(base + url, { method: body === undefined ? 'GET' : 'POST', headers: { 'Content-Type': 'application/json', 'X-Demo-User': actor }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: response.status, ...(await response.json()) };
  }
  try { return await work({ server, base, call }); } finally { await new Promise(r => server.close(r)); }
}
test('系统复核：中文传输、发布幂等与边界状态', async t => {
  await t.test('UTF8汉字跨HTTP数据块传输仍逐字完整', async () => withServer(async ({ base, call }) => {
    const data = Buffer.from(JSON.stringify(input));
    const split = data.indexOf(Buffer.from('中')) + 1;
    const result = await new Promise((resolve, reject) => {
      const request = http.request(base + '/api/items', { method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': data.length } }, response => {
        const chunks = []; response.on('data', c => chunks.push(c)); response.on('end', () => resolve({ status: response.statusCode, ...JSON.parse(Buffer.concat(chunks).toString('utf8')) }));
      });
      request.on('error', reject); request.write(data.subarray(0, split)); setTimeout(() => request.end(data.subarray(split)), 30);
    });
    assert.equal(result.status, 201); assert.equal(result.data.title, input.title);
    assert.equal((await call('/api/items/' + result.data.id)).data.description, input.description);
  }));
  await t.test('发布响应丢失后保存同一草稿，重试发布应清理该草稿且不重复新增', async () => withServer(async ({ call }) => {
    const first = (await call('/api/items', input)).data;
    await call('/api/draft', input);
    assert.equal((await call('/api/draft')).data.exists, true);
    assert.equal((await call('/api/items', input)).data.id, first.id);
    assert.equal((await call('/api/draft')).data.exists, false);
    assert.equal((await call('/api/items')).data.total, 13);
  }));
  await t.test('同一个发布标识提交不同内容必须返回冲突，不能悄悄返回旧内容', async () => withServer(async ({ call }) => {
    const first = (await call('/api/items', input)).data;
    const changed = await call('/api/items', { ...input, title: '完全不同的物品标题' });
    assert.equal(changed.status, 409); assert.equal((await call('/api/items/' + first.id)).data.title, input.title);
  }));
  await t.test('原启事后续编辑后，原始发布请求重试仍保持幂等且不覆盖编辑', async () => withServer(async ({ call }) => {
    const first = (await call('/api/items', input)).data;
    await call(`/api/items/${first.id}/update`, { ...input, title: '补充线索后的校园卡标题' });
    const retry = await call('/api/items', input);
    assert.equal(retry.status, 201); assert.equal(retry.data.id, first.id); assert.equal(retry.data.title, '补充线索后的校园卡标题');
  }));
  await t.test('上海午夜窗口只统计范围内日期，未来记录不破坏总量恒等式', () => {
    const rows = ['2025-12-27T15:59:59Z', '2025-12-27T16:00:00Z', '2026-01-03T15:59:59Z', '2026-01-03T16:00:00Z'].map((createdAt, i) => ({ ...input, id: 'time-' + i, createdAt, status: i === 1 ? 'resolved' : 'open' }));
    const result = aggregate(rows, [], 7, 'all', new Date('2026-01-02T16:00:00Z'));
    assert.equal(result.total, 2); assert.equal(result.resolved, 1); assert.equal(result.trend[0].label, '12-28'); assert.equal(result.trend.at(-1).label, '01-03');
    assert.equal(result.trend.reduce((sum, p) => sum + p.count, 0), result.total);
    assert.equal(result.updatedAt, '2026-01-02T16:00:00.000Z');
  });
  await t.test('非法筛选、空白发布标识和非法UTF8均返回400且服务继续可用', async () => withServer(async ({ base, call }) => {
    for (const query of ['kind=unknown', 'category=unknown', 'status=unknown', 'owner=unknown', 'sort=unknown', 'saved=unknown', 'page=1.5']) assert.equal((await call('/api/items?' + query)).status, 400, query);
    assert.equal((await call('/api/items', { ...input, requestId: ' ' })).status, 400);
    const invalidUtf8 = await fetch(base + '/api/items', { method: 'POST', body: Buffer.from([0x7b, 0x22, 0xc0, 0xaf, 0x22, 0x3a, 0x31, 0x7d]) });
    assert.equal(invalidUtf8.status, 400); assert.equal((await call('/health')).status, 200);
  }));
  await t.test('并发重试只新增一条，重复认领只产生一份待核对申请', async () => withServer(async ({ call }) => {
    const posts = await Promise.all(Array.from({ length: 8 }, () => call('/api/items', input)));
    assert.ok(posts.every(r => r.status === 201)); assert.equal(new Set(posts.map(r => r.data.id)).size, 1);
    const claims = await Promise.all(Array.from({ length: 8 }, () => call('/api/items/seed-1/claims', { proof: '卡套背面有白色贴纸，仅为虚构验证。', contact: '服务台（演示）' })));
    assert.equal(claims.filter(r => r.status === 201).length, 1); assert.equal(claims.filter(r => r.status === 409).length, 7);
    assert.equal((await call('/api/me')).data.outgoingPending, 1); assert.equal((await call('/api/items')).data.total, 13);
  }));
  await t.test('幂等重试清理草稿时磁盘失败，草稿与已发布记录都保留', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'campus-audit-'));
    try {
      const storage = path.join(dir, 'storage'); fs.mkdirSync(storage); const file = path.join(storage, 'items.json');
      await withServer(async ({ call }) => {
        const first = (await call('/api/items', input)).data; await call('/api/draft', input);
        fs.unlinkSync(file); fs.rmdirSync(storage); fs.writeFileSync(storage, 'blocked');
        assert.equal((await call('/api/items', input)).status, 500);
        assert.equal((await call('/api/draft')).data.exists, true); assert.equal((await call('/api/items/' + first.id)).data.title, input.title);
      }, { file, delay: 0 });
    } finally { assert.ok(path.resolve(dir).startsWith(path.resolve(os.tmpdir()) + path.sep)); fs.rmSync(dir, { recursive: true, force: true }); }
  });
  await t.test('非法请求地址返回400，不触发未捕获异常或终止服务', async () => withServer(async ({ server, call }) => {
    const status = await new Promise((resolve, reject) => {
      const request = http.request({ hostname: '127.0.0.1', port: server.address().port, method: 'GET', path: '//[' }, response => { response.resume(); response.on('end', () => resolve(response.statusCode)); });
      request.on('error', reject); request.end();
    });
    assert.equal(status, 400); assert.equal((await call('/health')).status, 200);
  }));
  await t.test('接口不暴露内部发布指纹，结构故障模式为合法JSON并可恢复', async () => withServer(async ({ call }) => {
    const item = (await call('/api/items', input)).data;
    assert.equal(item.requestId, undefined); assert.equal(item.createFingerprint, undefined);
    await call('/__test/mode', { mode: 'shape' }); assert.equal((await call('/api/items')).data.items[0], null);
    await call('/__test/mode', { mode: 'normal' }); assert.equal((await call('/api/items')).data.total, 13);
  }));
});
