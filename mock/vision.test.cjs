const test = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { once } = require('node:events');
const http = require('node:http');
const { createApp } = require('./server.cjs');
const { createVisionProvider, parseRecognition } = require('./vision.cjs');

test('媒体上传、草稿、AI 分类与拍照匹配', async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'campus-vision-test-'));
  const file = path.join(folder, 'store.json');
  const seen = [];
  let quality = 'clear';
  const open = async () => {
    const server = createApp({ file, delay: 0, recognize: async frames => {
      assert.ok(frames.length >= 1);
      assert.ok(frames.every(frame => frame[0] === 255 && frame[1] === 216));
      seen.push(frames.length);
      if (quality === 'error') throw new Error('provider unavailable');
      return { quality, category: '生活用品', object: '保温杯', features: ['绿色', '白色贴纸'] };
    } });
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    return server;
  };
  let server;
  const close = () => server && new Promise(resolve => {
    server.close(resolve);
    server.closeAllConnections();
  });
  t.after(async () => { await close(); fs.rmSync(folder, { recursive: true, force: true }); });
  const ffmpeg = process.env.CAMPUS_FFMPEG || 'ffmpeg';
  const photoPath = path.join(folder, 'source.jpg');
  const videoPath = path.join(folder, 'source.mp4');
  const generate = args => execFileSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', ...args], { windowsHide: true });
  generate(['-f', 'lavfi', '-i', 'color=green:s=96x64', '-frames:v', '1', photoPath]);
  generate(['-f', 'lavfi', '-i', 'color=green:s=96x64:d=3', '-c:v', 'libx264', videoPath]);
  const photo = fs.readFileSync(photoPath), video = fs.readFileSync(videoPath);
  server = await open();
  const request = (route, { method = 'GET', actor = 'demo-user', body, headers = {} } = {}) => {
    const payload = body === undefined || Buffer.isBuffer(body) ? body : JSON.stringify(body);
    return fetch(`http://127.0.0.1:${server.address().port}${route}`, {
      method, headers: { 'x-demo-user': actor, ...headers }, body: payload
    });
  };
  const post = (route, body, actor) => request(route, { method: 'POST', actor, body });
  let attached, id;
  const notice = { kind: 'found', category: '生活用品', title: '图书馆拾到保温杯', location: '图书馆',
    description: '在阅览室拾到绿色的保温杯，杯身有白色贴纸。', contact: '服务台转接', requestId: 'vision-notice' };

  await t.test('验证附件格式、识别和草稿所用附件归属', async () => {
    assert.equal((await post('/api/media?type=photo', Buffer.from('not an image'))).status, 415);
    const uploaded = await post('/api/media?type=video&analyze=true', video, 'peer-01');
    assert.equal(uploaded.status, 201);
    attached = (await uploaded.json()).data;
    assert.equal(attached.analysisStatus, 'recognized');
    assert.equal(attached.recognition.category, '生活用品');
    assert.equal(seen[0], 2);
    const draft = { ...notice, mediaId: attached.id, occurredAt: '' };
    assert.equal((await post('/api/draft', draft, 'demo-user')).status, 400);
    const stored = await post('/api/draft', draft, 'peer-01');
    assert.equal((await stored.json()).data.input.mediaId, attached.id);
    assert.equal((await request('/api/item-media/unpublished/' + attached.id)).status, 404);
  });

  await t.test('发布附件、幂等重试、视频范围和重启后读取', async () => {
    const input = { ...notice, mediaId: attached.id };
    const created = await post('/api/items', input, 'peer-01');
    assert.equal(created.status, 201);
    id = (await created.json()).data.id;
    const repeated = await post('/api/items', input, 'peer-01');
    assert.equal((await repeated.json()).data.id, id);
    assert.equal((await post('/api/items', { ...input, mediaId: '' }, 'peer-01')).status, 409);
    await close();
    server = await open();
    const media = await request('/api/item-media/' + id + '/' + attached.id, { headers: { range: 'bytes=0-15' } });
    assert.equal(media.status, 206);
    assert.equal(media.headers.get('content-type'), 'video/mp4');
    assert.match(media.headers.get('content-range'), /^bytes 0-15\/\d+$/);
    assert.equal((await media.arrayBuffer()).byteLength, 16);
  });

  await t.test('通过照片特征匹配，只返回可申领启事且保护联系指引', async () => {
    const found = await post('/api/media/search', photo);
    assert.equal(found.status, 200);
    const data = (await found.json()).data;
    assert.equal(data.matches[0].item.id, id);
    assert.equal(data.matches[0].item.contactVisible, false);
    assert.match(data.matches[0].reasons.join(' '), /外观特征/u);
    const own = await post('/api/media/search', photo, 'peer-01');
    assert.ok((await own.json()).data.matches.every(candidate => candidate.item.id !== id));
    assert.equal((await post('/api/items/' + id + '/withdraw', {}, 'peer-01')).status, 200);
    assert.equal((await request('/api/item-media/' + id + '/' + attached.id)).status, 404);
    const hidden = await post('/api/media/search', photo);
    assert.ok((await hidden.json()).data.matches.every(candidate => candidate.item.id !== id));
  });

  await t.test('看不清和模型失败时允许人工分类或重新查找', async () => {
    quality = 'uncertain';
    assert.equal((await post('/api/media/search', photo)).status, 422);
    quality = 'error';
    assert.equal((await post('/api/media/search', photo)).status, 502);
    const result = await post('/api/media?type=photo&analyze=true', photo);
    assert.equal(result.status, 201);
    assert.equal((await result.json()).data.analysisStatus, 'failed');
  });
});

test('视觉适配器向兼容服务提交图像并解析分类', async t => {
  let requestBody, auth;
  const service = http.createServer(async (req, res) => {
    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    requestBody = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    auth = req.headers.authorization;
    res.writeHead(req.url === '/v1/chat/completions' ? 200 : 404, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ choices: [{ message: { content: JSON.stringify({
      quality: 'clear', category: '电子数码', object: '耳机', features: ['黑色', '黑色', '1234567']
    }) } }] }));
  });
  service.listen(0, '127.0.0.1');
  await once(service, 'listening');
  t.after(() => new Promise(resolve => {
    service.close(resolve);
    service.closeAllConnections();
  }));
  const categories = ['电子数码'];
  const recognize = createVisionProvider(categories, {
    CAMPUS_VISION_API_KEY: 'test-key', CAMPUS_VISION_MODEL: 'test-vision',
    CAMPUS_VISION_BASE_URL: `http://127.0.0.1:${service.address().port}/v1`
  });
  const sample = Buffer.from([255, 216, 255]);
  const result = parseRecognition(await recognize([sample]), categories);
  assert.equal(auth, 'Bearer test-key');
  assert.equal(requestBody.model, 'test-vision');
  assert.equal(requestBody.messages[1].content[1].image_url.url, 'data:image/jpeg;base64,' + sample.toString('base64'));
  assert.deepEqual(result, { category: '电子数码', object: '耳机', features: ['黑色'] });
  assert.equal(createVisionProvider(categories, {}), null);
});
