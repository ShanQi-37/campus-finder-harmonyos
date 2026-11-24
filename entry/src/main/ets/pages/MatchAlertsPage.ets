import { AmbientBackground, Colors, FontSize, ItemThumb, PageHeader, Radius, Spacing, StatePanel } from '../components/Common';
import { MatchAlert, MatchSelection } from '../model/Models';
import { Api } from '../service/Api';

@ComponentV2
export struct MatchAlertsPage {
  @Local alerts: MatchAlert[] = [];
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local publishedId: string = '';
  private generation: number = 0;
  private stack: NavPathStack = new NavPathStack();

  async load(): Promise<void> {
    const ticket = ++this.generation;
    this.phase = 'loading';
    try {
      const result = await Api.matchAlerts(this.publishedId);
      if (ticket !== this.generation) { return; }
      this.alerts = result.alerts;
      this.phase = result.alerts.length ? 'ready' : 'empty';
    } catch (error) {
      if (ticket !== this.generation) { return; }
      this.error = (error as Error).message;
      this.phase = 'error';
    }
  }

  compare(alert: MatchAlert): void {
    const selection: MatchSelection = { sourceId: alert.source.id, candidateId: alert.candidate.id, alertId: alert.id };
    this.stack.pushPath({ name: 'MatchCompare', param: selection });
  }

  @Builder
  card(alert: MatchAlert) {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.sm }) {
        Text(alert.candidate.kind === 'lost' ? '发现相似寻物启事' : '发现相似招领启事')
          .fontSize(FontSize.caption).fontWeight(FontWeight.Bold).fontColor(Colors.greenDeep).layoutWeight(1)
        if (alert.unread) {
          Text('未读').fontSize(FontSize.caption).fontColor(Colors.greenDeep)
            .backgroundColor(Colors.soft).padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(Radius.sm)
        }
      }.width('100%')
      Row({ space: Spacing.sm }) {
        ItemThumb({ item: alert.candidate, w: 60, h: 60, radius: 10 })
        Column({ space: 4 }) {
          Text(alert.candidate.title).fontSize(FontSize.title).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(alert.candidate.location + ' · ' + alert.candidate.occurredAt)
            .fontSize(FontSize.caption).fontColor(Colors.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Text((alert.source.kind === 'lost' ? '我的寻物 · ' : '我的招领 · ') + alert.source.title)
        .fontSize(FontSize.caption).fontColor(Colors.muted).width('100%')
      Text(alert.reasons.join(' · ')).fontSize(FontSize.caption).fontColor(Colors.greenDeep).width('100%')
      Button('查看对比').width('100%').constraintSize({ minHeight: 42 })
        .fontSize(FontSize.body).backgroundColor(Colors.greenDeep).borderRadius(Radius.sm).onClick(() => this.compare(alert))
    }.width('100%').padding(Spacing.md).backgroundColor(Colors.surface).borderRadius(Radius.lg)
      .border({ width: 1, color: Colors.stroke })
  }

  build() {
    NavDestination() {
      Stack() {
        AmbientBackground()
        Column({ space: Spacing.sm }) {
          PageHeader({ title: '智能匹配', subtitle: this.publishedId ? '启事已发布' : (this.phase === 'ready' ?
            this.alerts.length + ' 条匹配' : ''), back: true,
            onBack: () => { this.stack.pop(); } })
          if (this.phase === 'ready') {
            List({ space: Spacing.sm }) {
              ForEach(this.alerts, (alert: MatchAlert) => {
                ListItem() { this.card(alert) }
              }, (alert: MatchAlert) => alert.id)
            }.width('100%').layoutWeight(1).padding({ left: Spacing.lg, right: Spacing.lg, bottom: Spacing.lg })
              .scrollBar(BarState.Auto)
          } else {
            StatePanel({ phase: this.phase, error: this.error, emptyText: '暂时没有符合条件的相似启事',
              onRetry: () => { this.load(); } }).layoutWeight(1)
          }
        }.width('100%').height('100%')
      }.width('100%').height('100%')
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
      this.publishedId = (context.pathInfo.param as string) || '';
    }).onShown(() => { this.load(); }).onHidden(() => { this.generation++; })
  }
}
