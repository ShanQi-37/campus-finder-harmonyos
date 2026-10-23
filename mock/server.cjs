const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
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
function aggregate(items) {
  const total = items.length, resolved = items.filter(i => i.status === 'resolved').length;
  return {
    total, resolved, open: total - resolved, recoveryRate: total ? Math.round(resolved / total * 100) : 0,
    categories: CATEGORIES.map(label => ({ label, count: items.filter(i => i.category === label).length })),
    trend: Array.from({ length: 7 }, (_, index) => {
      const day = dateKey(new Date(Date.now() - (6 - index) * 86400000));
      return { label: day.slice(5), count: items.filter(i => dateKey(new Date(i.createdAt)) === day).length };
    }), updatedAt: new Date().toISOString()
  };
}
function createApp(options = {}) {
  const file = options.file || path.join(__dirname, 'runtime', 'items.json');
  let items = options.memory ? seed() : (fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : seed());
  let fault = 'normal';
  const save = () => { if (!options.memory) { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, JSON.stringify(items, null, 2)); } };
  const reply = (res, status, data, message = 'ok') => { res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'Access-Control-Allow-Origin': '*' }); res.end(JSON.stringify({ code: status < 400 ? 0 : status, message, data })); };
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://127.0.0.1');
    const started = Date.now();
    res.on('finish', () => console.log(JSON.stringify({ time: new Date().toISOString(), method: req.method, path: url.pathname, query: url.search, status: res.statusCode, ms: Date.now() - started })));
    try {
      let raw = '';
      for await (const chunk of req) { raw += chunk; if (raw.length > 16384) { reply(res, 413, null, '请求过大'); return; } }
      let body;
      try { body = raw ? JSON.parse(raw) : {}; } catch { reply(res, 400, null, 'JSON格式错误'); return; }
      // Loopback-only test control; never exposed in the application's user interface.
      if (url.pathname === '/__test/mode' && req.method === 'POST') {
        if (!['normal', 'error', 'empty', 'slow', 'malformed'].includes(body.mode)) return reply(res, 400, null, '模式无效');
        fault = body.mode; return reply(res, 200, { mode: fault });
      }
      if (url.pathname === '/health') return reply(res, 200, { service: 'CampusFinder', count: items.length });
      if (!url.pathname.startsWith('/api/')) return reply(res, 404, null, '接口不存在');
      await new Promise(resolve => setTimeout(resolve, fault === 'slow' ? 2500 : (options.delay ?? 250)));
      if (req.method === 'GET' && fault === 'error') return reply(res, 503, null, '服务暂不可用，请稍后重试');
      if (req.method === 'GET' && fault === 'malformed') { res.writeHead(200, { 'Content-Type': 'application/json' }); return res.end('{invalid'); }
      const list = fault === 'empty' ? [] : items;
      if (url.pathname === '/api/statistics' && req.method === 'GET') return reply(res, 200, aggregate(list));
      if (url.pathname === '/api/items' && req.method === 'GET') {
        let result = list;
        for (const key of ['category', 'kind', 'owner']) { const value = url.searchParams.get(key); if (value && value !== 'all') result = result.filter(i => i[key] === value); }
        const keyword = (url.searchParams.get('keyword') || '').trim().toLowerCase();
        if (keyword) result = result.filter(i => `${i.title} ${i.description} ${i.location}`.toLowerCase().includes(keyword));
        return reply(res, 200, { items: [...result].sort((a, b) => b.createdAt.localeCompare(a.createdAt)), total: result.length });
      }
      if (url.pathname === '/api/items' && req.method === 'POST') {
        for (const [key, min, max] of [['title', 2, 36], ['location', 2, 30], ['description', 8, 300], ['contact', 2, 60]]) {
          if (typeof body[key] !== 'string' || body[key].trim().length < min || body[key].trim().length > max) return reply(res, 400, null, `${key}长度应为${min}-${max}`);
        }
        if (!CATEGORIES.includes(body.category) || !['lost', 'found'].includes(body.kind)) return reply(res, 400, null, '分类或类型无效');
        const item = { id: randomUUID(), title: body.title.trim(), description: body.description.trim(), location: body.location.trim(), contact: body.contact.trim(), kind: body.kind, category: body.category, occurredAt: dateKey(), owner: 'demo-user', status: 'open', createdAt: new Date().toISOString() };
        items.unshift(item); save(); return reply(res, 201, item);
      }
      const match = url.pathname.match(/^\/api\/items\/([^/]+)(\/resolve)?$/);
      if (match) {
        const item = list.find(i => i.id === decodeURIComponent(match[1]));
        if (!item) return reply(res, 404, null, '物品不存在或已移除');
        if (!match[2] && req.method === 'GET') return reply(res, 200, item);
        if (match[2] && req.method === 'POST') {
          if (item.owner !== 'demo-user') return reply(res, 403, null, '仅可操作本人发布的信息');
          item.status = 'resolved'; save(); return reply(res, 200, item);
        }
      }
      reply(res, 404, null, '接口不存在');
    } catch (error) { console.error(error.message); if (!res.headersSent) reply(res, 500, null, '服务器内部错误'); else res.end(); }
  });
  return server;
}
if (require.main === module) {
  const port = Number(process.env.PORT || 4524);
  createApp({ file: process.env.DATA_FILE }).listen(port, '127.0.0.1', () => console.log(`CampusFinder Mock http://127.0.0.1:${port}`));
}
module.exports = { createApp, aggregate, seed };
