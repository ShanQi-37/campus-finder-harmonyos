import { FeedModel } from '../model/FeedModel';
import { Api } from '../service/Api';
import { Colors, PageHeader } from '../components/Common';
import { BottomNav } from '../components/BottomNav';
import { FeedContent } from '../components/FeedContent';
import { DetailPage } from './DetailPage';
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
      Column({ space: 8 }) {
        PageHeader({ title: '拾光校园', subtitle: '校园失物招领' })
        Column() {
          Row() {
            Column({ space: 5 }) {
              Text('失物广场').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              Text(this.headline).fontSize(12).fontColor('#D9EDE2').maxLines(2)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Image($r('app.media.campus_hero')).width(86).height(70).objectFit(ImageFit.Contain).accessibilityLevel('no')
          }.width('100%').height(80).padding({ left: 15, right: 8 }).backgroundColor('#134E45').borderRadius(16)
        }.width('100%').padding({ left: 16, right: 16 })
        FeedContent({ model: this.model, onOpen: (id: string) => this.open('Detail', id), onRefresh: () => { this.refreshHeadline(); } }).layoutWeight(1)
        BottomNav({ active: 'Home', onNavigate: (route: string) => { if (route === 'Home') { this.refresh(); } else { this.open(route); } } })
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).navDestination(this.destination).mode(NavigationMode.Stack)
      .onNavBarStateChange((visible: boolean) => { if (visible) { this.refresh(); } })
  }
}
