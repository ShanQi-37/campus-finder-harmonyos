import { FeedModel } from '../model/FeedModel';
import { Api } from '../service/Api';
import { Colors, FontSize, Radius, Shadow, Spacing, PageHeader, AmbientBackground } from '../components/Common';
import { BottomNav } from '../components/BottomNav';
import { FeedContent } from '../components/FeedContent';
import { DetailPage } from './DetailPage';
import { PhotoSearchPage } from './PhotoSearchPage';
import { TextSearchPage } from './TextSearchPage';
import { PhotoFunnelPage } from './PhotoFunnelPage';
import { MatchComparePage } from './MatchComparePage';
import { PublishPage } from './PublishPage';
import { MyPage } from './MyPage';
import { StatisticsPage } from './StatisticsPage';
import { StatisticsItemsPage } from './StatisticsItemsPage';
import { ClaimFormPage } from './ClaimFormPage';
import { ClaimCenterPage } from './ClaimCenterPage';
@Entry
@ComponentV2
struct Index {
  @Local model: FeedModel = new FeedModel();
  @Local headline: string = '正在同步统计…';
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;
  aboutToDisappear(): void { this.model.cancel(); this.generation++; }
  async refresh(): Promise<void> {
    this.model.load(false);
    await this.refreshHeadline();
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
    else if (name === 'Publish') { PublishPage() }
    else if (name === 'My') { MyPage() }
    else if (name === 'Statistics') { StatisticsPage() }
    else if (name === 'StatisticsItems') { StatisticsItemsPage() }
    else if (name === 'ClaimForm') { ClaimFormPage() }
    else if (name === 'ClaimCenter') { ClaimCenterPage() }
  }
  build() {
    Navigation(this.stack) {
      Stack() {
        AmbientBackground()
        Column({ space: Spacing.sm }) {
          PageHeader({ title: '拾光校园', subtitle: '校园失物招领' })
          Column() {
            Stack({ alignContent: Alignment.Center }) {
              Row() {
                Column({ space: 5 }) {
                  Text('失物广场').fontSize(FontSize.heading).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                  Text(this.headline).fontSize(FontSize.caption).fontColor('#D9F2E8').maxLines(2)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Image($r('app.media.campus_hero')).width(86).height(70).objectFit(ImageFit.Contain).accessibilityLevel('no')
              }.width('100%').height(84).padding({ left: Spacing.lg, right: Spacing.sm })
              // 装饰柔光：与背景光斑呼应，让 hero 不再单调
              Circle().width(120).height(120).fill('#1FFFFFFF').blur(18)
                .position({ x: -30, y: -18 }).accessibilityLevel('no')
              Circle().width(90).height(90).fill('#14FFFFFF').blur(14)
                .position({ x: 150, y: 38 }).accessibilityLevel('no')
            }.width('100%').borderRadius(Radius.lg)
            .linearGradient({ angle: 135, colors: [[Colors.heroStart, 0.0], [Colors.heroEnd, 1.0]] })
            .shadow({ radius: 12, color: Shadow.md, offsetX: 0, offsetY: 4 }).clip(true)
          }.width('100%').padding({ left: Spacing.lg, right: Spacing.lg })
          Row({ space: Spacing.sm }) {
            Button('描述找物 ›').fontSize(FontSize.caption).constraintSize({ minHeight: 40 }).fontColor(Colors.greenDeep)
              .backgroundColor(Colors.soft).borderRadius(Radius.sm).onClick(() => this.open('TextSearch'))
            Button('拍照找物 ›').fontSize(FontSize.caption).constraintSize({ minHeight: 40 }).fontColor(Colors.greenDeep)
              .backgroundColor(Colors.soft).borderRadius(Radius.sm).onClick(() => this.open('PhotoSearch'))
          }.width('100%').padding({ left: Spacing.lg, right: Spacing.lg }).justifyContent(FlexAlign.End)
          FeedContent({ model: this.model, onOpen: (id: string) => this.open('Detail', id), onRefresh: () => { this.refreshHeadline(); } }).layoutWeight(1)
          BottomNav({ active: 'Home', onNavigate: (route: string) => { if (route === 'Home') { this.refresh(); } else { this.open(route); } } })
        }.width('100%').height('100%')
      }.width('100%').height('100%')
    }.hideTitleBar(true).navDestination(this.destination).mode(NavigationMode.Stack)
      .onNavBarStateChange((visible: boolean) => { if (visible) { this.refresh(); } })
  }
}
