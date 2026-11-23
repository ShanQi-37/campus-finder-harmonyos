const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('./server.cjs');
const { loadEts } = require('./ets-test-loader.cjs');

test('AI 招领建议仅使用识别出的物品名和外观', () => {
  const { suggestFoundNotice } = loadEts('model/RecognitionDraft.ets');
  const suggestion = suggestFoundNotice({ category: '生活用品', object: '保温杯', features: [' 绿色 ', '白色贴纸'] });
  assert.equal(suggestion.title, '拾到保温杯');
  assert.equal(suggestion.description, '拾到一件保温杯，可见外观：绿色、白色贴纸。');
  assert.equal(suggestFoundNotice({ category: '生活用品', object: '水杯', features: [] }).description, '');
});

test('媒体选择器：相机空结果按取消处理并清理临时文件', async () => {
  const unlinked = [];
  const { MediaPicker } = loadEts('service/MediaPicker.ets', {
    '@kit.AbilityKit': { common: {} },
    '@kit.CoreFileKit': {
      fileIo: {
        OpenMode: { READ_ONLY: 0, CREATE: 1, WRITE_ONLY: 2 },
        open: async () => ({ fd: 1 }), close: async () => {}, unlink: async path => { unlinked.push(path); }
      },
      fileUri: { getUriFromPath: path => 'file://' + path }
    },
    '@kit.ImageKit': { image: {} },
    '@kit.CameraKit': {
      camera: { CameraPosition: { CAMERA_POSITION_BACK: 1 } },
      cameraPicker: { PickerMediaType: { PHOTO: 0, VIDEO: 1 }, pick: async () => undefined }
    },
    '@kit.MediaLibraryKit': { photoAccessHelper: {} }
  });
  assert.equal(await MediaPicker.choose({ cacheDir: '/cache' }, false, false), null);
  assert.equal(unlinked.length, 1);
  assert.match(unlinked[0], /^\/cache\/campus-capture-\d+\.jpg$/);
});
const { ResponseGuard: guard } = loadEts('service/ResponseGuard.ets');

