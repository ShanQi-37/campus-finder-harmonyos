import { FeedModel } from '../model/FeedModel';
import { Session } from '../model/Session';
import { Api } from '../service/Api';
import { ChoiceChip, Colors, PageHeader } from '../components/Common';
import { FeedContent } from '../components/FeedContent';
@ComponentV2
export struct MyPage {
  @Local model: FeedModel = new FeedModel();
  @Local actor: string = Session.actor;
  @Local tab: string = 'posted';
  @Local pending: number = 0;
  @Local badgeError: boolean = false;
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;
  aboutToDisappear(): void { this.model.cancel(); this.generation++; }
  async reload(): Promise<void> {
    this.model.owner = this.tab === 'posted' ? Session.actor : ''; this.model.saved = this.tab === 'saved'; this.model.load();
    const ticket = ++this.generation;
    try { const result = await Api.claims('received'); if (ticket === this.generation) { this.pending = result.pending; this.badgeError = false; } }
    catch (error) { if (ticket === this.generation) { this.badgeError = true; } }
  }
  switchActor(actor: string): void { Session.actor = actor; this.actor = actor; this.reload(); }
  build() {
    NavDestination() {
      Column({ space: 12 }) {
        PageHeader({ title: '我的校园', subtitle: '收藏线索，记录每一次重逢', back: true, onBack: () => { this.stack.pop({ changed: true }); } })
        Row({ space: 12 }) {
          Text(this.actor === 'demo-user' ? '同' : (this.actor === 'peer-01' ? '助' : '愿')).fontSize(24).fontColor('#FFFCED').width(58).height(58).textAlign(TextAlign.Center).backgroundColor(Colors.green).borderRadius(20)
          Column({ space: 6 }) {
            Text(Session.displayName()).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
            Text('固定虚构身份 · 可切换体验双角色流程').fontSize(10).fontColor(Colors.muted)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.padding({ left: 18, right: 18 }).width('100%')
        Row({ space: 7 }) {
          ChoiceChip({ label: '校园同学', selected: this.actor === 'demo-user', onSelect: () => this.switchActor('demo-user') })
          ChoiceChip({ label: '互助同学', selected: this.actor === 'peer-01', onSelect: () => this.switchActor('peer-01') })
          ChoiceChip({ label: '志愿同学', selected: this.actor === 'peer-02', onSelect: () => this.switchActor('peer-02') })
        }.width('100%').padding({ left: 18, right: 18 })
        Row() {
          Column({ space: 5 }) {
            Text('认领与线索中心').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.green)
            Text(this.badgeError ? '统计暂不可用，点此打开并重试' : (this.pending + ' 条待核对 · 查看收到和发出的申请')).fontSize(10).fontColor(Colors.muted)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text('›').fontSize(25).fontColor(Colors.green)
        }.width('90%').padding(15).backgroundColor('#E5EEE2').borderRadius(17).onClick(() => { this.stack.pushPath({ name: 'ClaimCenter', param: 'received' }); })
        Row({ space: 10 }) {
          ChoiceChip({ label: '我发布的', selected: this.tab === 'posted', onSelect: () => { this.tab = 'posted'; this.reload(); } })
          ChoiceChip({ label: '我收藏的', selected: this.tab === 'saved', onSelect: () => { this.tab = 'saved'; this.reload(); } })
          Blank()
          Text('刷新').fontSize(11).fontColor(Colors.green).padding(6).onClick(() => { this.reload(); })
        }.width('100%').padding({ left: 18, right: 18 })
        FeedContent({ model: this.model, filters: false, onOpen: (id: string) => { this.stack.pushPath({ name: 'Detail', param: id }); } }).layoutWeight(1)
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; }).onShown(() => { this.reload(); })
  }
}
