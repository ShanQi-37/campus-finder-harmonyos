export interface TimelineEvent { label: string; at: string; }
export interface Item {
  id: string; title: string; category: string; kind: string; location: string; description: string;
  owner: string; ownerName: string; status: string; contact: string; contactVisible: boolean;
  occurredAt: string; createdAt: string; updatedAt: string; resolvedAt: string;
  saved: boolean; myPending: boolean; claimCount: number; history: TimelineEvent[];
}
export interface ItemList { items: Item[]; total: number; page: number; pageSize: number; hasMore: boolean; }
export interface CountPoint { label: string; count: number; }
export interface Statistics {
  total: number; resolved: number; open: number; recoveryRate: number; lost: number; found: number;
  withdrawn: number; pendingClaims: number; categories: CountPoint[]; trend: CountPoint[]; days: number; category: string; updatedAt: string;
}
export interface PublishInput { title: string; category: string; kind: string; location: string; description: string; contact: string; occurredAt: string; requestId: string; }
export interface ClaimInput { proof: string; contact: string; }
export interface Claim {
  id: string; itemId: string; itemTitle: string; category: string; kind: string; sender: string; owner: string;
  senderName: string; ownerName: string; proof: string; contact: string; status: string; createdAt: string; updatedAt: string;
}
export interface ClaimList { claims: Claim[]; pending: number; }
export const CATEGORIES: string[] = ['证件卡片', '电子数码', '生活用品', '学习文具'];
export const CATEGORY_OPTIONS: SelectOption[] = [{ value: '全部分类' }, { value: '证件卡片' }, { value: '电子数码' }, { value: '生活用品' }, { value: '学习文具' }];
export const STATUS_OPTIONS: SelectOption[] = [{ value: '全部状态' }, { value: '待寻回' }, { value: '已寻回' }];
export function emptyItem(): Item { return { id: '', title: '', category: '证件卡片', kind: 'lost', location: '', description: '', owner: '', ownerName: '', status: 'open', contact: '', contactVisible: false, occurredAt: '', createdAt: '', updatedAt: '', resolvedAt: '', saved: false, myPending: false, claimCount: 0, history: [] }; }
export function emptyStatistics(): Statistics { return { total: 0, resolved: 0, open: 0, recoveryRate: 0, lost: 0, found: 0, withdrawn: 0, pendingClaims: 0, categories: [], trend: [], days: 7, category: 'all', updatedAt: '' }; }
