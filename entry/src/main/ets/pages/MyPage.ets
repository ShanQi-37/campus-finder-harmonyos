import { FeedModel } from '../model/FeedModel';
import { PersonalSummary, emptySummary } from '../model/Models';
import { Session } from '../model/Session';
import { Api } from '../service/Api';
import { ChoiceChip, Colors, PageHeader } from '../components/Common';
import { FeedContent } from '../components/FeedContent';
import { TaskTile } from '../components/TaskTile';
import { BottomNav } from '../components/BottomNav';
@ComponentV2
export struct MyPage {
  @Local model: FeedModel = new FeedModel();
  @Local actor: string = Session.actor;
  @Local tab: string = 'posted';
  @Local summary: PersonalSummary = emptySummary();
  @Local badgeError: boolean = false;
  @Local syncing: boolean = true;
  @Local identities: boolean = false;
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;
  aboutToDisappear(): void { this.model.cancel(); this.generation++; }
  async reload(reset: boolean = true): Promise<void> {
    this.model.owner = this.tab === 'posted' ? Session.actor : ''; this.model.saved = this.tab === 'saved'; this.model.load(reset);
    this.summary = emptySummary(); this.badgeError = false; this.syncing = true;
    const ticket = ++this.generation;
    try { const result = await Api.me(); if (ticket === this.generation) { this.summary = result; this.syncing = false; } }
    catch (error) { if (ticket === this.generation) { this.badgeError = true; this.syncing = false; } }
  }
  switchActor(actor: string): void { Session.actor = actor; this.actor = actor; this.model.status = 'all'; this.reload(); }
  navigate(route: string): void {
    if (route === 'My') { this.reload(); }
    else if (route === 'Home') { this.stack.clear(); }
    else if (route === 'Publish') { this.stack.pushPath({ name: 'Publish', param: '' }); }
    else { this.stack.replacePath({ name: route, param: '' }); }
  }
  build() {
    NavDestination() {
      Column({ space: 10 }) {
        PageHeader({ title: '我的校园', subtitle: '每一次主动，都让重逢更近一步', back: true, onBack: () => { this.stack.clear(); } })
        Row({ space: 12 }) {
          Text(this.actor === 'demo-user' ? '同' : (this.actor === 'peer-01' ? '助' : '愿')).fontSize(23).fontColor('#FFF7E5').width(52).height(52).textAlign(TextAlign.Center).backgroundColor(Colors.green).borderRadius(18)
          Column({ space: 6 }) {
            Text(this.actor === 'demo-user' ? '校园体验同学' : (this.actor === 'peer-01' ? '互助体验同学' : '志愿体验同学')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
            Text(this.syncing ? '正在同步个人记录…' : (this.badgeError ? '任务暂未同步，点击刷新重试' : ('待寻回 ' + this.summary.open + ' · 已寻回 ' + this.summary.resolved))).fontSize(11).fontColor(Colors.muted)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text(this.identities ? '收起' : '身份体验').fontSize(11).fontColor(Colors.green).padding(5).onClick(() => { this.identities = !this.identities; })
        }.padding({ left: 18, right: 18 }).width('100%')
        if (this.identities) {
          Row({ space: 7 }) {
            ChoiceChip({ label: '校园同学', selected: this.actor === 'demo-user', onSelect: () => this.switchActor('demo-user') })
            ChoiceChip({ label: '互助同学', selected: this.actor === 'peer-01', onSelect: () => this.switchActor('peer-01') })
            ChoiceChip({ label: '志愿同学', selected: this.actor === 'peer-02', onSelect: () => this.switchActor('peer-02') })
          }.width('100%').padding({ left: 18, right: 18 })
          Text('三种固定虚构身份，用于体验双方流程。').fontSize(10).fontColor(Colors.muted).width('90%')
        }
        Row({ space: 9 }) {
          TaskTile({ label: '待我核对', value: this.syncing ? '…' : this.summary.incomingPending.toString(), failed: this.badgeError, onOpen: () => { this.stack.pushPath({ name: 'ClaimCenter', param: 'received' }); } }).layoutWeight(1)
          TaskTile({ label: '我的申请', value: this.syncing ? '…' : this.summary.outgoingPending.toString(), failed: this.badgeError, onOpen: () => { this.stack.pushPath({ name: 'ClaimCenter', param: 'sent' }); } }).layoutWeight(1)
          TaskTile({ label: '发布草稿', value: this.syncing ? '…' : (this.summary.draftUpdatedAt.length ? '1' : '0'), failed: this.badgeError, onOpen: () => this.navigate('Publish') }).layoutWeight(1)
        }.width('100%').padding({ left: 18, right: 18 })
        if (!this.syncing && this.summary.draftUpdatedAt.length) {
          Row() { Text('继续填写 · ' + this.summary.draftTitle).fontSize(11).fontColor(Colors.green).maxLines(1).layoutWeight(1); Text('›').fontSize(18).fontColor(Colors.green) }
            .width('90%').padding(10).backgroundColor('#E6EEE4').borderRadius(12).onClick(() => this.navigate('Publish'))
        }
        Row({ space: 8 }) {
          ChoiceChip({ label: '我发布的', selected: this.tab === 'posted', onSelect: () => { this.tab = 'posted'; this.reload(); } })
          ChoiceChip({ label: this.syncing ? '收藏' : ('收藏 ' + this.summary.saved), selected: this.tab === 'saved', onSelect: () => { this.tab = 'saved'; this.model.status = 'all'; this.reload(); } })
          Blank()
          Text('刷新').fontSize(12).fontColor(Colors.green).padding(6).onClick(() => { this.reload(); })
        }.width('100%').padding({ left: 18, right: 18 })
        if (this.tab === 'posted') {
          Row({ space: 6 }) {
            ChoiceChip({ label: '全部', selected: this.model.status === 'all', onSelect: () => { this.model.status = 'all'; this.model.load(); } })
            ChoiceChip({ label: '待寻回', selected: this.model.status === 'open', onSelect: () => { this.model.status = 'open'; this.model.load(); } })
            ChoiceChip({ label: '已寻回', selected: this.model.status === 'resolved', onSelect: () => { this.model.status = 'resolved'; this.model.load(); } })
            ChoiceChip({ label: '已撤回', selected: this.model.status === 'withdrawn', onSelect: () => { this.model.status = 'withdrawn'; this.model.load(); } })
          }.width('100%').padding({ left: 18, right: 18 })
        }
        FeedContent({ model: this.model, filters: false, onOpen: (id: string) => { this.stack.pushPath({ name: 'Detail', param: id }); } }).layoutWeight(1)
        BottomNav({ active: 'My', onNavigate: (route: string) => this.navigate(route) })
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; }).onShown(() => { this.reload(false); })
  }
}