test('原生响应校验器：真实服务契约与损坏结构', async t => {
  const server = createApp({ memory: true, delay: 0 }); await new Promise(r => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const get = async url => (await (await fetch(base + url)).json()).data;
  const post = async (url, body) => (await (await fetch(base + url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })).json()).data;
  try {
    const list = await get('/api/items?pageSize=2'), stats = await get('/api/statistics?days=14'), summary = await get('/api/me');
    await t.test('实际列表、详情、统计、摘要与无草稿返回都能通过原生校验', async () => {
      assert.equal(guard.list(list), true); assert.equal(guard.item(list.items[0]), true); assert.equal(guard.statistics(stats), true); assert.equal(guard.summary(summary), true);
      assert.equal(guard.draft(await get('/api/draft')), true); assert.equal(guard.claims(await get('/api/claims')), true); assert.equal(guard.matches(await get('/api/items/seed-2/matches')), true);
    });
    await t.test('保存未填完的草稿与真实申请结果遵守同一原生契约', async () => {
      const draft = await post('/api/draft', { title: '', description: '', location: '', contact: '', occurredAt: '', kind: 'lost', category: '证件卡片', requestId: 'contract-draft' });
      assert.equal(guard.draft(draft), true);
      const claim = await post('/api/items/seed-1/claims', { proof: '白色贴纸为虚构核对说明，请当面核实。', contact: '服务台（演示）' });
      assert.equal(guard.claim(claim), true); assert.equal(guard.claims(await get('/api/claims?direction=sent')), true);
    });
    await t.test('嵌套null、缺字段和非法时间被拒绝，不会进入UI崩溃', () => {
      for (const value of [null, {}, { ...list.items[0], history: [null] }, { ...list.items[0], occurredAt: '2026-02-30' }, { ...list.items[0], location: null }]) assert.equal(guard.item(value), false);
      assert.equal(guard.list({ ...list, items: [null] }), false);
      assert.equal(guard.matches({ matches: [{ item: list.items[0], reasons: [null] }] }), false);
      assert.equal(guard.draft({ exists: true, input: { requestId: 'only-id' }, updatedAt: new Date().toISOString() }), false);
      assert.equal(guard.summary({ ...summary, draftUpdatedAt: null }), false);
    });
    await t.test('页码、申请待办和统计恒等式不一致被识别为格式错误', () => {
      for (const broken of [{ ...list, page: 0 }, { ...list, total: -1 }, { ...list, hasMore: false }, { ...list, pageSize: '2' }]) assert.equal(guard.list(broken), false);
      assert.equal(guard.claims({ claims: [], pending: 1 }), false);
      for (const broken of [{ ...stats, total: stats.total + 1 }, { ...stats, recoveryRate: 101 }, { ...stats, trend: [] },
        { ...stats, recoveryTrend: [] }, { ...stats, recoveryWindowStart: '2024-02-30' }, { ...stats, undatedResolved: -1 },
        { ...stats, categories: [null] }, { ...stats, open: 1.5 }]) assert.equal(guard.statistics(broken), false);
    });
    await t.test('原生统计API发送历史模式并拦截日期、寻回数或筛选条件不一致的响应', async () => {
      const category = '证件卡片';
      const query = '/api/statistics?days=14&category=' + encodeURIComponent(category) + '&anchor=latest';
      const actual = await get(query);
      let data = actual;
      const http = { RequestMethod: { GET: 'GET' }, HttpDataType: { STRING: 'STRING' }, createHttp: () => ({ request: async url => {
        assert.equal(new URL(url).pathname + new URL(url).search, query);
        return { responseCode: 200, result: JSON.stringify({ code: 0, message: 'ok', data }) };
      }, destroy: () => {} }) };
      const { Api } = loadEts('service/Api.ets', { '@kit.NetworkKit': { http } });
      assert.equal((await Api.statistics(14, category, 'latest')).windowEnd, actual.windowEnd);
      for (const change of [{ anchor: 'today' }, { windowStart: '2024-02-30' }, { recoveryWindowStart: '2024-02-30' },
        { trend: [{ ...actual.trend[0], resolved: 99 }, ...actual.trend.slice(1)] }, { trend: [...actual.trend].reverse() },
        { recoveryTrend: [...actual.recoveryTrend].reverse() }]) {
        data = { ...actual, ...change };
        await assert.rejects(() => Api.statistics(14, category, 'latest'), /返回统计格式异常/);
      }
    });
    await t.test('合法JSON但字段损坏时，所有读写API都报可读错误并销毁HTTP对象', async () => {
      let destroys = 0, payload = { code: 0, message: 'ok', data: { items: [null] } };
      const http = { RequestMethod: { GET: 'GET', POST: 'POST' }, HttpDataType: { STRING: 'STRING' }, createHttp: () => ({ request: async () => ({ responseCode: 200, result: JSON.stringify(payload) }), destroy: () => { destroys++; } }) };
      const { Api } = loadEts('service/Api.ets', { '@kit.NetworkKit': { http } });
      const input = { title: '', location: '', description: '', contact: '', occurredAt: '', kind: 'lost', category: '证件卡片', requestId: 'shape' };
      const calls = [() => Api.list('all', 'all', ''), () => Api.detail('id'), () => Api.publish(input), () => Api.action('id', 'resolve'), () => Api.favorite('id', true), () => Api.claim('id', { proof: '', contact: '' }), () => Api.claims('sent'), () => Api.review('id', 'cancel'), () => Api.matches('id'), () => Api.draft(), () => Api.saveDraft(input), () => Api.discardDraft('draft', new Date().toISOString()), () => Api.me(), () => Api.statistics()];
      for (const call of calls) await assert.rejects(call, /格式异常/);
      assert.equal(destroys, calls.length);
      payload = null; await assert.rejects(() => Api.list('all', 'all', ''), /数据异常/); assert.equal(destroys, calls.length + 1);
    });
    await t.test('真实服务的结构故障模式被原生校验拒绝，恢复后重新通过', async () => {
      await post('/__test/mode', { mode: 'shape' }); assert.equal(guard.list(await get('/api/items')), false); assert.equal(guard.statistics(await get('/api/statistics')), false);
      await post('/__test/mode', { mode: 'normal' }); assert.equal(guard.list(await get('/api/items?pageSize=2')), true);
    });
  } finally { await new Promise(r => server.close(r)); }
});

