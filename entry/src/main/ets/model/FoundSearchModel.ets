import { ItemList, SearchCriteria } from './Models';
import { Api } from '../service/Api';

@ObservedV2
export class FoundSearchModel {
  @Trace phase: string = 'idle';
  @Trace error: string = '';
  @Trace appliedLabel: string = '';
  @Trace result: ItemList = { items: [], total: 0, page: 1, pageSize: 6, hasMore: false };
  private submitted?: SearchCriteria;
  private requestedPage: number = 1;
  private generation: number = 0;

  search(criteria: SearchCriteria): Promise<void> {
    this.submitted = criteria;
    const date = criteria.occurredFrom === criteria.occurredTo ? criteria.occurredFrom :
      criteria.occurredFrom + ' 至 ' + criteria.occurredTo;
    this.appliedLabel = [criteria.keyword, criteria.location, criteria.category === 'all' ? '' : criteria.category, date]
      .filter((part: string) => part.length > 0).join(' · ');
    return this.load(1);
  }

  turn(delta: number): Promise<void> {
    if (this.phase !== 'ready' || (delta < 0 && this.result.page <= 1) ||
      (delta > 0 && !this.result.hasMore)) { return Promise.resolve(); }
    return this.load(this.result.page + delta);
  }

  retry(): Promise<void> {
    return this.load(this.requestedPage);
  }

  refresh(): Promise<void> {
    if (this.phase !== 'ready' && this.phase !== 'empty') { return Promise.resolve(); }
    return this.load(this.result.page);
  }

  clear(): void {
    this.generation++;
    this.submitted = undefined;
    this.requestedPage = 1;
    this.error = '';
    this.appliedLabel = '';
    this.phase = 'idle';
  }

  async load(page: number): Promise<void> {
    const criteria = this.submitted;
    if (criteria === undefined) { return; }
    const ticket = ++this.generation;
    this.requestedPage = page;
    this.phase = 'loading';
    this.error = '';
    try {
      const result = await Api.searchFound(criteria, page);
      if (ticket !== this.generation) { return; }
      this.result = result;
      this.phase = result.total ? 'ready' : 'empty';
    } catch (error) {
      if (ticket !== this.generation) { return; }
      this.error = (error as Error).message;
      this.phase = 'error';
    }
  }
}
