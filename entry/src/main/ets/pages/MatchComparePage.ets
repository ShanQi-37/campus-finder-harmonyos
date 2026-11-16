import { Colors, NoticeStatus, PageHeader, StatePanel, categoryArt } from '../components/Common';
import { Item, MatchSelection, emptyItem } from '../model/Models';
import { Session } from '../model/Session';
import { Api } from '../service/Api';

@ComponentV2
export struct MatchComparePage {
  @Local source: Item = emptyItem();
  @Local candidate: Item = emptyItem();
  @Local reasons: string[] = [];
  @Local phase: string = 'loading';
  @Local error: string = '';
  private selection: MatchSelection = { sourceId: '', candidateId: '' };
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;

  async load(): Promise<void> {
    const ticket = ++this.generation;
    this.phase = 'loading';
    this.error = '';
    try {
      const result = await Promise.all([
        Api.detail(this.selection.sourceId), Api.matches(this.selection.sourceId)
      ]);
      if (ticket !== this.generation) { return; }
      const lead = result[1].matches.find((entry) => entry.item.id === this.selection.candidateId);
      if (!lead) {
        this.phase = 'empty';
        return;
      }
      this.source = result[0];
      this.candidate = lead.item;
      this.reasons = lead.reasons;
      this.phase = 'ready';
    } catch (error) {
      if (ticket !== this.generation) { return; }
      this.error = (error as Error).message;
      this.phase = 'error';
    }
  }

  @Builder
  itemHeading(item: Item, label: string) {
    Column({ space: 6 }) {
      Text(label + ' · ' + (item.kind === 'found' ? '招领' : '寻物')).fontSize(12)
        .fontColor(Colors.muted).width('100%')
      Image(categoryArt(item.category)).width(44).height(44).objectFit(ImageFit.Contain)
        .backgroundColor(item.kind === 'found' ? '#EAF2E6' : '#FBF0D9').borderRadius(10).accessibilityLevel('no')
      Text(item.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
      NoticeStatus({ status: item.status })
    }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding(10)
      .backgroundColor(Colors.surface).borderRadius(12)
  }

  @Builder
  field(label: string, original: string, candidate: string) {
    Column({ space: 7 }) {
      Text(label).fontSize(12).fontWeight(FontWeight.Medium).fontColor(Colors.muted).width('100%')
      Row({ space: 12 }) {
        Text(original).fontSize(14).fontColor(Colors.ink).layoutWeight(1)
        Text(candidate).fontSize(14).fontColor(Colors.ink).layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Top)
    }.width('100%')
  }

  @Builder
  actions() {
    Row({ space: 10 }) {
      Button('查看候选启事').height(46).fontSize(14).fontColor(Colors.green)
        .backgroundColor(Colors.soft).layoutWeight(1)
        .onClick(() => this.stack.pushPath({ name: 'Detail', param: this.candidate.id }))
      if (this.candidate.owner !== Session.actor) {
        Button(this.candidate.myPending ? '查看申请进度' : (this.candidate.kind === 'found' ? '申请认领' : '提供线索'))
          .height(46).fontSize(14).backgroundColor(Colors.green).layoutWeight(1)
          .onClick(() => {
            if (this.candidate.myPending) {
              this.stack.pushPath({ name: 'ClaimCenter', param: 'sent' });
            } else {
              this.stack.pushPath({ name: 'ClaimForm', param: this.candidate.id });
            }
          })
      }
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 12 })
      .backgroundColor(Colors.surface).border({ width: { top: 1 }, color: Colors.stroke })
  }

  build() {
    NavDestination() {
      Column({ space: 10 }) {
        PageHeader({ title: '相似线索对比', back: true, onBack: () => { this.stack.pop(); } })
        if (this.phase === 'ready') {
          Scroll() {
            Column({ space: 12 }) {
              Row({ space: 10 }) {
                this.itemHeading(this.source, '原启事')
                this.itemHeading(this.candidate, '候选启事')
              }.width('100%').alignItems(VerticalAlign.Top)
              Column({ space: 11 }) {
                this.field('类别', this.source.category, this.candidate.category)
                Divider().color(Colors.stroke)
                this.field('地点', this.source.location, this.candidate.location)
                Divider().color(Colors.stroke)
                this.field('发生日期', this.source.occurredAt, this.candidate.occurredAt)
              }.width('100%').padding(12).backgroundColor(Colors.surface).borderRadius(14)
              Column({ space: 6 }) {
                Text('匹配理由').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Colors.green).width('100%')
                Text(this.reasons.join(' · ')).fontSize(13).fontColor(Colors.ink).width('100%')
                Text('请核对物品特征后再提交申请。').fontSize(12).fontColor(Colors.muted).width('100%')
              }.width('100%').padding(12).backgroundColor(Colors.soft).borderRadius(14)
              Column({ space: 7 }) {
                Text('物品描述').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
                this.field('原启事 / 候选启事', this.source.description, this.candidate.description)
              }.width('100%').padding(12).backgroundColor(Colors.surface).borderRadius(14)
            }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
          }.layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top)
          this.actions()
        } else {
          StatePanel({ phase: this.phase, error: this.error, emptyText: '这条线索已不在匹配列表中',
            onRetry: () => { this.load(); } }).layoutWeight(1)
        }
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
      this.selection = context.pathInfo.param as MatchSelection;
    }).onShown(() => { this.load(); }).onHidden(() => { this.generation++; })
  }
}
