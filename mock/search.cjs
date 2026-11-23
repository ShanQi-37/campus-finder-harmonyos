function searchCriteria(value, categories, today, isDateKey) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const criteria = {};
  for (const [field, limit] of [['keyword', 80], ['location', 30], ['category', 12], ['occurredFrom', 10], ['occurredTo', 10]]) {
    if (typeof value[field] !== 'string' || value[field].trim().length > limit) return null;
    criteria[field] = value[field].trim();
  }
  const { keyword, location, category, occurredFrom, occurredTo } = criteria;
  if (category !== 'all' && !categories.includes(category)) return null;
  if ((occurredFrom || occurredTo) && (!isDateKey(occurredFrom) || !isDateKey(occurredTo) ||
      occurredFrom > occurredTo || occurredTo > today)) return null;
  if (!keyword && !location && !occurredFrom && category === 'all') return null;
  return criteria;
}

function photoFunnel(searches, claims, days, end) {
  const start = new Date(Date.parse(end) - (days - 1) * 86400000).toISOString().slice(0, 10);
  const rows = searches.filter(row => row.day >= start && row.day <= end);
  const withCandidates = new Set(rows.filter(row => row.candidateIds.length > 0).map(row => row.id));
  const applied = new Set(), recovered = new Set();
  for (const claim of claims) {
    if (!withCandidates.has(claim.photoSearchId)) continue;
    applied.add(claim.photoSearchId);
    if (claim.status === 'accepted') recovered.add(claim.photoSearchId);
  }
  return { days, start, end, recognized: rows.length, matched: withCandidates.size, applied: applied.size, recovered: recovered.size };
}

module.exports = { searchCriteria, photoFunnel };
