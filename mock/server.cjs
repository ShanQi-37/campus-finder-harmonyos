const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID, createHash } = require('node:crypto');
const CATEGORIES = ['证件卡片', '电子数码', '生活用品', '学习文具'];
const dateKey = (date = new Date()) => date.toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' });
function seed() {
  const rows = [
    ['图书馆捡到一张校园卡', '证件卡片', 'found', '图书馆二楼', '卡片已交至图书馆服务台，请携带能够证明身份的信息前往核对。', 'peer-01', 'open'],
    ['寻找浅绿色保温杯', '生活用品', 'lost', '第十教学楼', '杯盖有一枚白色贴纸，周三下午遗落在自习室，请通过服务台留言。', 'demo-user', 'open'],
    ['拾到无线耳机充电盒', '电子数码', 'found', '芷兰食堂', '仅拾到白色充电盒，未发现耳机，请提供型号及特征核实。', 'peer-02', 'open'],
    ['蓝色高数笔记本已寻回', '学习文具', 'lost', '教学楼A座', '感谢同学将笔记本送到值班室，已经核对并取回。', 'demo-user', 'resolved'],
    ['捡到黑色折叠伞', '生活用品', 'found', '体育馆', '黑色长柄折叠伞，已放到体育馆前台，核实伞面特征后领取。', 'peer-03', 'open'],
    ['寻找校园公交卡', '证件卡片', 'lost', '东门公交站', '卡套为透明磨砂材质，背面夹有课程表。', 'peer-04', 'resolved'],
    ['拾到一支银色触控笔', '电子数码', 'found', '计算机实验楼', '已交至一楼值班室，领取时请说明设备型号。', 'peer-01', 'open'],
    ['实验记录本招领', '学习文具', 'found', '生科楼', '封面写有实验分组编号，已妥善保管。', 'peer-05', 'resolved'],
    ['寻找红色U盘', '电子数码', 'lost', '图书馆一楼', '红色金属外壳，内有课程练习，请勿公开文件内容。', 'demo-user', 'open'],
    ['钥匙串已归还', '生活用品', 'found', '宿舍区', '带绿色挂绳的钥匙串，已通过描述核实并交还。', 'peer-06', 'resolved'],
    ['学生证招领', '证件卡片', 'found', '文渊楼', '请本人到值班室核对姓名后领取。', 'peer-07', 'open'],
    ['寻找透明文件袋', '学习文具', 'lost', '教学楼B座', '内有打印的复习资料，封面没有个人证件。', 'peer-08', 'open']
  ];
  return rows.map((r, i) => {
    const created = new Date(Date.now() - Math.floor(i / 2) * 86400000 - i * 60000);
    return { id: `seed-${i + 1}`, title: r[0], category: r[1], kind: r[2], location: r[3], description: r[4], owner: r[5], status: r[6], contact: '校园服务台转接（演示）', occurredAt: dateKey(created), createdAt: created.toISOString() };
  });
}
// Demo identities deliberately model actors, not authentication or production security.
const ACTORS = ['demo-user', 'peer-01', 'peer-02'];
const names = { 'demo-user': '校园体验同学', 'peer-01': '互助体验同学', 'peer-02': '志愿体验同学' };
const now = () => new Date().toISOString();
const event = (label, at = now()) => ({ label, at });
const fingerprint = input => createHash('sha256').update(JSON.stringify(['title', 'location', 'description', 'contact', 'kind', 'category', 'occurredAt'].map(key => input[key]))).digest('hex');
function normalize(item) {
  return { ...item, owner: ACTORS.includes(item.owner) ? item.owner : 'peer-01',
    updatedAt: item.updatedAt || item.createdAt, resolvedAt: item.resolvedAt || (item.status === 'resolved' ? item.createdAt : ''),
    requestId: item.requestId || '', history: item.history || [event('发布启事', item.createdAt)] };
}
function aggregate(items, claims = [], days = 7, category = 'all', reference = new Date()) {
  const today = dateKey(reference), first = dateKey(new Date(reference.getTime() - (days - 1) * 86400000));
  const scoped = items.filter(i => { const day = dateKey(new Date(i.createdAt)); return day >= first && day <= today && (category === 'all' || i.category === category); });
  const active = scoped.filter(i => i.status !== 'withdrawn');
  const total = active.length, resolved = active.filter(i => i.status === 'resolved').length;
  return { total, resolved, open: total - resolved, recoveryRate: total ? Math.round(resolved / total * 100) : 0,
    lost: active.filter(i => i.kind === 'lost').length, found: active.filter(i => i.kind === 'found').length,
    withdrawn: scoped.length - total, pendingClaims: claims.filter(c => c.status === 'pending' && active.some(i => i.id === c.itemId)).length,
    categories: CATEGORIES.map(label => ({ label, count: active.filter(i => i.category === label).length })),
    trend: Array.from({ length: days }, (_, index) => {
      const day = dateKey(new Date(reference.getTime() - (days - 1 - index) * 86400000));
      return { label: day.slice(5), count: active.filter(i => dateKey(new Date(i.createdAt)) === day).length };
    }), days, category, updatedAt: reference.toISOString() };
}
function createApp(options = {}) {
  const file = options.file || path.join(__dirname, 'runtime', 'items.json');
  const rawStore = !options.memory && fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : seed();
  // Legacy arrays are migrated without losing any previously published records.
  let store = Array.isArray(rawStore) ? { version: 2, items: rawStore.map(normalize), claims: [], favorites: [] }
    : { ...rawStore, version: 2, items: rawStore.items.map(normalize) };
  store = { ...store, drafts: store.drafts || [] };
  let fault = 'normal';
  const commit = next => {
    if (!options.memory) {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      const temporary = `${file}.${process.pid}.tmp`;
      try { fs.writeFileSync(temporary, JSON.stringify(next, null, 2), 'utf8'); fs.renameSync(temporary, file); }
      finally { if (fs.existsSync(temporary)) fs.unlinkSync(temporary); }
    }
    store = next;
  };
  const reply = (res, status, data, message = 'ok') => {
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'Access-Control-Allow-Origin': '*' });
    res.end(JSON.stringify({ code: status < 400 ? 0 : status, message, data }));
  };
  const server = http.createServer(async (req, res) => {
    const started = Date.now(); let url;
    try { url = new URL(req.url, 'http://127.0.0.1'); }
    catch { return reply(res, 400, null, '请求地址格式错误'); }
    res.on('finish', () => console.log(JSON.stringify({ time: now(), method: req.method, path: url.pathname, query: url.search, status: res.statusCode, ms: Date.now() - started })));
    try {
      const chunks = []; let bytes = 0;
      for await (const chunk of req) { bytes += chunk.length; if (bytes > 16384) return reply(res, 413, null, '请求过大'); chunks.push(chunk); }
      let body;
      try { const raw = new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks)); body = raw ? JSON.parse(raw) : {}; } catch { return reply(res, 400, null, 'JSON或UTF8格式错误'); }
      if (!body || typeof body !== 'object' || Array.isArray(body)) return reply(res, 400, null, '请求体必须为JSON对象');
      if (url.pathname === '/__test/mode' && req.method === 'POST') {
        if (!['normal', 'error', 'empty', 'slow', 'malformed', 'shape'].includes(body.mode)) return reply(res, 400, null, '模式无效');
        fault = body.mode; return reply(res, 200, { mode: fault });
      }
      if (url.pathname === '/health') return reply(res, 200, { service: 'CampusFinder', version: 2, count: store.items.length });
      if (!url.pathname.startsWith('/api/')) return reply(res, 404, null, '接口不存在');
      const actor = req.headers['x-demo-user'] || 'demo-user';
      if (!ACTORS.includes(actor)) return reply(res, 400, null, '演示身份无效');
      await new Promise(resolve => setTimeout(resolve, fault === 'slow' ? 2500 : (options.delay ?? 250)));
      if (req.method === 'GET' && fault === 'error') return reply(res, 503, null, '服务暂不可用，请稍后重试');
      if (req.method === 'GET' && fault === 'malformed') { res.writeHead(200, { 'Content-Type': 'application/json' }); return res.end('{invalid'); }
      if (req.method === 'GET' && fault === 'shape') return reply(res, 200, { items: [null], claims: [null], matches: [null], exists: true, input: { requestId: '' } });
      const list = fault === 'empty' ? [] : store.items;
      const view = item => {
        const accepted = store.claims.some(c => c.itemId === item.id && c.sender === actor && c.status === 'accepted');
        const { requestId, createFingerprint, ...visible } = item;
        return { ...visible, contact: item.owner === actor || accepted ? item.contact : '核对申请通过后可查看联系指引',
          contactVisible: item.owner === actor || accepted, ownerName: names[item.owner],
          saved: store.favorites.some(f => f.actor === actor && f.itemId === item.id),
          myPending: store.claims.some(c => c.itemId === item.id && c.sender === actor && c.status === 'pending'),
          claimCount: store.claims.filter(c => c.itemId === item.id && c.status === 'pending').length };
      };
      const claimView = claim => {
        const item = store.items.find(i => i.id === claim.itemId);
        return { ...claim, itemTitle: item.title, kind: item.kind, category: item.category, senderName: names[claim.sender], ownerName: names[claim.owner] };
      };
      if (url.pathname === '/api/me' && req.method === 'GET') {
        const own = list.filter(i => i.owner === actor), claims = fault === 'empty' ? [] : store.claims;
        const draft = fault === 'empty' ? undefined : store.drafts.find(d => d.actor === actor);
        return reply(res, 200, { posted: own.length, open: own.filter(i => i.status === 'open').length,
          resolved: own.filter(i => i.status === 'resolved').length,
          saved: list.filter(i => i.status !== 'withdrawn' && store.favorites.some(f => f.actor === actor && f.itemId === i.id)).length,
          incomingPending: claims.filter(c => c.owner === actor && c.status === 'pending').length,
          outgoingPending: claims.filter(c => c.sender === actor && c.status === 'pending').length,
          draftTitle: draft ? draft.input.title || '未命名草稿' : '', draftUpdatedAt: draft ? draft.updatedAt : '' });
      }
      if (url.pathname === '/api/draft') {
        if (req.method === 'GET') {
          const draft = fault === 'empty' ? undefined : store.drafts.find(d => d.actor === actor);
          return reply(res, 200, { exists: !!draft, input: draft ? draft.input : null, updatedAt: draft ? draft.updatedAt : '' });
        }
        if (req.method === 'POST') {
          for (const [key, max] of [['title', 36], ['location', 30], ['description', 300], ['contact', 60], ['occurredAt', 10]]) {
            if (typeof body[key] !== 'string' || body[key].length > max) return reply(res, 400, null, '草稿字段格式或长度无效');
          }
          if (!CATEGORIES.includes(body.category) || !['lost', 'found'].includes(body.kind) || typeof body.requestId !== 'string' || !body.requestId.trim() || body.requestId.length > 80) return reply(res, 400, null, '草稿类型或标识无效');
          const input = { title: body.title.trim(), location: body.location.trim(), description: body.description.trim(), contact: body.contact.trim(), occurredAt: body.occurredAt.trim(), kind: body.kind, category: body.category, requestId: body.requestId };
          const previous = Date.parse(store.drafts.find(d => d.actor === actor)?.updatedAt || '');
          const draft = { actor, input, updatedAt: new Date(Math.max(Date.now(), Number.isFinite(previous) ? previous + 1 : 0)).toISOString() };
          commit({ ...store, drafts: [...store.drafts.filter(d => d.actor !== actor), draft] });
          return reply(res, 200, { exists: true, input, updatedAt: draft.updatedAt });
        }
      }
      if (url.pathname === '/api/draft/discard' && req.method === 'POST') {
        if (typeof body.requestId !== 'string' || !body.requestId.trim() || body.requestId.length > 80 || typeof body.updatedAt !== 'string' || !Number.isFinite(Date.parse(body.updatedAt))) return reply(res, 400, null, '草稿版本参数无效，请重新加载');
        const draft = store.drafts.find(d => d.actor === actor);
        if (draft && (draft.input.requestId !== body.requestId || draft.updatedAt !== body.updatedAt)) return reply(res, 409, null, '草稿已有新版本，请返回后重新打开，避免误删新内容');
        if (draft) commit({ ...store, drafts: store.drafts.filter(d => d.actor !== actor) });
        return reply(res, 200, { exists: false, input: null, updatedAt: '' });
      }
      if (url.pathname === '/api/statistics' && req.method === 'GET') {
        const days = Number(url.searchParams.get('days') || 7), category = url.searchParams.get('category') || 'all';
        if (![7, 14, 30].includes(days) || (category !== 'all' && !CATEGORIES.includes(category))) return reply(res, 400, null, '统计条件无效');
        return reply(res, 200, aggregate(list, fault === 'empty' ? [] : store.claims, days, category));
      }
      if (url.pathname === '/api/claims' && req.method === 'GET') {
        const direction = url.searchParams.get('direction') || 'received';
        if (!['received', 'sent'].includes(direction)) return reply(res, 400, null, '申请方向无效');
        const status = url.searchParams.get('status') || 'all';
        if (!['all', 'pending', 'accepted', 'rejected', 'cancelled'].includes(status)) return reply(res, 400, null, '申请状态无效');
        const rows = (fault === 'empty' ? [] : store.claims).filter(c => (direction === 'sent' ? c.sender : c.owner) === actor && (status === 'all' || c.status === status));
        return reply(res, 200, { claims: [...rows].sort((a, b) => b.createdAt.localeCompare(a.createdAt)).map(claimView), pending: rows.filter(c => c.status === 'pending').length });
      }
      if (url.pathname === '/api/items' && req.method === 'GET') {
        for (const [key, choices] of [['kind', ['all', 'lost', 'found']], ['category', ['all', ...CATEGORIES]], ['status', ['all', 'open', 'resolved', 'withdrawn']], ['owner', ['all', ...ACTORS]], ['sort', ['latest', 'oldest']], ['saved', ['true', 'false']]]) {
          const value = url.searchParams.get(key);
          if (value && !choices.includes(value)) return reply(res, 400, null, '筛选条件无效');
        }
        let result = list;
        for (const key of ['category', 'kind', 'owner', 'status']) {
          const value = url.searchParams.get(key);
          if (value && value !== 'all') result = result.filter(i => i[key] === value);
        }
        // Withdrawn notices stay in the owner's management area only.
        if (url.searchParams.get('owner') !== actor) result = result.filter(i => i.status !== 'withdrawn');
        if (url.searchParams.get('saved') === 'true') result = result.filter(i => store.favorites.some(f => f.actor === actor && f.itemId === i.id));
        const keyword = (url.searchParams.get('keyword') || '').trim().toLowerCase();
        if (keyword.length > 80) return reply(res, 400, null, '关键词最多80字');
        if (keyword) result = result.filter(i => `${i.title} ${i.description} ${i.location}`.toLowerCase().includes(keyword));
        const page = Number(url.searchParams.get('page') || 1), pageSize = Number(url.searchParams.get('pageSize') || 100);
        if (!Number.isSafeInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) return reply(res, 400, null, '分页参数无效');
        const sorted = [...result].sort((a, b) => (url.searchParams.get('sort') === 'oldest' ? 1 : -1) * a.createdAt.localeCompare(b.createdAt));
        const current = Math.min(page, Math.max(1, Math.ceil(result.length / pageSize)));
        return reply(res, 200, { items: sorted.slice((current - 1) * pageSize, current * pageSize).map(view), total: result.length, page: current, pageSize, hasMore: current * pageSize < result.length });
      }
      const validateItem = () => {
        for (const [key, min, max, label] of [['title', 2, 36, '标题'], ['location', 2, 30, '地点'], ['description', 8, 300, '描述'], ['contact', 2, 60, '联系指引']]) {
          if (typeof body[key] !== 'string' || body[key].trim().length < min || body[key].trim().length > max) return `${label}长度应为${min}-${max}字`;
        }
        if (!CATEGORIES.includes(body.category) || !['lost', 'found'].includes(body.kind)) return '分类或类型无效';
        if (body.occurredAt !== undefined && (typeof body.occurredAt !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(body.occurredAt) || !Number.isFinite(Date.parse(body.occurredAt)) || new Date(body.occurredAt).toISOString().slice(0, 10) !== body.occurredAt || body.occurredAt > dateKey())) return '日期需为有效的YYYY-MM-DD，且不能晚于今天';
        if (body.requestId !== undefined && (typeof body.requestId !== 'string' || !body.requestId.trim() || body.requestId.length > 80)) return '请求标识无效';
        return '';
      };
      const fields = () => ({ title: body.title.trim(), description: body.description.trim(), location: body.location.trim(), contact: body.contact.trim(), kind: body.kind, category: body.category, occurredAt: body.occurredAt || dateKey() });
      if (url.pathname === '/api/items' && req.method === 'POST') {
        const invalid = validateItem(); if (invalid) return reply(res, 400, null, invalid);
        const existing = body.requestId && store.items.find(i => i.owner === actor && i.requestId === body.requestId);
        const payload = fields();
        // An omitted date was defaulted on the original request, not on each retry day.
        if (existing && body.occurredAt === undefined) payload.occurredAt = existing.occurredAt;
        const key = fingerprint(payload);
        if (existing) {
          if ((existing.createFingerprint || fingerprint(existing)) !== key) return reply(res, 409, null, '这份草稿已发布且内容不同，请在我的记录中编辑已发布启事');
          const drafts = store.drafts.filter(d => d.actor !== actor || d.input.requestId !== existing.requestId);
          if (drafts.length !== store.drafts.length) commit({ ...store, drafts });
          return reply(res, 201, view(existing));
        }
        const item = normalize({ ...payload, id: randomUUID(), owner: actor, status: 'open', createdAt: now(), requestId: body.requestId || '', createFingerprint: key });
        commit({ ...store, items: [item, ...store.items], drafts: store.drafts.filter(d => d.actor !== actor || d.input.requestId !== item.requestId) }); return reply(res, 201, view(item));
      }
      const match = url.pathname.match(/^\/api\/items\/([^/]+)(?:\/(resolve|withdraw|restore|update|favorite|claims|matches))?$/);
      if (match) {
        let id;
        try { id = decodeURIComponent(match[1]); } catch { return reply(res, 400, null, '物品标识格式错误'); }
        const item = list.find(i => i.id === id), action = match[2];
        if (!item || (item.status === 'withdrawn' && item.owner !== actor)) return reply(res, 404, null, '物品不存在或已撤回');
        if (!action && req.method === 'GET') return reply(res, 200, view(item));
        if (action === 'matches' && req.method === 'GET') {
          // Explainable rules suggest leads; they never establish ownership or unlock contact details.
          const rows = item.status !== 'open' ? [] : list.filter(i => i.id !== id && i.status === 'open' && i.kind !== item.kind && i.category === item.category && i.owner !== item.owner).map(candidate => {
            const reasons = ['同类物品'], a = item.location.trim(), b = candidate.location.trim(); let rank = 0;
            if (a === b) { rank += 4; reasons.push('同一地点'); }
            else if (a.includes(b) || b.includes(a) || Array.from({ length: Math.max(0, a.length - 1) }, (_, index) => a.slice(index, index + 2)).some(part => b.includes(part))) { rank += 2; reasons.push('地点相近'); }
            const gap = Math.abs(Date.parse(item.occurredAt) - Date.parse(candidate.occurredAt)) / 86400000;
            if (gap <= 3) { rank += 1; reasons.push('日期相近'); }
            return { item: view(candidate), reasons, rank };
          }).sort((a, b) => b.rank - a.rank || b.item.createdAt.localeCompare(a.item.createdAt) || a.item.id.localeCompare(b.item.id)).slice(0, 5);
          return reply(res, 200, { matches: rows.map(({ item, reasons }) => ({ item, reasons })) });
        }
        if (req.method !== 'POST') return reply(res, 404, null, '接口不存在');
        if (action === 'favorite') {
          if (typeof body.saved !== 'boolean') return reply(res, 400, null, '收藏状态无效');
          const favorites = store.favorites.filter(f => f.actor !== actor || f.itemId !== id);
          if (body.saved) favorites.push({ actor, itemId: id });
          commit({ ...store, favorites }); return reply(res, 200, view(item));
        }
        if (action === 'claims') {
          if (item.owner === actor) return reply(res, 403, null, '不能对本人启事提交申请');
          if (item.status !== 'open') return reply(res, 409, null, '启事已结束，不能继续申请');
          if (typeof body.proof !== 'string' || body.proof.trim().length < 8 || body.proof.trim().length > 240 || typeof body.contact !== 'string' || body.contact.trim().length < 2 || body.contact.trim().length > 60) return reply(res, 400, null, '核对说明需8-240字，联系指引需2-60字');
          if (store.claims.some(c => c.itemId === id && c.sender === actor && c.status === 'pending')) return reply(res, 409, null, '已有待核对申请，请到申请中心查看');
          const claim = { id: randomUUID(), itemId: id, sender: actor, owner: item.owner, proof: body.proof.trim(), contact: body.contact.trim(), status: 'pending', createdAt: now(), updatedAt: now() };
          commit({ ...store, claims: [claim, ...store.claims] }); return reply(res, 201, claimView(claim));
        }
        if (item.owner !== actor) return reply(res, 403, null, '仅可操作本人发布的信息');
        if (action === 'update') {
          if (item.status !== 'open') return reply(res, 409, null, '仅能编辑待寻回启事');
          const invalid = validateItem(); if (invalid) return reply(res, 400, null, invalid);
          // Existing claims refer to the original evidence; require withdrawing first if changing type/category.
          if ((body.kind !== item.kind || body.category !== item.category) && store.claims.some(c => c.itemId === id && c.status === 'pending')) return reply(res, 409, null, '已有待核对申请，请先处理后再更改类型或分类');
          const updated = { ...item, ...fields(), updatedAt: now(), history: [...item.history, event('更新物品线索')] };
          commit({ ...store, items: store.items.map(i => i.id === id ? updated : i) }); return reply(res, 200, view(updated));
        }
        const target = { resolve: 'resolved', withdraw: 'withdrawn', restore: 'open' }[action];
        if (!target) return reply(res, 404, null, '接口不存在');
        if (item.status === target) return reply(res, 200, view(item));
        if ((action === 'restore' && item.status !== 'withdrawn') || (action !== 'restore' && item.status !== 'open')) return reply(res, 409, null, '当前状态不支持此操作');
        const updated = { ...item, status: target, updatedAt: now(), resolvedAt: target === 'resolved' ? now() : '', history: [...item.history, event({ resolve: '发布者确认寻回', withdraw: '发布者撤回启事', restore: '重新开放启事' }[action])] };
        const claims = store.claims.map(c => c.itemId === id && c.status === 'pending' ? { ...c, status: 'cancelled', updatedAt: now() } : c);
        commit({ ...store, items: store.items.map(i => i.id === id ? updated : i), claims }); return reply(res, 200, view(updated));
      }
      const claimMatch = url.pathname.match(/^\/api\/claims\/([^/]+)\/(accept|reject|cancel)$/);
      if (claimMatch && req.method === 'POST') {
        let id;
        try { id = decodeURIComponent(claimMatch[1]); } catch { return reply(res, 400, null, '申请标识格式错误'); }
        const claim = store.claims.find(c => c.id === id), action = claimMatch[2];
        if (!claim) return reply(res, 404, null, '申请不存在');
        if ((action === 'cancel' ? claim.sender : claim.owner) !== actor) return reply(res, 403, null, '无权处理此申请');
        const target = { accept: 'accepted', reject: 'rejected', cancel: 'cancelled' }[action];
        if (claim.status === target) return reply(res, 200, claimView(claim));
        if (claim.status !== 'pending') return reply(res, 409, null, '申请已处理，请刷新查看');
        const item = store.items.find(i => i.id === claim.itemId);
        if (item.status !== 'open') return reply(res, 409, null, '启事已结束');
        const updated = { ...claim, status: target, updatedAt: now() };
        const claims = store.claims.map(c => c.id === id ? updated : action === 'accept' && c.itemId === item.id && c.status === 'pending' ? { ...c, status: 'rejected', updatedAt: now() } : c);
        const items = action === 'accept' ? store.items.map(i => i.id === item.id ? { ...i, status: 'resolved', updatedAt: now(), resolvedAt: now(), history: [...i.history, event('核对申请通过，确认完成交接')] } : i) : store.items;
        commit({ ...store, items, claims }); return reply(res, 200, claimView(updated));
      }
      return reply(res, 404, null, '接口不存在');
    } catch (error) { console.error(error.message); if (!res.headersSent) reply(res, 500, null, '保存失败或服务异常，请稍后重试'); else res.end(); }
  });
  return server;
}
if (require.main === module) {
  const port = Number(process.env.PORT || 4524);
  createApp({ file: process.env.DATA_FILE }).listen(port, '127.0.0.1', () => console.log(`CampusFinder Mock http://127.0.0.1:${port}`));
}
module.exports = { createApp, aggregate, seed };
