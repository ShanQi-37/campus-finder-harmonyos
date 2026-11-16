const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createApp, aggregate } = require('./server.cjs');

const dateKey = (date = new Date()) => date.toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' });
const baseItem = (id, createdAt, status = 'open', extra = {}) => ({
  id, title: '虚构寻回测试物品', category: '证件卡片', kind: 'lost', location: '校园服务台',
  description: '仅用于验证实际确认寻回日期的虚构物品描述。', owner: 'demo-user', status,
  contact: '服务台转接（虚构）', occurredAt: createdAt.slice(0, 10), createdAt, updatedAt: createdAt,
  history: [{ label: '发布启事', at: createdAt }], ...extra
});
const snapshot = items => ({ version: 2, items, claims: [], favorites: [], drafts: [] });

async function withServer(work, options = { memory: true, delay: 0 }) {
  const server = createApp(options);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (route, body, actor = 'demo-user') => {
    const response = await fetch(base + route, {
      method: body === undefined ? 'GET' : 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Demo-User': actor },
      body: body === undefined ? undefined : JSON.stringify(body)
    });
    return { status: response.status, ...(await response.json()) };
  };
  try { return await work({ call, base }); }
  finally { await new Promise(resolve => server.close(resolve)); }
}

test('实际确认寻回日期：可靠时间、趋势与明细', async t => {
  await t.test('动态事件与独立时间戳按上海日期统计，旧createdAt补值不算确认日期', () => {
    const legacyTime = '2026-01-01T04:00:00.000Z';
    const eventTime = '2026-01-02T16:00:00.000Z';
    const rows = [
      baseItem('legacy', legacyTime, 'resolved', { resolvedAt: legacyTime }),
      baseItem('timestamp', '2025-11-01T04:00:00.000Z', 'resolved', { resolvedAt: '2026-01-02T15:59:59.000Z' }),
      baseItem('event', '2025-11-02T04:00:00.000Z', 'resolved', {
        resolvedAt: '2025-11-02T04:00:00.000Z',
        history: [{ label: '发布启事', at: '2025-11-02T04:00:00.000Z' }, { label: '发布者确认寻回', at: eventTime }]
      }),
      baseItem('claim', '2025-11-03T04:00:00.000Z', 'resolved', {
        resolvedAt: '2026-01-03T01:00:00.000Z',
        history: [{ label: '发布启事', at: '2025-11-03T04:00:00.000Z' }, { label: '核对申请通过，确认完成交接', at: '2026-01-03T01:00:00.000Z' }]
      })
    ];
    const result = aggregate(rows, [], 7, 'all', new Date('2026-01-03T12:00:00.000Z'), 'latest');
    assert.equal(result.windowEnd, '2026-01-01');
    assert.equal(result.recoveryWindowStart, '2025-12-28');
    assert.equal(result.recoveryWindowEnd, '2026-01-03');
    assert.equal(result.total, 1);
    assert.equal(result.resolved, 1);
    assert.equal(result.undatedResolved, 1);
    assert.equal(result.recoveryTrend[5].label, '01-02');
    assert.equal(result.recoveryTrend[5].count, 1);
    assert.equal(result.recoveryTrend[6].label, '01-03');
    assert.equal(result.recoveryTrend[6].count, 2);
    assert.equal(result.recoveryTrend.reduce((sum, point) => sum + point.count, 0), 3);
    assert.equal(result.trend.reduce((sum, point) => sum + point.resolved, 0), result.resolved);
  });

  await t.test('旧快照中的补值被保守清理，可靠记录可查明细并按确认时间倒序分页', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'campus-recovery-legacy-'));
    const file = path.join(dir, 'items.json');
    const fallbackTime = '2026-01-01T04:00:00.000Z';
    const eventTime = '2026-01-03T01:00:00.000Z';
    const rows = [
      baseItem('fallback', fallbackTime, 'resolved', { resolvedAt: fallbackTime }),
      baseItem('missing', '2026-01-02T04:00:00.000Z', 'resolved'),
      baseItem('timestamp', '2025-12-20T04:00:00.000Z', 'resolved', { resolvedAt: '2026-01-02T12:00:00.000Z' }),
      baseItem('event', '2025-12-21T04:00:00.000Z', 'resolved', {
        resolvedAt: '2025-12-21T04:00:00.000Z',
        history: [{ label: '发布启事', at: '2025-12-21T04:00:00.000Z' }, { label: '发布者确认寻回', at: eventTime }]
      })
    ];
    fs.writeFileSync(file, JSON.stringify(snapshot(rows)));
    try {
      await withServer(async ({ call }) => {
        const stats = (await call('/api/statistics?days=7&anchor=latest')).data;
        assert.equal(stats.total, 2);
        assert.equal(stats.resolved, 2);
        assert.equal(stats.undatedResolved, 2);
        assert.equal(stats.windowEnd, '2026-01-02');
        assert.equal(stats.recoveryWindowEnd, '2026-01-03');
        assert.equal(stats.recoveryTrend.reduce((sum, point) => sum + point.count, 0), 2);
        assert.equal((await call('/api/items/fallback')).data.resolvedAt, '');
        assert.equal((await call('/api/items/missing')).data.resolvedAt, '');
        assert.equal((await call('/api/items/event')).data.resolvedAt, eventTime);
        const range = `status=resolved&resolvedFrom=${stats.recoveryWindowStart}&resolvedTo=${stats.recoveryWindowEnd}`;
        const list = (await call('/api/items?' + range)).data;
        assert.equal(list.total, 2);
        assert.deepEqual(list.items.map(item => item.id), ['event', 'timestamp']);
        const first = (await call('/api/items?' + range + '&pageSize=1&page=1')).data;
        const second = (await call('/api/items?' + range + '&pageSize=1&page=2')).data;
        assert.deepEqual([first.items[0].id, second.items[0].id], ['event', 'timestamp']);
      }, { file, delay: 0 });
    } finally {
      assert.ok(path.resolve(dir).startsWith(path.resolve(os.tmpdir()) + path.sep));
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });

  await t.test('早于发布统计窗的启事在窗内确认后，趋势、类别和单日明细数量一致', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'campus-recovery-old-'));
    const file = path.join(dir, 'items.json');
    const createdAt = new Date(Date.now() - 40 * 86400000).toISOString();
    fs.writeFileSync(file, JSON.stringify(snapshot([baseItem('old', createdAt)])));
    try {
      await withServer(async ({ call }) => {
        const before = (await call('/api/statistics?days=7')).data;
        assert.equal(before.total, 0);
        assert.equal(before.recoveryTrend.reduce((sum, point) => sum + point.count, 0), 0);
        assert.equal((await call('/api/items/old/resolve', {})).status, 200);
        const item = (await call('/api/items/old')).data;
        assert.equal(item.resolvedAt, item.history.at(-1).at);
        assert.equal(item.history.at(-1).label, '发布者确认寻回');
        const today = dateKey();
        const stats = (await call('/api/statistics?days=7')).data;
        assert.equal(stats.total, 0);
        assert.equal(stats.recoveryWindowEnd, today);
        assert.equal(stats.recoveryTrend.at(-1).count, 1);
        assert.equal(stats.undatedResolved, 0);
        const detail = (await call(`/api/items?status=resolved&resolvedFrom=${today}&resolvedTo=${today}`)).data;
        assert.equal(detail.total, stats.recoveryTrend.at(-1).count);
        assert.deepEqual(detail.items.map(row => row.id), ['old']);
        const other = (await call('/api/statistics?days=7&category=' + encodeURIComponent('电子数码'))).data;
        assert.equal(other.recoveryTrend.reduce((sum, point) => sum + point.count, 0), 0);
        assert.equal((await call(`/api/items?category=${encodeURIComponent('电子数码')}&status=resolved&resolvedFrom=${today}&resolvedTo=${today}`)).data.total, 0);
        const latest = (await call('/api/statistics?days=7&anchor=latest')).data;
        assert.equal(latest.windowEnd, dateKey(new Date(createdAt)));
        assert.equal(latest.recoveryWindowEnd, today);
        assert.equal(latest.total, 1);
        await call('/api/items/old/resolve', {});
        assert.equal((await call('/api/statistics?days=7')).data.recoveryTrend.at(-1).count, 1);
      }, { file, delay: 0 });
    } finally {
      assert.ok(path.resolve(dir).startsWith(path.resolve(os.tmpdir()) + path.sep));
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });

  await t.test('认领审核通过与直接确认共用可靠时间，旧发布记录同样进入当日明细', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'campus-recovery-claim-'));
    const file = path.join(dir, 'items.json');
    const createdAt = new Date(Date.now() - 50 * 86400000).toISOString();
    fs.writeFileSync(file, JSON.stringify(snapshot([baseItem('claim-old', createdAt, 'open', { owner: 'peer-01' })])));
    try {
      await withServer(async ({ call }) => {
        const claim = await call('/api/items/claim-old/claims', {
          proof: '能够描述物品上的虚构标记并当面核对。', contact: '校园服务台（虚构）'
        });
        assert.equal(claim.status, 201);
        assert.equal((await call(`/api/claims/${claim.data.id}/accept`, {}, 'peer-01')).status, 200);
        const item = (await call('/api/items/claim-old')).data;
        assert.equal(item.resolvedAt, item.history.at(-1).at);
        assert.equal(item.history.at(-1).label, '核对申请通过，确认完成交接');
        const stats = (await call('/api/statistics?days=7')).data;
        assert.equal(stats.total, 0);
        assert.equal(stats.recoveryTrend.at(-1).count, 1);
        const today = dateKey();
        assert.equal((await call(`/api/items?status=resolved&resolvedFrom=${today}&resolvedTo=${today}`)).data.total, 1);
      }, { file, delay: 0 });
    } finally {
      assert.ok(path.resolve(dir).startsWith(path.resolve(os.tmpdir()) + path.sep));
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });

  await t.test('确认日期范围严格校验，初始旧记录仍计入总览但不进入伪造日期明细', async () => withServer(async ({ call }) => {
    const stats = (await call('/api/statistics')).data;
    assert.equal(stats.resolved, 4);
    assert.equal(stats.undatedResolved, 4);
    assert.equal(stats.recoveryTrend.reduce((sum, point) => sum + point.count, 0), 0);
    const today = dateKey();
    const valid = `/api/items?status=resolved&resolvedFrom=2000-01-01&resolvedTo=${today}`;
    assert.equal((await call(valid)).data.total, 0);
    const invalid = [
      'resolvedFrom=2024-01-01', 'resolvedTo=2024-01-01',
      'resolvedFrom=&resolvedTo=2024-01-01', 'resolvedFrom=2024-02-30&resolvedTo=2024-03-02',
      'resolvedFrom=2024-03-02&resolvedTo=2024-03-01', 'resolvedFrom=2024-01-01&resolvedTo=2999-01-01'
    ];
    for (const query of invalid) assert.equal((await call('/api/items?status=resolved&' + query)).status, 400, query);
    assert.equal((await call('/api/items?resolvedFrom=2024-01-01&resolvedTo=2024-01-01')).status, 400);
    assert.equal((await call('/api/items?status=open&resolvedFrom=2024-01-01&resolvedTo=2024-01-01')).status, 400);
    assert.equal((await call('/api/statistics')).data.resolved, 4);
  }));
});
