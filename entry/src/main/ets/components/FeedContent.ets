import { CATEGORY_OPTIONS, CATEGORIES, STATUS_OPTIONS, Item } from '../model/Models';
import { FeedModel } from '../model/FeedModel';
import { Colors, FontSize, Radius, Spacing, ItemCard, SegmentTab, StatePanel } from './Common';

@ComponentV2
export struct FeedContent {
  @Param model: FeedModel = new FeedModel();
  @Param filters: boolean = true;
  @Param showPublishedDate: boolean = false;
  @Param showResolvedDate: boolean = false;
  @Event onOpen: (id: string) => void = () => {};
  @Event onRefresh: () => void = () => {};
  @Local filtersOpen: boolean = false;

  reset(): void {
    this.model.reset();
    this.onRefresh();
  }

  filterCount(): number {
    return (this.model.category === 'all' ? 0 : 1) + (this.model.status === 'all' ? 0 : 1) +
      (this.model.sort === 'latest' ? 0 : 1);
  }

  setKind(kind: string): void {
    if (this.model.kind !== kind) {
      this.model.kind = kind;
      this.model.load();
    }
  }

  @Builder
  searchControls() {
    Row({ space: Spacing.sm }) {
      TextInput({ placeholder: '搜索物品或地点', text: this.model.keywordInput }).constraintSize({ minHeight: 44 })
        .fontSize(FontSize.body).maxLength(80).enterKeyType(EnterKeyType.Search).placeholderColor(Colors.faint)
        .backgroundColor(Colors.glass).borderRadius(Radius.sm).border({ width: 1, color: Colors.glassStroke }).layoutWeight(1)
        .accessibilityText('按物品或地点搜索，可用空格分隔多个关键词')
        .onChange((value: string) => { this.model.keywordInput = value; }).onSubmit(() => { this.model.search(); })
      Button('搜索').constraintSize({ minWidth: 64, minHeight: 44 }).fontSize(FontSize.body).fontWeight(FontWeight.Bold)
        .backgroundColor(Colors.green).borderRadius(Radius.sm).onClick(() => { this.model.search(); })
    }.width('100%').padding({ left: Spacing.lg, right: Spacing.lg })
    Column() {
      Row({ space: 4 }) {
        SegmentTab({ label: '全部', selected: this.model.kind === 'all', onSelect: () => this.setKind('all') }).layoutWeight(1)
        SegmentTab({ label: '寻物启事', selected: this.model.kind === 'lost', onSelect: () => this.setKind('lost') }).layoutWeight(1)
        SegmentTab({ label: '招领启事', selected: this.model.kind === 'found', onSelect: () => this.setKind('found') }).layoutWeight(1)
      }.width('100%').backgroundColor(Colors.glass).borderRadius(Radius.md).padding(3)
    }.width('100%').padding({ left: Spacing.lg, right: Spacing.lg })
  }

