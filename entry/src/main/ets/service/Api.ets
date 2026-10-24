import { http } from '@kit.NetworkKit';
import { Claim, ClaimInput, ClaimList, DraftState, Item, ItemList, MatchList, PersonalSummary, PublishInput, Statistics } from '../model/Models';
import { Session } from '../model/Session';
interface Envelope<T> { code: number; message: string; data: T; }
export const BASE_URL: string = 'http://127.0.0.1:4524';
export class Api {
  private static async request<T>(path: string, body?: string): Promise<T> {
    const client = http.createHttp();
    let businessMessage: string = '';
    try {
      const response = await client.request(BASE_URL + path, {
        method: body === undefined ? http.RequestMethod.GET : http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'X-Demo-User': Session.actor },
        extraData: body ?? '', expectDataType: http.HttpDataType.STRING,
        connectTimeout: 4000, readTimeout: 6000, usingCache: false
      });
      const envelope = JSON.parse(response.result as string) as Envelope<T>;
      if (response.responseCode < 200 || response.responseCode >= 300 || envelope.code !== 0) {
        businessMessage = typeof envelope.message === 'string' ? envelope.message : '服务暂不可用，请稍后重试';
        throw new Error(businessMessage);
      }
      if (envelope.data === undefined || envelope.data === null) { throw new Error('返回数据不完整'); }
      return envelope.data;
    } catch (error) {
      throw new Error(businessMessage.length ? businessMessage : '连接失败或数据异常，请检查网络后重试');
    } finally { client.destroy(); }
  }
  static async list(kind: string, category: string, keyword: string, owner: string = '', status: string = 'all', sort: string = 'latest', saved: boolean = false, page: number = 1): Promise<ItemList> {
    const data = await Api.request<ItemList>('/api/items?kind=' + encodeURIComponent(kind) + '&category=' + encodeURIComponent(category) + '&keyword=' + encodeURIComponent(keyword) + '&owner=' + encodeURIComponent(owner) + '&status=' + encodeURIComponent(status) + '&sort=' + sort + '&saved=' + saved + '&pageSize=2&page=' + page);
    if (!Array.isArray(data.items) || !Number.isFinite(data.total) || typeof data.hasMore !== 'boolean' || data.items.some((i: Item) => typeof i.id !== 'string' || typeof i.title !== 'string' || !Array.isArray(i.history))) { throw new Error('返回列表格式异常'); }
    return data;
  }
  static async detail(id: string): Promise<Item> {
    const data = await Api.request<Item>('/api/items/' + encodeURIComponent(id));
    if (typeof data.id !== 'string' || typeof data.title !== 'string' || !Array.isArray(data.history)) { throw new Error('返回详情格式异常'); }
    return data;
  }
  static publish(input: PublishInput, id: string = ''): Promise<Item> { return Api.request<Item>('/api/items' + (id.length ? '/' + encodeURIComponent(id) + '/update' : ''), JSON.stringify(input)); }
  static action(id: string, action: string): Promise<Item> { return Api.request<Item>('/api/items/' + encodeURIComponent(id) + '/' + action, '{}'); }
  static favorite(id: string, saved: boolean): Promise<Item> { return Api.request<Item>('/api/items/' + encodeURIComponent(id) + '/favorite', JSON.stringify({ saved: saved })); }
  static claim(id: string, input: ClaimInput): Promise<Claim> { return Api.request<Claim>('/api/items/' + encodeURIComponent(id) + '/claims', JSON.stringify(input)); }
  static async claims(direction: string): Promise<ClaimList> {
    const data = await Api.request<ClaimList>('/api/claims?direction=' + direction);
    if (!Array.isArray(data.claims) || !Number.isFinite(data.pending)) { throw new Error('返回申请格式异常'); }
    return data;
  }
  static review(id: string, action: string): Promise<Claim> { return Api.request<Claim>('/api/claims/' + encodeURIComponent(id) + '/' + action, '{}'); }
  static async matches(id: string): Promise<MatchList> {
    const data = await Api.request<MatchList>('/api/items/' + encodeURIComponent(id) + '/matches');
    if (!Array.isArray(data.matches) || data.matches.some((lead) => !lead.item || typeof lead.item.id !== 'string' || !Array.isArray(lead.reasons))) { throw new Error('返回线索格式异常'); }
    return data;
  }
  static async draft(): Promise<DraftState> {
    const data = await Api.request<DraftState>('/api/draft');
    if (typeof data.exists !== 'boolean' || (data.exists && (!data.input || typeof data.input.requestId !== 'string'))) { throw new Error('返回草稿格式异常'); }
    return data;
  }
  static saveDraft(input: PublishInput): Promise<DraftState> { return Api.request<DraftState>('/api/draft', JSON.stringify(input)); }
  static async me(): Promise<PersonalSummary> {
    const data = await Api.request<PersonalSummary>('/api/me');
    if (![data.posted, data.open, data.resolved, data.saved, data.incomingPending, data.outgoingPending].every((n: number) => Number.isFinite(n) && n >= 0) || typeof data.draftTitle !== 'string') { throw new Error('返回任务格式异常'); }
    return data;
  }
  static async statistics(days: number = 7, category: string = 'all'): Promise<Statistics> {
    const data = await Api.request<Statistics>('/api/statistics?days=' + days + '&category=' + encodeURIComponent(category));
    if (!Array.isArray(data.categories) || !Array.isArray(data.trend) || !Number.isFinite(data.total) || !Number.isFinite(data.recoveryRate) || data.trend.some((p) => !Number.isFinite(p.count))) { throw new Error('返回统计格式异常'); }
    return data;
  }
}
