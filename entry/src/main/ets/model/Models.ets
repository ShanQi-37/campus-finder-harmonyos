export interface Item {
  id: string;
  title: string;
  category: string;
  kind: string;
  location: string;
  description: string;
  owner: string;
  status: string;
  contact: string;
  occurredAt: string;
  createdAt: string;
}
export interface ItemList { items: Item[]; total: number; }
export interface CountPoint { label: string; count: number; }
export interface Statistics {
  total: number;
  resolved: number;
  open: number;
  recoveryRate: number;
  categories: CountPoint[];
  trend: CountPoint[];
  updatedAt: string;
}
export interface PublishInput { title: string; category: string; kind: string; location: string; description: string; contact: string; }
export const CATEGORIES: string[] = ['证件卡片', '电子数码', '生活用品', '学习文具'];
export function emptyItem(): Item {
  return { id: '', title: '', category: '', kind: 'lost', location: '', description: '', owner: '', status: 'open', contact: '', occurredAt: '', createdAt: '' };
}
export function emptyStatistics(): Statistics {
  return { total: 0, resolved: 0, open: 0, recoveryRate: 0, categories: [], trend: [], updatedAt: '' };
}