const flush = () => new Promise(r => setImmediate(r));
function modelFixture() {
  const pending = [];
  const { FeedModel } = loadEts('model/FeedModel.ets', { '../service/Api': { Api: { list: (...args) => new Promise((resolve, reject) => pending.push({ args, resolve, reject })) } } });
  return { model: new FeedModel(), pending };
}
const result = (id, page = 1) => ({ items: [{ id }], total: 1, page, pageSize: 2, hasMore: false });
test('原生FeedModel：受控乱序、取消和分页恢复', async t => {
  await t.test('统计明细保持日期、类别和状态，翻页沿用同一统计范围', async () => {
    const { model, pending } = modelFixture();
    const window = { start: '2025-12-28', end: '2026-01-03' };
    model.category = '证件卡片';
    model.status = 'resolved';
    model.publicationWindow = window;
    const first = model.load();
    assert.deepEqual(pending[0].args.slice(0,5), ['all','证件卡片','','','resolved']);
    assert.equal(pending[0].args[8], window);
    pending[0].resolve({ ...result('first'), total: 3, hasMore: true });
    await first;
    model.turn(1);
    assert.equal(pending[1].args[7], 2);
    assert.equal(pending[1].args[8], window);
    pending[1].resolve({ ...result('last', 2), total: 3 });
    await flush();
    assert.equal(model.page, 2);
  });
  await t.test('确认寻回明细使用独立窗口，翻页继续携带确认日期而非发布日期', async () => {
    const { model, pending } = modelFixture();
    const window = { start: '2026-01-03', end: '2026-01-03' };
    model.category = '证件卡片';
    model.status = 'resolved';
    model.resolutionWindow = window;
    const first = model.load();
    assert.deepEqual(pending[0].args.slice(0, 5), ['all', '证件卡片', '', '', 'resolved']);
    assert.equal(pending[0].args[8], undefined);
    assert.equal(pending[0].args[9], window);
    pending[0].resolve({ ...result('first'), total: 3, hasMore: true });
    await first;
    model.turn(1);
    assert.equal(pending[1].args[7], 2);
    assert.equal(pending[1].args[8], undefined);
    assert.equal(pending[1].args[9], window);
    pending[1].resolve({ ...result('last', 2), total: 3 });
    await flush();
    assert.equal(model.page, 2);
  });
  await t.test('较旧成功响应不会覆盖较新的筛选结果', async () => {
    const { model, pending } = modelFixture(); const older = model.load(); model.keyword = 'new'; const newer = model.load();
    pending[1].resolve(result('new')); await newer; pending[0].resolve(result('old')); await older;
    assert.equal(model.items[0].id, 'new'); assert.equal(model.phase, 'ready'); assert.equal(pending[1].args[2], 'new');
  });
  await t.test('较旧失败响应不会将已加载的新结果改成错误', async () => {
    const { model, pending } = modelFixture(); const older = model.load(); const newer = model.load();
    pending[1].resolve(result('new')); await newer; pending[0].reject(new Error('old failure')); await older;
    assert.equal(model.phase, 'ready'); assert.equal(model.error, '');
  });
  await t.test('取消后的响应不写入页面，后续重新加载仍可成功', async () => {
    const { model, pending } = modelFixture(); const cancelled = model.load(); model.cancel(); pending[0].resolve(result('cancelled')); await cancelled;
    assert.equal(model.items.length, 0); const next = model.load(); pending[1].resolve(result('current')); await next; assert.equal(model.items[0].id, 'current');
  });
  await t.test('输入中的草稿不影响翻页与重试，提交新词才回到第一页', async () => {
    const { model, pending } = modelFixture();
    model.keywordInput = '  校园卡  ';
    const first = model.search();
    assert.equal(pending[0].args[2], '校园卡');
    pending[0].resolve({ ...result('one'), total: 3, hasMore: true });
    await first;
    model.keywordInput = '图书馆';
    model.turn(1);
    assert.equal(pending[1].args[2], '校园卡');
    assert.equal(pending[1].args[7], 2);
    pending[1].reject(new Error('offline'));
    await flush();
    const retry = model.load(false);
    assert.equal(pending[2].args[2], '校园卡');
    assert.equal(pending[2].args[7], 2);
    pending[2].resolve({ ...result('two', 2), total: 3 });
    await retry;
    const next = model.search();
    assert.equal(pending[3].args[2], '图书馆');
    assert.equal(pending[3].args[7], 1);
    pending[3].resolve(result('new'));
    await next;
    assert.equal(model.items[0].id, 'new');
    model.reset();
    assert.equal(model.keywordInput, '');
    assert.equal(pending[4].args[2], '');
    pending[4].resolve(result('reset'));
    await flush();
  });
  await t.test('返回刷新保留当前请求页并采用服务端收敛页码，重置筛选正常进入空状态', async () => {
    const { model, pending } = modelFixture(); model.page = 3; const refresh = model.load(false); assert.equal(pending[0].args[7], 3);
    pending[0].resolve(result('last', 1)); await refresh; assert.equal(model.page, 1);
    model.keyword = 'old'; model.kind = 'lost'; model.status = 'resolved'; model.sort = 'oldest'; model.reset();
    pending[1].resolve({ items: [], total: 0, page: 1, pageSize: 2, hasMore: false }); await flush();
    assert.equal(model.keyword, ''); assert.equal(model.kind, 'all'); assert.equal(model.status, 'all'); assert.equal(model.sort, 'latest'); assert.equal(model.phase, 'empty');
  });
});


