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
  @Trace updated: string = '';
  private generation: number = 0;
  owner: string = '';

  async load(): Promise<void> {
    const ticket = ++this.generation;
    this.phase = 'loading';
    this.error = '';
    try {
      const result = await Api.list(this.kind, this.category, this.keyword, this.owner);
      // A delayed response must never replace the user's newer filter result.
      if (ticket !== this.generation) { return; }
      this.items = result.items;
      this.phase = result.items.length ? 'ready' : 'empty';
      this.updated = new Date().toLocaleTimeString();
    } catch (error) {
      if (ticket !== this.generation) { return; }
      this.items = [];
      this.phase = 'error';
      this.error = (error as Error).message;
    }
  }
  cancel(): void { this.generation++; }
}
