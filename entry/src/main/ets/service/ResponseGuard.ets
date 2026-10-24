import { CATEGORIES, Claim, ClaimList, CountPoint, DraftState, Item, ItemList, MatchList, PersonalSummary, PublishInput, Statistics } from '../model/Models';

// Check every field used by the UI before accepting an untrusted HTTP payload.
export class ResponseGuard {
  static count(value: number): boolean { return Number.isSafeInteger(value) && value >= 0; }
  static strings(values: string[]): boolean { return values.every((value: string) => typeof value === 'string'); }
  static time(value: string): boolean { return typeof value === 'string' && value.length > 0 && Number.isFinite(Date.parse(value)); }
  static date(value: string): boolean {
    return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;
  }
  static input(input: PublishInput): boolean {
    return !!input && ResponseGuard.strings([input.title, input.location, input.description, input.contact, input.occurredAt, input.requestId]) &&
      input.title.length <= 36 && input.location.length <= 30 && input.description.length <= 300 && input.contact.length <= 60 && input.occurredAt.length <= 10 &&
      input.requestId.trim().length > 0 && input.requestId.length <= 80 && CATEGORIES.includes(input.category) && ['lost', 'found'].includes(input.kind);
  }
  static item(item: Item): boolean {
    return !!item && ResponseGuard.strings([item.id, item.title, item.category, item.kind, item.location, item.description, item.owner, item.ownerName, item.status, item.contact, item.resolvedAt]) &&
      item.id.length > 0 && CATEGORIES.includes(item.category) && ['lost', 'found'].includes(item.kind) && ['open', 'resolved', 'withdrawn'].includes(item.status) &&
      ResponseGuard.date(item.occurredAt) && ResponseGuard.time(item.createdAt) && ResponseGuard.time(item.updatedAt) &&
      (item.resolvedAt === '' || ResponseGuard.time(item.resolvedAt)) &&
      typeof item.contactVisible === 'boolean' && typeof item.saved === 'boolean' && typeof item.myPending === 'boolean' && ResponseGuard.count(item.claimCount) &&
      Array.isArray(item.history) && item.history.every((entry) => !!entry && typeof entry.label === 'string' && ResponseGuard.time(entry.at));
  }
  static list(data: ItemList): boolean {
    return !!data && Array.isArray(data.items) && data.items.every((item: Item) => ResponseGuard.item(item)) &&
      ResponseGuard.count(data.total) && ResponseGuard.count(data.page) && data.page >= 1 && ResponseGuard.count(data.pageSize) && data.pageSize >= 1 && data.pageSize <= 100 &&
      data.page <= Math.max(1, Math.ceil(data.total / data.pageSize)) &&
      data.items.length === Math.min(data.pageSize, Math.max(0, data.total - (data.page - 1) * data.pageSize)) &&
      data.hasMore === (data.page * data.pageSize < data.total);
  }
  static claim(claim: Claim): boolean {
    return !!claim && ResponseGuard.strings([claim.id, claim.itemId, claim.itemTitle, claim.sender, claim.owner, claim.senderName, claim.ownerName, claim.proof, claim.contact]) &&
      claim.id.length > 0 && claim.itemId.length > 0 && CATEGORIES.includes(claim.category) && ['lost', 'found'].includes(claim.kind) &&
      ['pending', 'accepted', 'rejected', 'cancelled'].includes(claim.status) && ResponseGuard.time(claim.createdAt) && ResponseGuard.time(claim.updatedAt);
  }
  static claims(data: ClaimList): boolean {
    return !!data && Array.isArray(data.claims) && data.claims.every((claim: Claim) => ResponseGuard.claim(claim)) && ResponseGuard.count(data.pending) &&
      data.pending === data.claims.filter((claim: Claim) => claim.status === 'pending').length;
  }
  static matches(data: MatchList): boolean {
    return !!data && Array.isArray(data.matches) && data.matches.length <= 5 && data.matches.every((lead) => !!lead && ResponseGuard.item(lead.item) &&
      Array.isArray(lead.reasons) && lead.reasons.length > 0 && ResponseGuard.strings(lead.reasons));
  }
  static draft(data: DraftState): boolean {
    return !!data && typeof data.exists === 'boolean' && (data.exists ?
      data.input !== null && ResponseGuard.input(data.input) && ResponseGuard.time(data.updatedAt) : data.input === null && data.updatedAt === '');
  }
  static summary(data: PersonalSummary): boolean {
    return !!data && [data.posted, data.open, data.resolved, data.saved, data.incomingPending, data.outgoingPending].every((value: number) => ResponseGuard.count(value)) &&
      data.open + data.resolved <= data.posted && typeof data.draftTitle === 'string' && typeof data.draftUpdatedAt === 'string' &&
      (data.draftTitle.length ? ResponseGuard.time(data.draftUpdatedAt) : data.draftUpdatedAt === '');
  }
  static points(points: CountPoint[]): boolean {
    return Array.isArray(points) && points.every((point: CountPoint) => !!point && typeof point.label === 'string' && ResponseGuard.count(point.count));
  }
  static statistics(data: Statistics): boolean {
    if (!data || ![data.total, data.open, data.resolved, data.lost, data.found, data.withdrawn, data.pendingClaims, data.recoveryRate].every((value: number) => ResponseGuard.count(value)) ||
      ![7, 14, 30].includes(data.days) || (data.category !== 'all' && !CATEGORIES.includes(data.category)) || !ResponseGuard.time(data.updatedAt) ||
      !ResponseGuard.points(data.categories) || !ResponseGuard.points(data.trend)) { return false; }
    return data.total === data.open + data.resolved && data.total === data.lost + data.found &&
      data.categories.length === CATEGORIES.length && data.categories.every((point: CountPoint, index: number) => point.label === CATEGORIES[index]) &&
      data.trend.length === data.days && data.trend.every((point: CountPoint) => /^\d{2}-\d{2}$/.test(point.label)) &&
      data.categories.reduce((sum: number, point: CountPoint) => sum + point.count, 0) === data.total &&
      data.trend.reduce((sum: number, point: CountPoint) => sum + point.count, 0) === data.total &&
      data.recoveryRate === (data.total ? Math.round(data.resolved / data.total * 100) : 0);
  }
}
