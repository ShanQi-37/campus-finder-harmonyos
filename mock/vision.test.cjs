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
  let selectedVideoFrame;
  let quality = 'clear';
  const open = async () => {
    const server = createApp({ file, delay: 0, recognize: async (frames, type) => {
      assert.ok(frames.length >= 1);
      assert.ok(frames.every(frame => frame[0] === 255 && frame[1] === 216));
      seen.push(frames.length);
      if (type === 'video') {
        assert.notDeepEqual(frames[0], frames[1]);
        selectedVideoFrame = frames[1];
      }
      if (quality === 'error') throw new Error('provider unavailable');
      return { quality, category: '生活用品', object: '保温杯', features: ['绿色', '白色贴纸'], coverFrame: 2 };
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
  generate(['-f', 'lavfi', '-i', 'testsrc2=s=96x64:d=3', '-c:v', 'libx264', videoPath]);
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
    assert.equal((await request('/api/item-media/unpublished/' + attached.id + '/cover')).status, 404);
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
    const coverRoute = '/api/item-media/' + id + '/' + attached.id + '/cover';
    const cover = await request(coverRoute);
    assert.equal(cover.status, 200);
    assert.equal(cover.headers.get('content-type'), 'image/jpeg');
    assert.deepEqual(Buffer.from(await cover.arrayBuffer()), selectedVideoFrame);
    const head = await request(coverRoute, { method: 'HEAD' });
    assert.equal(Number(head.headers.get('content-length')), selectedVideoFrame.length);

    // A recognized upload created before cover support has a video and metadata only.
    const savedCover = path.join(folder, 'media', 'peer-01-' + attached.id + '.cover.jpg');
    fs.rmSync(savedCover);
    const legacy = await request(coverRoute);
    assert.equal(legacy.status, 200);
    const legacyBytes = Buffer.from(await legacy.arrayBuffer());
    assert.deepEqual([...legacyBytes.subarray(0, 3)], [255, 216, 255]);
    assert.deepEqual(fs.readFileSync(savedCover), legacyBytes);
  });

  await t.test('寻物启事可保留本人上传的媒体和封面', async () => {
    const uploaded = await post('/api/media?type=video&analyze=true', video, 'peer-02');
    assert.equal(uploaded.status, 201);
    const mediaId = (await uploaded.json()).data.id;
    const lost = { ...notice, kind: 'lost', title: '寻找绿色保温杯', requestId: 'lost-ai-media' };
    assert.equal((await post('/api/draft', { ...lost, mediaId, occurredAt: '' }, 'peer-01')).status, 400);
    const draft = await post('/api/draft', { ...lost, mediaId, occurredAt: '' }, 'peer-02');
    assert.equal(draft.status, 200);
    assert.equal((await draft.json()).data.input.mediaId, mediaId);
    const created = await post('/api/items', { ...lost, mediaId }, 'peer-02');
    assert.equal(created.status, 201);
    const item = (await created.json()).data;
    assert.equal(item.kind, 'lost');
    assert.equal(item.mediaType, 'video');
    const route = '/api/item-media/' + item.id + '/' + mediaId;
    assert.equal((await request(route, { method: 'HEAD' })).headers.get('content-type'), 'video/mp4');
    assert.equal((await request(route + '/cover', { method: 'HEAD' })).headers.get('content-type'), 'image/jpeg');
    const updated = await post('/api/items/' + item.id + '/update', { ...lost, title: '寻找遗失的保温杯' }, 'peer-02');
    assert.equal((await updated.json()).data.mediaId, mediaId);
    const searched = await post('/api/media/search', photo, 'demo-user');
    assert.equal(searched.status, 200);
    assert.ok((await searched.json()).data.matches.every(match => match.item.id !== item.id));
    const removed = await post('/api/items/' + item.id + '/update', { ...lost, mediaId: '' }, 'peer-02');
    assert.equal((await removed.json()).data.mediaId, undefined);
    assert.equal((await request(route + '/cover')).status, 404);
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
    assert.equal((await request('/api/item-media/' + id + '/' + attached.id + '/cover')).status, 404);
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

  await t.test('拍照候选的真实申请与确认寻回进入同一统计', async () => {
    quality = 'clear';
    const openItem = await post('/api/items', { ...notice, requestId: 'funnel-notice' }, 'peer-01');
    assert.equal(openItem.status, 201);
    const itemId = (await openItem.json()).data.id;
    const response = await post('/api/media/search', photo);
    const result = (await response.json()).data;
    assert.ok(result.matches.some(candidate => candidate.item.id === itemId));
    const funnel = async () => (await (await request('/api/statistics/photo-search?days=7')).json()).data;
    const before = await funnel();
    const claimPath = '/api/items/' + itemId + '/claims';
    const input = { proof: '物品有白色贴纸，在图书馆遗失。', contact: '服务台转接', photoSearchId: result.searchId };
    assert.equal((await post(claimPath, input, 'peer-02')).status, 400);
    assert.equal((await post('/api/items/seed-1/claims', input)).status, 400);
    const submitted = await post(claimPath, input);
    assert.equal(submitted.status, 201);
    const claim = (await submitted.json()).data;
    assert.equal(claim.photoSearchId, undefined);
    assert.equal((await funnel()).applied, before.applied + 1);
    assert.equal((await funnel()).recovered, before.recovered);
    assert.equal((await post('/api/claims/' + claim.id + '/accept', {}, 'peer-01')).status, 200);
    await close();
    server = await open();
    const final = await funnel();
    assert.equal(final.recognized, before.recognized);
    assert.equal(final.matched, before.matched);
    assert.equal(final.recovered, before.recovered + 1);
  });

  await t.test('认领附件可选且仅申请双方可访问，图片和视频均绕过 AI', async () => {
    const second = await post('/api/items', { ...notice, requestId: 'evidence-second' }, 'peer-01');
    const secondId = (await second.json()).data.id;
    const upload = (itemId, type, bytes, actor) =>
      post('/api/items/' + itemId + '/claim-evidence?type=' + type + '&analyze=true', bytes, actor);
    const input = { proof: '我有物品外观标记的照片，可当面核实。', contact: '服务台转接' };
    const apply = (itemId, evidenceId, actor) => post('/api/items/' + itemId + '/claims', { ...input, evidenceId }, actor);
    const countBefore = seen.length;
    const imageResponse = await upload('seed-1', 'photo', photo);
    assert.equal(imageResponse.status, 201);
    const imageEvidence = (await imageResponse.json()).data;
    assert.equal(imageEvidence.analysisStatus, 'skipped');
    assert.equal(imageEvidence.recognition, null);
    assert.equal((await upload('seed-1', 'photo', photo, 'peer-01')).status, 404);
    assert.equal((await apply(secondId, imageEvidence.id)).status, 400);
    assert.equal((await apply('seed-1', imageEvidence.id, 'peer-02')).status, 400);
    assert.equal((await post('/api/items', { ...notice, requestId: 'evidence-public', mediaId: imageEvidence.id })).status, 400);

    const application = await apply('seed-1', imageEvidence.id);
    assert.equal(application.status, 201);
    const claim = (await application.json()).data;
    assert.equal(claim.evidenceType, 'photo');
    assert.equal(claim.evidenceId, undefined);
    const route = '/api/claims/' + claim.id + '/evidence';
    assert.equal((await request(route, { actor: 'peer-02' })).status, 404);
    assert.equal((await fetch(`http://127.0.0.1:${server.address().port}${route}`)).status, 404);
    const original = await request(route);
    assert.equal(original.headers.get('content-type'), 'image/jpeg');
    assert.ok((await original.arrayBuffer()).byteLength > 0);
    const received = (await (await request('/api/claims?direction=received', { actor: 'peer-01' })).json()).data.claims;
    assert.equal(received.find(row => row.id === claim.id).evidenceType, 'photo');
    assert.equal((await request('/api/item-media/seed-1/' + imageEvidence.id)).status, 404);
    const detail = (await (await request('/api/items/seed-1', { actor: 'peer-02' })).json()).data;
    assert.equal(detail.evidenceType, undefined);

    const videoResponse = await upload(secondId, 'video', video);
    assert.equal(videoResponse.status, 201);
    const videoEvidence = (await videoResponse.json()).data;
    assert.equal(videoEvidence.analysisStatus, 'skipped');
    assert.equal(seen.length, countBefore);
    const videoApplication = await apply(secondId, videoEvidence.id);
    assert.equal(videoApplication.status, 201);
    const videoClaim = (await videoApplication.json()).data;
    assert.equal(videoClaim.evidenceType, 'video');
    await close();
    server = await open();
    const stored = await request('/api/claims/' + videoClaim.id + '/evidence', {
      actor: 'peer-01', headers: { range: 'bytes=0-15' }
    });
    assert.equal(stored.status, 206);
    assert.equal(stored.headers.get('content-type'), 'video/mp4');
    assert.equal((await stored.arrayBuffer()).byteLength, 16);

    const optional = await apply(secondId, undefined, 'peer-02');
    assert.equal(optional.status, 201);
    assert.equal((await optional.json()).data.evidenceType, undefined);
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
  await recognize([sample, sample], 'video');
  assert.match(requestBody.messages[0].content, /coverFrame.*1 至 2/u);
  assert.deepEqual(requestBody.messages[1].content.filter(part => part.type === 'text').slice(1).map(part => part.text),
    ['第 1 帧', '第 2 帧']);
  assert.equal(createVisionProvider(categories, {}), null);
});
