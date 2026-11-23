import { CATEGORY_OPTIONS, CATEGORIES, CountPoint, Statistics, StatisticsScope, TrendPoint, emptyStatistics } from '../model/Models';
import { Api } from '../service/Api';
import { Colors, PageHeader, SegmentTab, StatePanel, AmbientBackground } from '../components/Common';
import { BottomNav } from '../components/BottomNav';
import { CategoryChart, RecoveryChart, TrendChart } from '../components/Charts';

@ComponentV2
struct StatisticsMetric {
  @Param label: string = '';
  @Param value: number = 0;
  @Event onOpen: () => void = () => {};

  build() {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 4 }) {
        Text(this.value.toString()).fontSize(23).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(1)
        Text(this.label + ' ›').fontSize(11).fontColor(Colors.green).maxLines(1)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    }.width('100%').height('100%').padding(0).backgroundColor(Colors.surface)
      .accessibilityText(this.label + ' ' + this.value + ' 条，查看启事').onClick(() => this.onOpen())
  }
}

@ComponentV2
export struct StatisticsPage {
  @Local data: Statistics = emptyStatistics();
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local chart: string = 'overview';
  @Local days: number = 7;
  @Local category: string = 'all';
  @Local anchor: string = 'today';
  @Local selectedDay: number = 0;
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;
  async load(): Promise<void> {
    const ticket = ++this.generation; this.phase = 'loading';
    try { const data = await Api.statistics(this.days, this.category, this.anchor); if (ticket !== this.generation) { return; } this.data = data;
      const recoveries = data.recoveryTrend.reduce((sum: number, point: CountPoint) => sum + point.count, 0);
      this.phase = data.total > 0 || recoveries > 0 ? 'ready' : 'empty'; }
    catch (error) { if (ticket !== this.generation) { return; } this.error = (error as Error).message; this.phase = 'error'; }
  }
  aboutToDisappear(): void { this.generation++; }
  recoveryPoints(): TrendPoint[] {
    return this.data.recoveryTrend.map((point: CountPoint) => {
      const trend: TrendPoint = { label: point.label, count: point.count, resolved: 0 };
      return trend;
    });
  }
  selectAnchor(anchor: string): void {
    if (this.anchor === anchor) { return; }
    this.anchor = anchor;
    this.selectedDay = 0;
    this.load();
  }
  selectDays(days: number): void {
    if (this.days !== days) {
      this.days = days;
      this.selectedDay = 0;
      this.load();
    }
  }
  retry(): void {
    if (this.phase === 'empty') {
      if (this.anchor === 'today') { this.anchor = 'latest'; }
      else { this.category = 'all'; }
      this.selectedDay = 0;
    }
    this.load();
  }
  navigate(route: string): void {
    if (route === 'Statistics') { this.load(); }
    else if (route === 'Home') { this.stack.clear(); }
    else if (route === 'Publish') { this.stack.pushPath({ name: 'Publish', param: '' }); }
    else { this.stack.replacePath({ name: route, param: '' }); }
  }
  openItems(status: string, index: number = -1, dateType: string = 'published', category: string = this.data.category): void {
    if (this.phase !== 'ready') { return; }
    const recovery = dateType === 'resolved';
    let start = recovery ? this.data.recoveryWindowStart : this.data.windowStart;
    let end = recovery ? this.data.recoveryWindowEnd : this.data.windowEnd;
    if (index >= 0) {
      const count = recovery ?
        (index < this.data.recoveryTrend.length ? this.data.recoveryTrend[index].count : 0) :
        (index < this.data.trend.length ? this.data.trend[index].count : 0);
      if (!count) { return; }
      // Each window contains consecutive calendar dates. UTC arithmetic avoids a local day shift.
      start = new Date(Date.parse(start) + index * 86400000).toISOString().slice(0, 10);
      end = start;
    }
    const scope: StatisticsScope = { window: { start: start, end: end }, category: category, status: status, dateType: dateType };
    this.stack.pushPath({ name: 'StatisticsItems', param: scope });
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
      Row({ space: 3 }) {
        ForEach([7, 14, 30], (days: number) => {
          SegmentTab({ label: days + '日', selected: this.days === days,
            onSelect: () => this.selectDays(days) }).layoutWeight(1)
        }, (days: number) => days.toString())
      }.width('100%').padding(2).borderRadius(12).backgroundColor(Colors.soft)
      Row({ space: 8 }) {
        Select(CATEGORY_OPTIONS).value(this.category === 'all' ? '全部分类' : this.category)
          .selected(CATEGORIES.indexOf(this.category) + 1).font({ size: 12 }).constraintSize({ minHeight: 42 })
          .layoutWeight(1).backgroundColor(Colors.surface).accessibilityText('统计类别')
          .onSelect((index: number) => {
            const category = index === 0 ? 'all' : CATEGORIES[index - 1];
            if (category !== this.category) { this.category = category; this.selectedDay = 0; this.load(); }
          })
        Button('↻').width(44).constraintSize({ minHeight: 42 }).fontSize(20).fontColor(Colors.green).borderRadius(10)
          .backgroundColor(Colors.surface).accessibilityText('刷新统计').onClick(() => { this.load(); })
      }.width('100%')
    }.width('100%').padding({ left: 16, right: 16 })
  }
  @Builder
  dashboard() {
    Scroll() {
      Column({ space: 10 }) {
        Grid() {
          GridItem() {
            StatisticsMetric({ label: '有效启事', value: this.data.total, onOpen: () => this.openItems('all') })
          }
          GridItem() {
            StatisticsMetric({ label: '已寻回', value: this.data.resolved, onOpen: () => this.openItems('resolved') })
          }
          GridItem() {
            StatisticsMetric({ label: '待寻回', value: this.data.open, onOpen: () => this.openItems('open') })
          }
        }.width('100%').height(65).columnsTemplate('1fr 1fr 1fr').rowsTemplate('1fr')
          .backgroundColor(Colors.glass).borderRadius(14).clip(true)
          .backdropBlur(20).border({ width: 1, color: Colors.glassStroke })
        Column({ space: 4 }) {
          Row({ space: 4 }) {
            SegmentTab({ label: '寻回进度', selected: this.chart === 'overview',
              onSelect: () => { this.chart = 'overview'; } }).layoutWeight(1)
            SegmentTab({ label: '类别分布', selected: this.chart === 'category',
              onSelect: () => { this.chart = 'category'; } }).layoutWeight(1)
          }.width('100%')
          Row({ space: 4 }) {
            SegmentTab({ label: '发布趋势', selected: this.chart === 'trend',
              onSelect: () => { this.chart = 'trend'; this.selectedDay = 0; } }).layoutWeight(1)
            SegmentTab({ label: '寻回趋势', selected: this.chart === 'recovery',
              onSelect: () => { this.chart = 'recovery'; this.selectedDay = 0; } }).layoutWeight(1)
          }.width('100%')
        }.width('100%').backgroundColor(Colors.soft).padding(3).borderRadius(13)
        if (this.chart === 'overview') { RecoveryChart({ data: this.data }) }
        else if (this.chart === 'category') {
          CategoryChart({ points: this.data.categories, showDetails: true,
            onBrowse: (category: string) => this.openItems('all', -1, 'published', category) })
        }
        else if (this.chart === 'trend') {
          TrendChart({ points: this.data.trend, selectedDay: this.selectedDay,
            onSelectDay: (day: number) => { this.selectedDay = day; },
            onBrowseDay: (index: number) => this.openItems('all', index) })
        }
        else {
          TrendChart({ points: this.recoveryPoints(), selectedDay: this.selectedDay, recovery: true,
            undatedResolved: this.data.undatedResolved,
            onSelectDay: (day: number) => { this.selectedDay = day; },
            onBrowseDay: (index: number) => this.openItems('resolved', index, 'resolved') })
        }
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
      Stack() {
        AmbientBackground()
        Column({ space: 8 }) {
        PageHeader({ title: '校园互助统计', subtitle: '启事发布与寻回数据', back: true, onBack: () => { this.stack.pop(); } })
        this.controls()
        Row() {
          Button('拍照找物统计 ›').fontSize(13).constraintSize({ minHeight: 40 })
            .fontColor(Colors.green).backgroundColor(Colors.soft)
            .onClick(() => { this.stack.pushPath({ name: 'PhotoFunnel', param: '' }); })
        }.width('100%').padding({ left: 16, right: 16 }).justifyContent(FlexAlign.End)
        if (this.phase === 'ready' || this.phase === 'empty') {
          Text(this.chart === 'recovery' ?
            this.data.recoveryWindowStart + ' 至 ' + this.data.recoveryWindowEnd + ' · 按实际确认寻回日期' :
            this.data.windowStart + ' 至 ' + this.data.windowEnd + ' · 按发布日期')
            .fontSize(11).fontColor(Colors.muted).width('100%').padding({ left: 16, right: 16 })
        }
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, emptyText: '所选范围暂无有效启事',
            emptyAction: this.anchor === 'today' ? '查看最近有记录的时段' : (this.category === 'all' ? '刷新统计' : '查看全部分类'),
            onRetry: () => this.retry() }).layoutWeight(1)
        } else { this.dashboard() }
        BottomNav({ active: 'Statistics', onNavigate: (route: string) => this.navigate(route) })
        }.width('100%').height('100%')
      }.width('100%').height('100%')
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; }).onShown(() => { this.load(); })
  }
}
