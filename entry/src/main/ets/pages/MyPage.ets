import { FeedModel } from '../model/FeedModel';
import { PersonalSummary, emptySummary } from '../model/Models';
import { Session } from '../model/Session';
import { Api } from '../service/Api';
import { Colors, PageHeader, SegmentTab } from '../components/Common';
import { FeedContent } from '../components/FeedContent';
import { TaskTile } from '../components/TaskTile';
import { BottomNav } from '../components/BottomNav';
@ComponentV2
export struct MyPage {
  @Local model: FeedModel = new FeedModel();
  @Local actor: string = Session.actor;
  @Local tab: string = 'posted';
  @Local postedStatus: string = 'all';
  @Local summary: PersonalSummary = emptySummary();
  @Local badgeError: boolean = false;
  @Local syncing: boolean = true;
  @Local identities: boolean = false;
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;
  aboutToDisappear(): void { this.model.cancel(); this.generation++; }
  loadRecords(reset: boolean = true): void {
    this.model.owner = this.tab === 'posted' ? Session.actor : '';
    this.model.saved = this.tab === 'saved';
    this.model.status = this.tab === 'posted' ? this.postedStatus : 'all';
    this.model.load(reset);
  }
  async reload(reset: boolean = true): Promise<void> {
    this.loadRecords(reset);
    this.summary = emptySummary(); this.badgeError = false; this.syncing = true;
    const ticket = ++this.generation;
    try { const result = await Api.me(); if (ticket === this.generation) { this.summary = result; this.syncing = false; } }
    catch (error) { if (ticket === this.generation) { this.badgeError = true; this.syncing = false; } }
  }
  switchActor(actor: string): void {
    if (this.actor !== actor) {
      Session.actor = actor;
      this.actor = actor;
      this.postedStatus = 'all';
      this.reload();
    }
    this.identities = false;
  }
  selectTab(tab: string): void {
    if (this.tab === tab) { return; }
    this.tab = tab;
    this.loadRecords();
  }
  selectStatus(status: string): void {
    if (this.postedStatus === status) { return; }
    this.postedStatus = status;
    this.loadRecords();
  }
  navigate(route: string): void {
    if (route === 'My') { this.reload(); }
    else if (route === 'Home') { this.stack.clear(); }
    else if (route === 'Publish') { this.stack.pushPath({ name: 'Publish', param: '' }); }
    else { this.stack.replacePath({ name: route, param: '' }); }
  }
  @Builder
  profile() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text(this.actor === 'demo-user' ? '同' : (this.actor === 'peer-01' ? '助' : '愿'))
          .fontSize(21).fontWeight(FontWeight.Bold).fontColor(Colors.green).width(43).height(43)
          .textAlign(TextAlign.Center).backgroundColor(Colors.soft).borderRadius(13).accessibilityLevel('no')
        Column({ space: 4 }) {
          Text(this.actor === 'demo-user' ? '校园体验同学' : (this.actor === 'peer-01' ? '互助体验同学' : '志愿体验同学'))
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(1)
          Text(this.syncing ? '正在同步个人记录…' : (this.badgeError ? '个人数据暂不可用' :
            ('待寻回 ' + this.summary.open + ' · 已寻回 ' + this.summary.resolved)))
            .fontSize(11).fontColor(Colors.muted).maxLines(1)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button(this.identities ? '收起' : '切换身份').height(36).fontSize(12).fontColor(Colors.green)
          .backgroundColor(Colors.paper).accessibilitySelected(this.identities)
          .onClick(() => { this.identities = !this.identities; })
      }.width('100%')
      if (this.identities) {
        Row({ space: 4 }) {
          SegmentTab({ label: '校园同学', selected: this.actor === 'demo-user',
            onSelect: () => this.switchActor('demo-user') }).layoutWeight(1)
          SegmentTab({ label: '互助同学', selected: this.actor === 'peer-01',
            onSelect: () => this.switchActor('peer-01') }).layoutWeight(1)
          SegmentTab({ label: '志愿同学', selected: this.actor === 'peer-02',
            onSelect: () => this.switchActor('peer-02') }).layoutWeight(1)
        }.width('100%').padding(3).borderRadius(11).backgroundColor(Colors.soft)
        Text('选择虚构身份体验认领和交接。').fontSize(11).fontColor(Colors.muted).width('100%')
      }
    }.width('100%').padding(11).backgroundColor(Colors.surface).borderRadius(15)
      .border({ width: 1, color: Colors.stroke })
  }

  @Builder
  tasks() {
    Row({ space: 7 }) {
      TaskTile({ label: '待我核对', value: this.syncing ? '…' : this.summary.incomingPending.toString(),
        failed: this.badgeError, onOpen: () => this.stack.pushPath({ name: 'ClaimCenter', param: 'received' }) }).layoutWeight(1)
      TaskTile({ label: '我的申请', value: this.syncing ? '…' : this.summary.outgoingPending.toString(),
        failed: this.badgeError, onOpen: () => this.stack.pushPath({ name: 'ClaimCenter', param: 'sent' }) }).layoutWeight(1)
    }.width('100%')
  }

  @Builder
  draftCard() {
    Row({ space: 9 }) {
      Column({ space: 3 }) {
        Text('发布草稿').fontSize(12).fontColor(Colors.green).fontWeight(FontWeight.Medium)
        Text(this.syncing || this.badgeError ? '打开编辑器查看草稿' : (this.summary.draftUpdatedAt.length ?
          (this.summary.draftTitle || '未命名启事') : '暂无草稿'))
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button(this.syncing || this.badgeError ? '打开' : (this.summary.draftUpdatedAt.length ? '继续填写' : '新建启事'))
        .height(38).fontSize(12).fontColor(Colors.green).backgroundColor(Colors.surface)
        .onClick(() => this.navigate('Publish'))
    }.width('100%').padding(10).backgroundColor(Colors.soft).borderRadius(14)
  }

  @Builder
  recordControls() {
    Row({ space: 6 }) {
      Row({ space: 3 }) {
        SegmentTab({ label: '我发布的', selected: this.tab === 'posted',
          onSelect: () => this.selectTab('posted') }).layoutWeight(1)
        SegmentTab({ label: this.syncing || this.badgeError ? '收藏' : '收藏 ' + this.summary.saved,
          selected: this.tab === 'saved', onSelect: () => this.selectTab('saved') }).layoutWeight(1)
      }.layoutWeight(1).padding(3).borderRadius(12).backgroundColor(Colors.soft)
      Button('刷新').height(42).fontSize(12).fontColor(Colors.green).backgroundColor(Colors.surface)
        .onClick(() => { this.reload(false); })
    }.width('100%')
    if (this.tab === 'posted') {
      Row({ space: 4 }) {
        SegmentTab({ label: '全部', selected: this.postedStatus === 'all',
          onSelect: () => this.selectStatus('all') }).layoutWeight(1)
        SegmentTab({ label: '待寻回', selected: this.postedStatus === 'open',
          onSelect: () => this.selectStatus('open') }).layoutWeight(1)
        SegmentTab({ label: '已寻回', selected: this.postedStatus === 'resolved',
          onSelect: () => this.selectStatus('resolved') }).layoutWeight(1)
        SegmentTab({ label: '已撤回', selected: this.postedStatus === 'withdrawn',
          onSelect: () => this.selectStatus('withdrawn') }).layoutWeight(1)
      }.width('100%').padding(2).borderRadius(12).backgroundColor(Colors.soft)
    }
  }

  build() {
    NavDestination() {
      Column({ space: 8 }) {
        PageHeader({ title: '我的校园', back: true, onBack: () => { this.stack.clear(); } })
        Column({ space: 8 }) {
          this.profile()
          this.tasks()
          this.draftCard()
          this.recordControls()
        }.width('100%').padding({ left: 16, right: 16 })
        FeedContent({ model: this.model, filters: false,
          onOpen: (id: string) => { this.stack.pushPath({ name: 'Detail', param: id }); } }).layoutWeight(1)
        BottomNav({ active: 'My', onNavigate: (route: string) => this.navigate(route) })
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; })
      .onShown(() => { this.reload(false); })
  }
}