  @Builder
  filterHeading() {
    Row({ space: Spacing.sm }) {
      Column({ space: 2 }) {
        Text(this.model.phase === 'ready' ? this.model.total + ' 条启事' : '校园线索')
          .fontSize(FontSize.title).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
        if (this.model.keyword) {
          Text('关键词：' + this.model.keyword).fontSize(FontSize.caption).fontColor(Colors.faint)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Button((this.filterCount() ? '筛选 ' + this.filterCount() : '筛选') + (this.filtersOpen ? '  ∧' : '  ∨'))
        .constraintSize({ minHeight: 40 }).fontSize(FontSize.caption).fontColor(Colors.greenDeep).backgroundColor(Colors.surface).borderRadius(Radius.sm)
        .border({ width: 1, color: Colors.stroke }).accessibilitySelected(this.filtersOpen)
        .onClick(() => { this.filtersOpen = !this.filtersOpen; })
    }.width('100%').padding({ left: Spacing.lg, right: Spacing.lg })
  }

  @Builder
  filterOptions() {
    Column({ space: Spacing.xs }) {
      Row({ space: 6 }) {
        Select(CATEGORY_OPTIONS).value(this.model.category === 'all' ? '全部分类' : this.model.category)
          .selected(CATEGORIES.indexOf(this.model.category) + 1).font({ size: FontSize.caption }).constraintSize({ minHeight: 40 })
          .backgroundColor(Colors.paper).layoutWeight(1).accessibilityText('物品分类')
          .onSelect((index: number) => {
            this.model.category = index === 0 ? 'all' : CATEGORIES[index - 1];
            this.model.load();
          })
        Select(STATUS_OPTIONS).value(this.model.status === 'all' ? '全部状态' : (this.model.status === 'open' ? '待寻回' : '已寻回'))
          .selected(this.model.status === 'all' ? 0 : (this.model.status === 'open' ? 1 : 2)).font({ size: FontSize.caption }).constraintSize({ minHeight: 40 })
          .backgroundColor(Colors.paper).layoutWeight(1).accessibilityText('启事状态')
          .onSelect((index: number) => {
            this.model.status = index === 0 ? 'all' : (index === 1 ? 'open' : 'resolved');
            this.model.load();
          })
      }.width('100%')
      Row() {
        Button(this.model.sort === 'latest' ? '最新发布 ↓' : '最早发布 ↑').constraintSize({ minHeight: 36 }).fontSize(FontSize.caption)
          .fontColor(Colors.greenDeep).backgroundColor(Colors.paper).borderRadius(Radius.sm).onClick(() => {
            this.model.sort = this.model.sort === 'latest' ? 'oldest' : 'latest';
            this.model.load();
          })
        Blank()
        Button('清空筛选').constraintSize({ minHeight: 36 }).fontSize(FontSize.caption).fontColor(Colors.muted).backgroundColor(Colors.surface)
          .onClick(() => this.reset())
      }.width('100%')
    }.width('100%').padding(Spacing.sm).backgroundColor(Colors.surface).borderRadius(Radius.md).border({ width: 1, color: Colors.stroke })
  }

  @Builder
  pagination() {
    Row({ space: Spacing.sm }) {
      Button('‹ 上一页').constraintSize({ minHeight: 38 }).fontSize(FontSize.caption).fontColor(Colors.greenDeep).backgroundColor(Colors.surface)
        .enabled(this.model.page > 1).onClick(() => this.model.turn(-1))
      Text('第 ' + this.model.page + ' 页 · 共 ' + this.model.total + ' 条').fontSize(FontSize.caption).fontColor(Colors.faint)
        .layoutWeight(1).textAlign(TextAlign.Center)
      Button('下一页 ›').constraintSize({ minHeight: 38 }).fontSize(FontSize.caption).fontColor(Colors.greenDeep).backgroundColor(Colors.surface)
        .enabled(this.model.hasMore).onClick(() => this.model.turn(1))
    }.width('100%').padding({ left: Spacing.lg, right: Spacing.lg, top: 6, bottom: 4 })
  }

  build() {
    Column({ space: Spacing.sm }) {
      if (this.filters) {
        this.searchControls()
        this.filterHeading()
        if (this.filtersOpen) {
          Column() { this.filterOptions() }.width('100%').padding({ left: Spacing.lg, right: Spacing.lg })
        }
      }
      if (this.model.phase !== 'ready') {
        StatePanel({ phase: this.model.phase, error: this.model.error,
          emptyText: this.filters && this.model.keyword ? '没有符合这些关键词的启事' : '暂无符合条件的启事',
          emptyAction: this.filters ? '清空筛选' : '刷新信息', onRetry: () => {
            if (this.filters && this.model.phase === 'empty') { this.reset(); }
            else { this.model.load(false); this.onRefresh(); }
          } }).layoutWeight(1)
      } else {
        List({ space: Spacing.sm }) {
          ForEach(this.model.items, (item: Item) => {
            ListItem() {
              ItemCard({ item: item, showPublishedDate: this.showPublishedDate, showResolvedDate: this.showResolvedDate,
                onOpen: (id: string) => this.onOpen(id) })
            }
          }, (item: Item) => item.id)
        }.layoutWeight(1).padding({ left: Spacing.lg, right: Spacing.lg, bottom: Spacing.md }).scrollBar(BarState.Auto).width('100%')
        if (this.model.hasMore || this.model.page > 1) { this.pagination() }
      }
    }.width('100%').height('100%')
  }
}
