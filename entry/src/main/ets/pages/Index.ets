import { FeedModel } from '../model/FeedModel';
import { Api } from '../service/Api';
import { Colors, PageHeader } from '../components/Common';
import { FeedContent } from '../components/FeedContent';
import { DetailPage } from './DetailPage';
import { PublishPage } from './PublishPage';
import { MyPage } from './MyPage';
import { StatisticsPage } from './StatisticsPage';
import { ClaimFormPage } from './ClaimFormPage';
import { ClaimCenterPage } from './ClaimCenterPage';
@Entry
@ComponentV2
struct Index {
  @Local model: FeedModel = new FeedModel();
  @Local headline: string = '校园线索，正在连接';
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;
  aboutToDisappear(): void { this.model.cancel(); this.generation++; }
  async refresh(): Promise<void> {
    this.model.load(false);
    const ticket = ++this.generation;
    try { const stats = await Api.statistics(30); if (ticket === this.generation) { this.headline = '近30日 ' + stats.total + ' 条线索 · ' + stats.resolved + ' 份重逢'; } }
    catch (error) { if (ticket === this.generation) { this.headline = '每一份善意，都值得被看见'; } }
  }
  open(name: string, param: string = ''): void { this.stack.pushPath({ name: name, param: param }); }
  @Builder
  destination(name: string) {
    if (name === 'Detail') { DetailPage() }
    else if (name === 'Publish') { PublishPage() }
    else if (name === 'My') { MyPage() }
    else if (name === 'Statistics') { StatisticsPage() }
    else if (name === 'ClaimForm') { ClaimFormPage() }
    else if (name === 'ClaimCenter') { ClaimCenterPage() }
  }
  @Builder
  nav(label: string, symbol: string, route: string) {
    Column({ space: 3 }) {
      Text(symbol).fontSize(21).fontWeight(FontWeight.Bold).fontColor(route.length ? '#7F948A' : Colors.green)
      Text(label).fontSize(10).fontWeight(route.length ? FontWeight.Normal : FontWeight.Bold).fontColor(route.length ? '#7F948A' : Colors.green)
    }.layoutWeight(1).height(52).justifyContent(FlexAlign.Center).onClick(() => { if (route.length) { this.open(route); } else { this.model.reset(); this.refresh(); } })
  }
  build() {
    Navigation(this.stack) {
      Column({ space: 10 }) {
        PageHeader({ title: '拾光校园', subtitle: 'CAMPUS FINDER  /  让善意有迹可循' })
        Row() {
          Column({ space: 7 }) {
            Text('遗失有回应\n善意有回响').fontSize(23).fontWeight(FontWeight.Bold).fontColor('#FFFCED').lineHeight(29)
            Text(this.headline).fontSize(10).fontColor('#C6DDC7')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Image($r('app.media.campus_hero')).width(116).height(108).objectFit(ImageFit.Contain)
        }.width('90%').height(118).padding({ left: 18, right: 5 }).backgroundColor('#175D50').borderRadius(22)
        FeedContent({ model: this.model, onOpen: (id: string) => this.open('Detail', id) }).layoutWeight(1)
        Row() {
          this.nav('失物广场', '⌂', '')
          this.nav('互助统计', '▥', 'Statistics')
          this.nav('发布启事', '＋', 'Publish')
          this.nav('我的', '○', 'My')
        }.width('100%').padding({ left: 10, right: 10, top: 4, bottom: 8 }).backgroundColor('#FFFFFF').border({ width: { top: 1 }, color: '#E4EBE3' })
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).navDestination(this.destination).mode(NavigationMode.Stack)
      .onNavBarStateChange((visible: boolean) => { if (visible) { this.refresh(); } })
  }
}
