import { FeedModel } from '../model/FeedModel';
import { Api } from '../service/Api';
import { Colors, PageHeader } from '../components/Common';
import { BottomNav } from '../components/BottomNav';
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
  build() {
    Navigation(this.stack) {
      Column({ space: 9 }) {
        PageHeader({ title: '拾光校园', subtitle: 'CAMPUS FINDER  /  每一条线索都值得被看见' })
        Row() {
          Column({ space: 7 }) {
            Text('让遗失，遇见归途').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#FFFCED').lineHeight(28)
            Text('寻物 · 招领 · 核对交接').fontSize(11).fontColor('#E5D7AF')
            Text(this.headline).fontSize(11).fontColor('#C6DDC7')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Image($r('app.media.campus_hero')).width(95).height(94).objectFit(ImageFit.Contain)
        }.width('90%').height(102).padding({ left: 18, right: 5 }).backgroundColor('#175D50').borderRadius(20)
        FeedContent({ model: this.model, onOpen: (id: string) => this.open('Detail', id) }).layoutWeight(1)
        BottomNav({ active: 'Home', onNavigate: (route: string) => { if (route === 'Home') { this.refresh(); } else { this.open(route); } } })
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).navDestination(this.destination).mode(NavigationMode.Stack)
      .onNavBarStateChange((visible: boolean) => { if (visible) { this.refresh(); } })
  }
}