test('原生管理API：状态参数与舍弃响应契约', async t => {
  let last, destroys = 0, payload = { claims: [], pending: 0 };
  const http = { RequestMethod: { GET: 'GET', POST: 'POST' }, HttpDataType: { STRING: 'STRING' }, createHttp: () => ({ request: async (url, options) => { last = { url, options }; return { responseCode: 200, result: JSON.stringify({ code: 0, message: 'ok', data: payload }) }; }, destroy: () => { destroys++; } }) };
  const { Api } = loadEts('service/Api.ets', { '@kit.NetworkKit': { http } });
  await t.test('实际Api传递申请状态与方向，默认调用仍为全部', async () => {
    await Api.claims('sent', 'rejected'); assert.match(last.url, /direction=sent&status=rejected/); assert.equal(last.options.method, 'GET');
    await Api.claims('received'); assert.match(last.url, /status=all/); assert.equal(destroys, 2);
  });
  await t.test('实际Api携带草稿版本，拒绝仍存在草稿的成功假响应', async () => {
    payload = { exists: false, input: null, updatedAt: '' };
    await Api.discardDraft('draft-token', '2026-01-01T00:00:00.000Z');
    assert.match(last.url, /\/api\/draft\/discard$/); assert.equal(last.options.method, 'POST');
    assert.deepEqual(JSON.parse(last.options.extraData), { requestId: 'draft-token', updatedAt: '2026-01-01T00:00:00.000Z' });
    payload = { exists: true, input: { title: '', location: '', description: '', contact: '', occurredAt: '', kind: 'lost', category: '证件卡片', requestId: 'new' }, updatedAt: '2026-01-01T00:00:00.000Z' };
    await assert.rejects(() => Api.discardDraft('draft-token', '2026-01-01T00:00:00.000Z'), /格式异常/); assert.equal(destroys, 4);
  });
  await t.test('实际Api将确认寻回窗口映射到resolvedFrom与resolvedTo', async () => {
    payload = { items: [], total: 0, page: 1, pageSize: 6, hasMore: false };
    const before = destroys;
    const window = { start: '2026-01-03', end: '2026-01-03' };
    await Api.list('all', '证件卡片', '', '', 'resolved', 'latest', false, 1, undefined, window);
    const target = new URL(last.url);
    assert.equal(target.searchParams.get('status'), 'resolved');
    assert.equal(target.searchParams.get('category'), '证件卡片');
    assert.equal(target.searchParams.get('resolvedFrom'), window.start);
    assert.equal(target.searchParams.get('resolvedTo'), window.end);
    assert.equal(target.searchParams.has('publishedFrom'), false);
    assert.equal(destroys, before + 1);
  });
});

test('原生UI配置：实时字数、Next/Done焦点与系统字体缩放', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/pages/PublishPage.ets'), 'utf8');
  const app = fs.readFileSync(path.join(__dirname, '../AppScope/app.json5'), 'utf8');
  const font = JSON.parse(fs.readFileSync(path.join(__dirname, '../AppScope/resources/base/profile/configuration.json'), 'utf8'));
  assert.equal(app.includes('"configuration": "$profile:configuration"'), true);
  assert.deepEqual(font.configuration, { fontSizeScale: 'followSystem', fontSizeMaxScale: '2' });
  const ability = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/entryability/EntryAbility.ets'), 'utf8');
  const feed = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/components/FeedContent.ets'), 'utf8');
  const claims = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/pages/ClaimCenterPage.ets'), 'utf8');
  assert.equal(ability.includes('setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)'), true, '键盘弹出应压缩内容区而非把页头推入安全区');
  assert.equal(feed.includes("Button('搜索').constraintSize({ minWidth: 64, minHeight: 44 })"), true, '搜索按钮需随字号增长');
  assert.equal(claims.includes("accessibilityText('申请状态筛选')"), true);
  assert.equal(claims.includes('.backgroundColor(Colors.surface).width(118).accessibilityText(\'申请状态筛选\')'), false, '申请筛选不能锁定在小字号宽度');
  for (const [field, max] of [['title', 36], ['location', 30], ['description', 300]]) {
    assert.equal(source.includes(`Text(this.${field}.length + ' / ${max}')`), true, `${field}计数必须直接订阅@Local状态`);
  }
  assert.equal(/this\.fieldLabel\([^\n]*this\.(title|location|description)\.length/.test(source), false, '动态计数不能经按值Builder冻结');
  assert.equal(source.includes(".id('publishTitle').enterKeyType(EnterKeyType.Next).onSubmit(() => { focusControl.requestFocus('publishLocation'); })"), true);
  assert.equal(source.includes(".id('publishLocation').enterKeyType(EnterKeyType.Done).onSubmit(() => this.next())"), true);
  assert.equal(source.includes(".id('publishContact').enterKeyType(EnterKeyType.Next).onSubmit(() => { focusControl.requestFocus('publishDate'); })"), true);
  assert.equal(source.includes(".id('publishDate').enterKeyType(EnterKeyType.Done).onSubmit(() => this.next())"), true);
});
