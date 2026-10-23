import { Statistics, emptyStatistics } from '../model/Models';
import { Api } from '../service/Api';
import { ChoiceChip, Colors, PageHeader, StatePanel } from '../components/Common';
import { CategoryChart, RecoveryChart, TrendChart } from '../components/Charts';
@ComponentV2
export struct StatisticsPage {
  @Local data: Statistics = emptyStatistics();
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local chart: string = 'overview';
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;
  async load(): Promise<void> {
    const ticket = ++this.generation;
    this.phase = 'loading';
    try {
      const data = await Api.statistics();
      if (ticket !== this.generation) { return; }
      this.data = data; this.phase = data.total ? 'ready' : 'empty';
    } catch (error) {
      if (ticket !== this.generation) { return; }
      this.error = (error as Error).message; this.phase = 'error';
    }
  }
  aboutToDisappear(): void { this.generation++; }
  @Builder
  metric(label: string, value: number) {
    Column({ space: 8 }) {
      Text(value.toString()).fontSize(29).fontWeight(FontWeight.Bold).fontColor(Colors.green)
      Text(label).fontSize(11).fontColor(Colors.muted)
    }.width('100%').height(88).justifyContent(FlexAlign.Center).backgroundColor('#E6EDDE').borderRadius(16)
  }
  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '校园互助统计', subtitle: '每一条线索，都值得被看见', back: true, onBack: () => { this.stack.pop(); } })
        Row() {
          Text(this.phase === 'ready' ? '更新于 ' + new Date(this.data.updatedAt).toLocaleTimeString() : '正在同步校园互助记录').fontSize(11).fontColor(Colors.muted)
          Blank()
          Button('刷新数据').fontSize(12).height(34).backgroundColor(Colors.green).enabled(this.phase !== 'loading').onClick(() => { this.load(); })
        }.padding({ left: 20, right: 20, bottom: 15 }).width('100%')
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, emptyText: '还没有可统计的互助记录', onRetry: () => { this.load(); } })
        } else {
          Row({ space: 10 }) {
            ChoiceChip({ label: '寻回概览', selected: this.chart === 'overview', onSelect: () => { this.chart = 'overview'; } })
            ChoiceChip({ label: '类别分布', selected: this.chart === 'category', onSelect: () => { this.chart = 'category'; } })
            ChoiceChip({ label: '七日趋势', selected: this.chart === 'trend', onSelect: () => { this.chart = 'trend'; } })
          }.width('100%').padding({ left: 20, right: 20, bottom: 15 })
          Scroll() {
            Column({ space: 16 }) {
              Grid() {
                GridItem() { this.metric('全部信息', this.data.total) }
                GridItem() { this.metric('待寻回', this.data.open) }
                GridItem() { this.metric('已寻回', this.data.resolved) }
              }.columnsTemplate('1fr 1fr 1fr').columnsGap(10).height(88).width('100%')
              if (this.chart === 'overview') { RecoveryChart({ data: this.data }) }
              else if (this.chart === 'category') { CategoryChart({ points: this.data.categories }) }
              else { TrendChart({ points: this.data.trend }) }
              Text('统计来自当前校园演示记录，发布和寻回后会重新计算。').fontSize(11).fontColor(Colors.muted).lineHeight(19)
            }.width('100%').padding({ left: 20, right: 20, bottom: 30 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        }
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; }).onShown(() => { this.load(); })
  }
}
