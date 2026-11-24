import { FeedModel } from '../model/FeedModel';
import { Api } from '../service/Api';
import { Colors, Spacing, AmbientBackground } from '../components/Common';
import { BottomNav } from '../components/BottomNav';
import { FeedContent } from '../components/FeedContent';
import { DetailPage } from './DetailPage';
import { PhotoSearchPage } from './PhotoSearchPage';
import { TextSearchPage } from './TextSearchPage';
import { PhotoFunnelPage } from './PhotoFunnelPage';
import { MatchComparePage } from './MatchComparePage';
import { MatchAlertsPage } from './MatchAlertsPage';
import { PublishPage } from './PublishPage';
import { MyPage } from './MyPage';
import { StatisticsPage } from './StatisticsPage';
import { StatisticsItemsPage } from './StatisticsItemsPage';
import { ClaimFormPage } from './ClaimFormPage';
import { ClaimCenterPage } from './ClaimCenterPage';
import { LoginPage } from './LoginPage';
import { LoginSession, Session } from '../model/Session';
@Entry
@ComponentV2
struct Index {
  @Local model: FeedModel = new FeedModel();
  @Local headline: string = '正在同步统计…';
  @Local signedIn: boolean = Session.token.length > 0;
  @Local loginNote: string = '';
  @Local unreadMatches: number = 0;
  private stack: NavPathStack = new NavPathStack();
  private feedScroller: Scroller = new Scroller();
  private generation: number = 0;
  private refreshing: boolean = false;
  private matchTimer: number = -1;
  private matchRequest: number = 0;
  private matchCountLoaded: boolean = false;
  aboutToAppear(): void { Session.onExpired = () => this.clearSession('登录已失效，请重新登录'); }
  aboutToDisappear(): void {
    this.stopMatchUpdates();
    Session.onExpired = () => {};
    this.model.cancel();
    this.generation++;
  }
  onPageShow(): void {
    if (this.signedIn) {
      this.startMatchUpdates();
      this.refreshMatchCount();
    }
  }
  onPageHide(): void { this.stopMatchUpdates(); }
  startMatchUpdates(): void {
    if (!this.signedIn || this.matchTimer !== -1) { return; }
    this.matchTimer = setInterval(() => { this.refreshMatchCount(); }, 15000);
  }
  stopMatchUpdates(): void {
    if (this.matchTimer !== -1) { clearInterval(this.matchTimer); this.matchTimer = -1; }
    this.matchRequest++;
  }
  async refreshMatchCount(): Promise<void> {
    if (!this.signedIn) { return; }
    const ticket = ++this.matchRequest;
    try {
      const summary = await Api.me();
      if (ticket !== this.matchRequest) { return; }
      const count = summary.unreadMatches ?? 0;
      const notify = this.matchCountLoaded && count > this.unreadMatches;
      this.unreadMatches = count;
      this.matchCountLoaded = true;
      if (notify) {
        this.getUIContext().getPromptAction().showToast({ message: '发现相似启事，可在「我的」中查看智能匹配' });
      }
    } catch { }
  }
  signIn(session: LoginSession): void {
    Session.start(session);
    this.headline = '正在同步统计…';
    this.loginNote = '';
    this.signedIn = true;
    this.startMatchUpdates();
    this.refresh();
  }
  signOut(): void {
    Api.logout().catch(() => {});
    this.clearSession();
  }
  clearSession(note: string = ''): void {
    this.signedIn = false;
    this.stopMatchUpdates();
    this.unreadMatches = 0;
    this.refreshing = false;
    this.matchCountLoaded = false;
    this.loginNote = note;
    Session.clear();
    this.model.cancel();
    this.generation++;
    this.stack.clear();
    this.model = new FeedModel();
  }
  async refresh(): Promise<void> {
    if (!this.signedIn || this.refreshing) { return; }
    const token = Session.token;
    this.refreshing = true;
    try {
      await this.model.load(false);
      if (token !== Session.token) { return; }
      await this.refreshHeadline();
      if (token === Session.token) { await this.refreshMatchCount(); }
    } finally {
      if (token === Session.token) { this.refreshing = false; }
    }
  }
  async refreshHeadline(): Promise<void> {
    const ticket = ++this.generation;
    try { const stats = await Api.statistics(30); if (ticket === this.generation) { this.headline = '近 30 日 ' + stats.total + ' 条启事 · ' + stats.resolved + ' 条已寻回'; } }
    catch (error) { if (ticket === this.generation) { this.headline = '近期统计暂不可用'; } }
  }
  open(name: string, param: string = ''): void { this.stack.pushPath({ name: name, param: param }); }
  @Builder
  destination(name: string) {
    if (name === 'Detail') { DetailPage() }
    else if (name === 'PhotoSearch') { PhotoSearchPage() }
    else if (name === 'TextSearch') { TextSearchPage() }
    else if (name === 'PhotoFunnel') { PhotoFunnelPage() }
    else if (name === 'MatchCompare') { MatchComparePage() }
    else if (name === 'MatchAlerts') { MatchAlertsPage() }
    else if (name === 'Publish') { PublishPage() }
    else if (name === 'My') { MyPage({ onSignOut: () => this.signOut() }) }
    else if (name === 'Statistics') { StatisticsPage() }
    else if (name === 'StatisticsItems') { StatisticsItemsPage() }
    else if (name === 'ClaimForm') { ClaimFormPage() }
    else if (name === 'ClaimCenter') { ClaimCenterPage() }
  }
  @Builder
  plazaHeader() {
    Row({ space: Spacing.sm }) {
      Image($r('app.media.app_icon')).width(36).height(36).accessibilityLevel('no')
      Column({ space: 1 }) {
        Text('拾光校园').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
        Text('失物广场').fontSize(12).fontColor(Colors.muted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Stack({ alignContent: Alignment.TopEnd }) {
        Image($r('app.media.icon_match')).width(22).height(22).align(Alignment.Center)
          .margin({ top: 11, right: 11 }).accessibilityLevel('no')
        if (this.unreadMatches > 0) {
          Text(this.unreadMatches > 99 ? '99+' : this.unreadMatches.toString()).fontSize(10)
            .fontWeight(FontWeight.Bold).fontColor('#FFFFFF').backgroundColor(Colors.greenDeep)
            .constraintSize({ minWidth: 15, minHeight: 15 }).textAlign(TextAlign.Center)
            .padding({ left: 3, right: 3 }).borderRadius(9).margin({ top: 2, right: 2 })
        }
      }.width(44).height(44).borderRadius(12).backgroundColor('#EFF6F1')
        .accessibilityText(this.unreadMatches > 0 ? '智能匹配 · ' + this.unreadMatches + ' 条新提醒' : '智能匹配')
        .onClick(() => this.open('MatchAlerts'))
    }.width('100%').padding({ left: Spacing.lg, right: Spacing.lg, top: 10, bottom: 3 })
  }

  @Builder
  home() {
    Navigation(this.stack) {
      Stack() {
        AmbientBackground({ prominent: true })
        Column({ space: Spacing.sm }) {
          this.plazaHeader()
          Scroll(this.feedScroller) {
            Column({ space: Spacing.sm }) {
              FeedContent({ model: this.model, pageScroller: this.feedScroller, searchHeadline: this.headline,
                onOpenSearch: (route: string) => this.open(route),
                onOpen: (id: string) => this.open('Detail', id),
                onRefresh: () => { this.refreshHeadline().then(() => this.refreshMatchCount()); } })
            }.width('100%')
          }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top)
          BottomNav({ active: 'Home', onNavigate: (route: string) => { if (route === 'Home') { this.refresh(); } else { this.open(route); } } })
        }.width('100%').height('100%')
      }.width('100%').height('100%')
    }.hideTitleBar(true).navDestination(this.destination).mode(NavigationMode.Stack)
      .onNavBarStateChange((visible: boolean) => { if (visible) { this.refresh(); } })
  }
  build() {
    if (this.signedIn) { this.home() }
    else { LoginPage({ note: this.loginNote, onLogin: (session: LoginSession) => this.signIn(session) }) }
  }
}
