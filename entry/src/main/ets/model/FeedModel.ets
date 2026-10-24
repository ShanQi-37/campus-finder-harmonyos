import { Item } from './Models';
import { Api } from '../service/Api';
@ObservedV2
export class FeedModel {
  @Trace items: Item[] = [];
  @Trace phase: string = 'loading';
  @Trace error: string = '';
  @Trace kind: string = 'all';
  @Trace category: string = 'all';
  @Trace keyword: string = '';
  @Trace status: string = 'all';
  @Trace sort: string = 'latest';
  @Trace total: number = 0;
  @Trace page: number = 1;
  @Trace hasMore: boolean = false;
  @Trace updated: string = '';
  private generation: number = 0;
  owner: string = '';
  saved: boolean = false;
  async load(reset: boolean = true): Promise<void> {
    const ticket = ++this.generation;
    if (reset) { this.page = 1; }
    this.phase = 'loading'; this.error = '';
    try {
      const result = await Api.list(this.kind, this.category, this.keyword, this.owner, this.status, this.sort, this.saved, this.page);
      // Requests are tagged so older results cannot overwrite a newer choice.
      if (ticket !== this.generation) { return; }
      this.items = result.items; this.total = result.total; this.hasMore = result.hasMore;
      this.phase = result.items.length ? 'ready' : 'empty'; this.updated = new Date().toLocaleTimeString();
    } catch (error) {
      if (ticket !== this.generation) { return; }
      this.items = []; this.phase = 'error'; this.error = (error as Error).message;
    }
  }
  reset(): void { this.keyword = ''; this.kind = 'all'; this.category = 'all'; this.status = 'all'; this.sort = 'latest'; this.load(); }
  turn(delta: number): void { if (this.phase === 'loading' || this.page + delta < 1) { return; } this.page += delta; this.load(false); }
  cancel(): void { this.generation++; }
}
