import { Colors, ItemCard, PageHeader, StatePanel, AmbientBackground, Shadow } from '../components/Common';
import { CATEGORIES, CATEGORY_OPTIONS, Item, SearchCriteria } from '../model/Models';
import { FoundSearchModel } from '../model/FoundSearchModel';
import { Api } from '../service/Api';
import { ResponseGuard } from '../service/ResponseGuard';

@ComponentV2
export struct TextSearchPage {
  @Local query: string = '';
  @Local keyword: string = '';
  @Local location: string = '';
  @Local category: string = 'all';
  @Local from: string = '';
  @Local to: string = '';
  @Local interpreting: boolean = false;
  @Local hint: string = '';
  @Local error: string = '';
  @Local model: FoundSearchModel = new FoundSearchModel();
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;

  async interpret(): Promise<void> {
    if (this.interpreting || this.model.phase === 'loading') { return; }
    const text = this.query.trim();
    this.hint = '';
    this.error = '';
    if (!text) { this.error = '请先描述要找的物品'; return; }
    const ticket = ++this.generation;
    this.interpreting = true;
    try {
      const criteria = await Api.interpretSearch(text);
      if (ticket !== this.generation) { return; }
      this.keyword = criteria.keyword;
      this.location = criteria.location;
      this.category = criteria.category;
      this.from = criteria.occurredFrom;
      this.to = criteria.occurredTo;
      this.model.clear();
      this.hint = '已提取条件，可以修改后再搜索。';
    } catch (error) {
      if (ticket === this.generation) { this.error = (error as Error).message; }
    } finally {
      if (ticket === this.generation) { this.interpreting = false; }
    }
  }

  submit(): void {
    if (this.interpreting || this.model.phase === 'loading') { return; }
    this.error = '';
    this.hint = '';
    const start = this.from.trim() || this.to.trim();
    const end = this.to.trim() || this.from.trim();
    const criteria: SearchCriteria = { keyword: this.keyword.trim(), location: this.location.trim(),
      category: this.category, occurredFrom: start, occurredTo: end };
    const today = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' });
    if (!ResponseGuard.searchCriteria(criteria) || end > today) {
      this.error = '请填写有效日期 YYYY-MM-DD，且结束日期不能晚于今天';
      return;
    }
    if (!criteria.keyword && !criteria.location && !start && criteria.category === 'all') {
      this.error = '请至少填写一个筛选条件';
      return;
    }
    this.model.search(criteria);
  }

  fillExample(): void {
    this.query = '我在图书馆丢了一张校园卡';
    this.error = '';
  }

  @Builder
  form() {
    Column({ space: 10 }) {
      TextArea({ text: this.query, placeholder: '例如：昨天在图书馆丢了蓝色耳机盒' })
        .height(92).maxLength(160).backgroundColor(Colors.paper).borderRadius(10)
        .accessibilityText('找物描述').onChange((text: string) => { this.query = text; })
      Text('点「提取条件」会将描述发给 AI，请避开姓名和联系方式。').fontSize(12)
        .fontColor(Colors.muted).width('100%')
      if (!this.query.trim()) {
        Button('填入示例描述').fontSize(12).fontColor(Colors.green).backgroundColor(Colors.surface)
          .constraintSize({ minHeight: 40 }).width('100%').onClick(() => this.fillExample())
      }
      Button(this.interpreting ? '正在提取…' : 'AI 提取条件').width('100%').constraintSize({ minHeight: 44 })
        .fontColor(Colors.green).backgroundColor(Colors.soft).onClick(() => { this.interpret(); })
      Text('搜索条件').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
      TextInput({ text: this.keyword, placeholder: '物品关键词' }).maxLength(80).constraintSize({ minHeight: 44 })
        .backgroundColor(Colors.paper).accessibilityText('物品关键词').onChange((text: string) => { this.keyword = text; })
      TextInput({ text: this.location, placeholder: '发生地点' }).maxLength(30).constraintSize({ minHeight: 44 })
        .backgroundColor(Colors.paper).accessibilityText('发生地点').onChange((text: string) => { this.location = text; })
      Select(CATEGORY_OPTIONS).selected(CATEGORIES.indexOf(this.category) + 1)
        .value(this.category === 'all' ? '全部分类' : this.category).width('100%')
        .backgroundColor(Colors.paper).onSelect((i: number) => { this.category = i > 0 ? CATEGORIES[i - 1] : 'all'; })
      Text('发生日期 · 可留空').fontSize(12).fontColor(Colors.muted).width('100%')
      TextInput({ text: this.from, placeholder: '开始  YYYY-MM-DD' }).maxLength(10).constraintSize({ minHeight: 44 })
        .backgroundColor(Colors.paper).accessibilityText('开始日期').onChange((text: string) => { this.from = text; })
      TextInput({ text: this.to, placeholder: '结束  YYYY-MM-DD' }).maxLength(10).constraintSize({ minHeight: 44 })
        .backgroundColor(Colors.paper).accessibilityText('结束日期').onChange((text: string) => { this.to = text; })
      Button('搜索招领启事').width('100%').constraintSize({ minHeight: 46 })
        .backgroundColor(Colors.green).onClick(() => this.submit())
      if (this.hint) { Text(this.hint).fontSize(13).fontColor(Colors.green).width('100%') }
      if (this.error) { Text(this.error).fontSize(13).fontColor(Colors.red).width('100%') }
    }.padding(14).width('100%').borderRadius(16).backgroundColor(Colors.glass)
      .border({ width: 1, color: Colors.glassStroke }).backdropBlur(20)
      .shadow({ radius: 8, color: Shadow.sm, offsetX: 0, offsetY: 2 })
      .enabled(!this.interpreting && this.model.phase !== 'loading')
  }

  build() {
    NavDestination() {
      Stack() {
        AmbientBackground()
        Column({ space: 8 }) {
        PageHeader({ title: '描述找物', back: true, onBack: () => { this.stack.pop(); } })
        Scroll() {
          Column({ space: 12 }) {
            this.form()
            if (this.model.phase === 'ready') {
              Text('搜索结果 · ' + this.model.result.total + ' 条').fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor(Colors.ink).width('100%')
              Text('已应用 · ' + this.model.appliedLabel).fontSize(12).fontColor(Colors.muted).width('100%')
              ForEach(this.model.result.items, (item: Item) => {
                ItemCard({ item: item, onOpen: (id: string) => { this.stack.pushPath({ name: 'Detail', param: id }); } })
              }, (item: Item) => item.id + ':' + item.updatedAt)
              if (this.model.result.page > 1 || this.model.result.hasMore) {
                Row({ space: 12 }) {
                  Button('上一页').enabled(this.model.result.page > 1).layoutWeight(1)
                    .onClick(() => { this.model.turn(-1); })
                  Button('下一页').enabled(this.model.result.hasMore).layoutWeight(1)
                    .onClick(() => { this.model.turn(1); })
                }.width('100%')
              }
            } else if (this.model.phase !== 'idle') {
              StatePanel({ phase: this.model.phase, error: this.model.error, emptyText: '没有符合条件的招领启事',
                emptyAction: '重新查询', onRetry: () => { this.model.retry(); } })
            }
          }.width('100%').padding({ left: 16, right: 16, bottom: 16 })
        }.layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top)
        }.width('100%').height('100%')
      }.width('100%').height('100%')
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
    }).onShown(() => { this.model.refresh(); }).onDisAppear(() => { this.generation++; this.model.clear(); })
  }
}
