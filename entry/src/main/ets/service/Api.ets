import { http } from '@kit.NetworkKit';
import { Claim, ClaimInput, ClaimList, DraftState, Item, ItemList, MatchList, PersonalSummary, PublishInput, Statistics } from '../model/Models';
import { ResponseGuard } from './ResponseGuard';
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
    if (!ResponseGuard.list(data)) { throw new Error('返回列表格式异常'); }
    return data;
  }
  static async detail(id: string): Promise<Item> {
    const data = await Api.request<Item>('/api/items/' + encodeURIComponent(id));
    if (!ResponseGuard.item(data)) { throw new Error('返回详情格式异常'); }
    return data;
  }
  private static async itemResponse(request: Promise<Item>): Promise<Item> { const item = await request; if (!ResponseGuard.item(item)) { throw new Error('返回启事格式异常，请刷新后核对结果'); } return item; }
  private static async claimResponse(request: Promise<Claim>): Promise<Claim> { const claim = await request; if (!ResponseGuard.claim(claim)) { throw new Error('返回申请格式异常，请刷新后核对结果'); } return claim; }
  static publish(input: PublishInput, id: string = ''): Promise<Item> { return Api.itemResponse(Api.request<Item>('/api/items' + (id.length ? '/' + encodeURIComponent(id) + '/update' : ''), JSON.stringify(input))); }
  static action(id: string, action: string): Promise<Item> { return Api.itemResponse(Api.request<Item>('/api/items/' + encodeURIComponent(id) + '/' + action, '{}')); }
  static favorite(id: string, saved: boolean): Promise<Item> { return Api.itemResponse(Api.request<Item>('/api/items/' + encodeURIComponent(id) + '/favorite', JSON.stringify({ saved: saved }))); }
  static claim(id: string, input: ClaimInput): Promise<Claim> { return Api.claimResponse(Api.request<Claim>('/api/items/' + encodeURIComponent(id) + '/claims', JSON.stringify(input))); }
  static async claims(direction: string, status: string = 'all'): Promise<ClaimList> {
    const data = await Api.request<ClaimList>('/api/claims?direction=' + encodeURIComponent(direction) + '&status=' + encodeURIComponent(status));
    if (!ResponseGuard.claims(data)) { throw new Error('返回申请格式异常'); }
    return data;
  }
  static review(id: string, action: string): Promise<Claim> { return Api.claimResponse(Api.request<Claim>('/api/claims/' + encodeURIComponent(id) + '/' + action, '{}')); }
  static async matches(id: string): Promise<MatchList> {
    const data = await Api.request<MatchList>('/api/items/' + encodeURIComponent(id) + '/matches');
    if (!ResponseGuard.matches(data)) { throw new Error('返回线索格式异常'); }
    return data;
  }
  static async draft(): Promise<DraftState> {
    const data = await Api.request<DraftState>('/api/draft');
    if (!ResponseGuard.draft(data)) { throw new Error('返回草稿格式异常'); }
    return data;
  }
  static async saveDraft(input: PublishInput): Promise<DraftState> { const data = await Api.request<DraftState>('/api/draft', JSON.stringify(input)); if (!ResponseGuard.draft(data)) { throw new Error('返回草稿格式异常，请刷新后核对保存结果'); } return data; }
  static async discardDraft(requestId: string, updatedAt: string): Promise<DraftState> {
    const data = await Api.request<DraftState>('/api/draft/discard', JSON.stringify({ requestId: requestId, updatedAt: updatedAt }));
    if (!ResponseGuard.draft(data) || data.exists) { throw new Error('返回草稿格式异常，请重新加载后核对结果'); }
    return data;
  }
  static async me(): Promise<PersonalSummary> {
    const data = await Api.request<PersonalSummary>('/api/me');
    if (!ResponseGuard.summary(data)) { throw new Error('返回任务格式异常'); }
    return data;
  }
  static async statistics(days: number = 7, category: string = 'all'): Promise<Statistics> {
    const data = await Api.request<Statistics>('/api/statistics?days=' + days + '&category=' + encodeURIComponent(category));
    if (!ResponseGuard.statistics(data)) { throw new Error('返回统计格式异常'); }
    return data;
  }
}
