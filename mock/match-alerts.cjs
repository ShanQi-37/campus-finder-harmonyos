const { createHash } = require('node:crypto');

const normalize = text => (text || '').normalize('NFKC').toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
const itemName = text => normalize(text).replace(/^(?:我?(?:想要)?(?:寻找|找回|找|寻物|丢失|遗失|拾到|捡到|招领))(?:一[个件只支顶把张本部条副对双])?/u, '');
const genericNames = new Set(['物品', '东西', '失物', '线索']);
const sameName = (a, b) => a.length >= 2 && b.length >= 2 && !genericNames.has(a) && !genericNames.has(b)
  && (a.includes(b) || b.includes(a));

function placeSimilarity(a, b) {
  if (!a || !b) return 0;
  if (a === b) return 4;
  if (a.includes(b) || b.includes(a)) return 2;
  for (let index = 0; index < a.length - 1; index++) {
    if (b.includes(a.slice(index, index + 2))) return 2;
  }
  return 0;
}

function matchAlerts(items, actor, recognitionFor) {
  const open = items.filter(item => item.status === 'open');
  const profiles = new Map();
  function profile(item) {
    if (!profiles.has(item.id)) {
      const recognition = recognitionFor(item);
      const features = (recognition?.features || []).map(normalize).filter(feature => feature.length >= 2);
      profiles.set(item.id, { names: [itemName(item.title), itemName(recognition?.object)],
        features, evidence: [normalize(item.title), normalize(item.description), ...features],
        location: normalize(item.location), date: Date.parse(item.occurredAt) });
    }
    return profiles.get(item.id);
  }
  const own = open.filter(item => item.owner === actor);
  const others = open.filter(item => item.owner !== actor);
  const alerts = [];
  for (const source of own) {
    for (const candidate of others) {
      if (source.kind === candidate.kind || source.category !== candidate.category) continue;
      const a = profile(source), b = profile(candidate);
      if (!(Math.abs(a.date - b.date) <= 7 * 86400000)) continue;
      const place = placeSimilarity(a.location, b.location);
      const name = a.names.some(first => b.names.some(second => sameName(first, second)));
      if (!name) continue;
      const features = new Set([
        ...a.features.filter(feature => b.evidence.some(field => field.includes(feature))),
        ...b.features.filter(feature => a.evidence.some(field => field.includes(feature)))
      ]);
      if (!place && features.size < 2) continue;
      const reasons = ['物品名称相近', '日期相近'];
      if (place) reasons.push(place === 4 ? '同一地点' : '地点相近');
      if (features.size) reasons.push('外观特征相近');
      const id = createHash('sha256').update(JSON.stringify([source.id, candidate.id].sort())).digest('hex');
      const createdAt = source.createdAt > candidate.createdAt ? source.createdAt : candidate.createdAt;
      alerts.push({ id, source, candidate, reasons, createdAt });
    }
  }
  return alerts.sort((a, b) => b.createdAt.localeCompare(a.createdAt) || a.id.localeCompare(b.id));
}

module.exports = { matchAlerts, placeSimilarity };
