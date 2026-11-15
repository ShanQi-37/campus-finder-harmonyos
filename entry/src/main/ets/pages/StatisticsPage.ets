import { CATEGORY_OPTIONS, CATEGORIES, Statistics, emptyStatistics } from '../model/Models';
import { Api } from '../service/Api';
import { ChoiceChip, Colors, PageHeader, StatePanel } from '../components/Common';
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
  metric(label: string, value: number, accent: boolean) {
    Row() {
      Column({ space: 5 }) {
        Text(label).fontSize(11).fontColor(accent ? '#C7DDCC' : Colors.muted)
        Text(value.toString()).fontSize(27).fontWeight(FontWeight.Bold).fontColor(accent ? '#FFF5DD' : Colors.green)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(accent ? '↗' : '·').fontSize(25).fontColor(accent ? '#DCBE78' : '#BCCFBE')
    }.width('100%').height(67).padding(12).backgroundColor(accent ? '#1A6254' : '#FFFFFF').borderRadius(16)
  }
  build() {
    NavDestination() {
      Column({ space: 10 }) {
        PageHeader({ title: '校园互助统计', subtitle: '把善意化成可见的校园温度', back: true, onBack: () => { this.stack.pop(); } })
        Row({ space: 7 }) {
          ChoiceChip({ label: '截至今天', selected: this.anchor === 'today', onSelect: () => this.selectAnchor('today') })
          ChoiceChip({ label: '最近有记录', selected: this.anchor === 'latest', onSelect: () => this.selectAnchor('latest') })
          Blank()
          Text('刷新 ↻').fontSize(11).fontColor(Colors.green).padding(6).onClick(() => { this.load(); })
        }.width('100%').padding({ left: 18, right: 18 })
        Row({ space: 7 }) {
          ForEach([7, 14, 30], (days: number) => { ChoiceChip({ label: days + '日', selected: this.days === days, onSelect: () => { this.days = days; this.load(); } }) }, (days: number) => days.toString())
          Select(CATEGORY_OPTIONS).value(this.category === 'all' ? '全部分类' : this.category).font({ size: 10 }).height(32).layoutWeight(1).backgroundColor('#E4ECE4')
            .onSelect((index: number) => { this.category = index === 0 ? 'all' : CATEGORIES[index - 1]; this.load(); })
        }.width('100%').padding({ left: 18, right: 18 })
        if (this.phase === 'ready' || this.phase === 'empty') {
          Text(this.data.windowStart + ' 至 ' + this.data.windowEnd + ' · 按发布日期')
            .fontSize(10).fontColor(Colors.muted).width('100%').padding({ left: 18, right: 18 })
        }
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, emptyText: '所选范围暂无有效启事',
            emptyAction: this.anchor === 'today' ? '查看最近有记录的时段' : (this.category === 'all' ? '刷新统计' : '查看全部分类'),
            onRetry: () => this.retry() }).layoutWeight(1)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              Grid() {
                GridItem() { this.metric('有效启事', this.data.total, true) }
                GridItem() { this.metric('已寻回', this.data.resolved, false) }
                GridItem() { this.metric('等待重逢', this.data.open, false) }
                GridItem() { this.metric('待核对申请', this.data.pendingClaims, false) }
              }.columnsTemplate('1fr 1fr').columnsGap(10).rowsGap(10).height(144).width('100%')
              Row({ space: 7 }) {
                ChoiceChip({ label: '寻回概览', selected: this.chart === 'overview', onSelect: () => { this.chart = 'overview'; } })
                ChoiceChip({ label: '类别分布', selected: this.chart === 'category', onSelect: () => { this.chart = 'category'; } })
                ChoiceChip({ label: '发布与寻回', selected: this.chart === 'trend', onSelect: () => { this.chart = 'trend'; } })
              }.width('100%')
              if (this.chart === 'overview') { RecoveryChart({ data: this.data }) }
              else if (this.chart === 'category') { CategoryChart({ points: this.data.categories }) }
              else { TrendChart({ points: this.data.trend }) }
              Text('寻物 ' + this.data.lost + ' 条 · 招领 ' + this.data.found + ' 条 · 已撤回 ' + this.data.withdrawn + ' 条\n更新于 ' + new Date(this.data.updatedAt).toLocaleTimeString()).fontSize(10).fontColor(Colors.muted).lineHeight(18).width('100%')
            }.width('100%').padding({ left: 18, right: 18, bottom: 20 })
          }.layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top)
        }
        BottomNav({ active: 'Statistics', onNavigate: (route: string) => this.navigate(route) })
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; }).onShown(() => { this.load(); })
  }
}
