import { CATEGORY_OPTIONS, CATEGORIES, Statistics, emptyStatistics } from '../model/Models';
import { Api } from '../service/Api';
import { Colors, PageHeader, SegmentTab, StatePanel } from '../components/Common';
import { BottomNav } from '../components/BottomNav';
import { CategoryChart, RecoveryChart, TrendChart } from '../components/Charts';
@ComponentV2
export struct StatisticsPage {
  @Local data: Statistics = emptyStatistics();
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local chart: string = 'overview';
  @Local days: number = 7;
  @Local category: string = 'all';
  @Local anchor: string = 'today';
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;
  async load(): Promise<void> {
    const ticket = ++this.generation; this.phase = 'loading';
    try { const data = await Api.statistics(this.days, this.category, this.anchor); if (ticket !== this.generation) { return; } this.data = data; this.phase = data.total ? 'ready' : 'empty'; }
    catch (error) { if (ticket !== this.generation) { return; } this.error = (error as Error).message; this.phase = 'error'; }
  }
  aboutToDisappear(): void { this.generation++; }
  selectAnchor(anchor: string): void {
    if (this.anchor === anchor) { return; }
    this.anchor = anchor;
    this.load();
  }
  selectDays(days: number): void {
    if (this.days !== days) {
      this.days = days;
      this.load();
    }
  }
  retry(): void {
    if (this.phase === 'empty') {
      if (this.anchor === 'today') { this.anchor = 'latest'; }
      else { this.category = 'all'; }
    }
    this.load();
  }
  navigate(route: string): void {
    if (route === 'Statistics') { this.load(); }
    else if (route === 'Home') { this.stack.clear(); }
    else if (route === 'Publish') { this.stack.pushPath({ name: 'Publish', param: '' }); }
    else { this.stack.replacePath({ name: route, param: '' }); }
  }
  @Builder
  metric(label: string, value: number) {
    Column({ space: 4 }) {
      Text(value.toString()).fontSize(23).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(1)
      Text(label).fontSize(11).fontColor(Colors.muted).maxLines(1)
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }
  @Builder
  controls() {
    Column({ space: 7 }) {
      Row({ space: 5 }) {
        SegmentTab({ label: '截至今天', selected: this.anchor === 'today',
          onSelect: () => this.selectAnchor('today') }).layoutWeight(1)
        SegmentTab({ label: '最近有记录', selected: this.anchor === 'latest',
          onSelect: () => this.selectAnchor('latest') }).layoutWeight(1)
      }.width('100%').padding(3).borderRadius(13).backgroundColor(Colors.soft)
      Row({ space: 5 }) {
        Row({ space: 3 }) {
          ForEach([7, 14, 30], (days: number) => {
            SegmentTab({ label: days + '日', selected: this.days === days,
              onSelect: () => this.selectDays(days) }).layoutWeight(1)
          }, (days: number) => days.toString())
        }.layoutWeight(3).padding(2).borderRadius(12).backgroundColor(Colors.soft)
        Select(CATEGORY_OPTIONS).value(this.category === 'all' ? '全部分类' : this.category)
          .selected(CATEGORIES.indexOf(this.category) + 1).font({ size: 12 }).height(42)
          .layoutWeight(2).backgroundColor(Colors.surface).accessibilityText('统计类别')
          .onSelect((index: number) => {
            const category = index === 0 ? 'all' : CATEGORIES[index - 1];
            if (category !== this.category) { this.category = category; this.load(); }
          })
        Button('↻').width(44).height(42).fontSize(20).fontColor(Colors.green).borderRadius(10)
          .backgroundColor(Colors.surface).accessibilityText('刷新统计').onClick(() => { this.load(); })
      }.width('100%')
    }.width('100%').padding({ left: 16, right: 16 })
  }
  @Builder
  dashboard() {
    Scroll() {
      Column({ space: 10 }) {
        Grid() {
          GridItem() { this.metric('有效启事', this.data.total) }
          GridItem() { this.metric('已寻回', this.data.resolved) }
          GridItem() { this.metric('待寻回', this.data.open) }
        }.width('100%').height(65).columnsTemplate('1fr 1fr 1fr').rowsTemplate('1fr')
          .backgroundColor(Colors.surface).borderRadius(14)
          .border({ width: 1, color: Colors.stroke })
        Row({ space: 4 }) {
          SegmentTab({ label: '寻回进度', selected: this.chart === 'overview',
            onSelect: () => { this.chart = 'overview'; } }).layoutWeight(1)
          SegmentTab({ label: '类别分布', selected: this.chart === 'category',
            onSelect: () => { this.chart = 'category'; } }).layoutWeight(1)
          SegmentTab({ label: '发布趋势', selected: this.chart === 'trend',
            onSelect: () => { this.chart = 'trend'; } }).layoutWeight(1)
        }.width('100%').backgroundColor(Colors.soft).padding(3).borderRadius(13)
        if (this.chart === 'overview') { RecoveryChart({ data: this.data }) }
        else if (this.chart === 'category') { CategoryChart({ points: this.data.categories }) }
        else { TrendChart({ points: this.data.trend }) }
        Column({ space: 6 }) {
          Text('寻物 ' + this.data.lost + ' 条 · 招领 ' + this.data.found + ' 条').fontSize(12).fontColor(Colors.ink)
          Text('待核对申请 ' + this.data.pendingClaims + ' 条 · 已撤回 ' + this.data.withdrawn + ' 条')
            .fontSize(12).fontColor(Colors.muted)
          Text('更新于 ' + new Date(this.data.updatedAt).toLocaleTimeString()).fontSize(11).fontColor(Colors.muted)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 3, top: 4 })
      }.width('100%').padding({ left: 16, right: 16, bottom: 18 })
    }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top)
  }
  build() {
    NavDestination() {
      Column({ space: 8 }) {
        PageHeader({ title: '校园互助统计', subtitle: '启事发布与寻回数据', back: true, onBack: () => { this.stack.pop(); } })
        this.controls()
        if (this.phase === 'ready' || this.phase === 'empty') {
          Text(this.data.windowStart + ' 至 ' + this.data.windowEnd + ' · 按发布日期')
            .fontSize(11).fontColor(Colors.muted).width('100%').padding({ left: 16, right: 16 })
        }
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, emptyText: '所选范围暂无有效启事',
            emptyAction: this.anchor === 'today' ? '查看最近有记录的时段' : (this.category === 'all' ? '刷新统计' : '查看全部分类'),
            onRetry: () => this.retry() }).layoutWeight(1)
        } else { this.dashboard() }
        BottomNav({ active: 'Statistics', onNavigate: (route: string) => this.navigate(route) })
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; }).onShown(() => { this.load(); })
  }
}
