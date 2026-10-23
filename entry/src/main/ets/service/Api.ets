import { http } from '@kit.NetworkKit';
import { Item, ItemList, PublishInput, Statistics } from '../model/Models';
interface Envelope<T> { code: number; message: string; data: T; }
// Previewer runs on the host. A simulator needs hdc rport tcp:4524 tcp:4524.
export const BASE_URL: string = 'http://127.0.0.1:4524';
export class Api {
  private static async request<T>(path: string, body?: string): Promise<T> {
    const client = http.createHttp();
    try {
      const response = await client.request(BASE_URL + path, {
        method: body === undefined ? http.RequestMethod.GET : http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: body ?? '', expectDataType: http.HttpDataType.STRING,
        connectTimeout: 4000, readTimeout: 6000, usingCache: false
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        if (response.responseCode === 404) { throw new Error('信息已移除，请返回刷新'); }
        throw new Error('服务暂不可用，请稍后重试');
      }
      const envelope = JSON.parse(response.result as string) as Envelope<T>;
      if (envelope.code !== 0 || envelope.data === undefined || envelope.data === null) { throw new Error('返回数据不完整，请重试'); }
      return envelope.data;
    } catch (error) {
      const message: string = (error as Error).message ?? '';
      if (message.startsWith('信息') || message.startsWith('服务') || message.startsWith('返回')) { throw new Error(message); }
      throw new Error('连接失败或数据异常，请检查网络后重试');
    } finally { client.destroy(); }
  }
  static async list(kind: string, category: string, keyword: string, owner: string = ''): Promise<ItemList> {
    const data = await Api.request<ItemList>('/api/items?kind=' + encodeURIComponent(kind) + '&category=' + encodeURIComponent(category) + '&keyword=' + encodeURIComponent(keyword) + '&owner=' + encodeURIComponent(owner));
    if (!Array.isArray(data.items) || typeof data.total !== 'number') { throw new Error('返回列表格式异常'); }
    return data;
  }
  static detail(id: string): Promise<Item> { return Api.request<Item>('/api/items/' + encodeURIComponent(id)); }
  static publish(input: PublishInput): Promise<Item> { return Api.request<Item>('/api/items', JSON.stringify(input)); }
  static resolve(id: string): Promise<Item> { return Api.request<Item>('/api/items/' + encodeURIComponent(id) + '/resolve', '{}'); }
  static async statistics(): Promise<Statistics> {
    const data = await Api.request<Statistics>('/api/statistics');
    if (!Array.isArray(data.categories) || !Array.isArray(data.trend) || typeof data.total !== 'number') { throw new Error('返回统计格式异常'); }
    return data;
  }
}
