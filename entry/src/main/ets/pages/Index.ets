import { FeedModel } from '../model/FeedModel';
import { Colors, PageHeader } from '../components/Common';
import { FeedContent } from '../components/FeedContent';
import { DetailPage } from './DetailPage';
import { PublishPage } from './PublishPage';
import { MyPage } from './MyPage';
import { StatisticsPage } from './StatisticsPage';
interface ReturnResult { changed?: boolean; published?: boolean; }
@Entry
@ComponentV2
struct Index {
  @Local model: FeedModel = new FeedModel();
  @Local notice: string = '';
  private stack: NavPathStack = new NavPathStack();
  private noticeTimer: number = -1;
  aboutToAppear(): void { this.model.load(); }
  aboutToDisappear(): void { this.model.cancel(); if (this.noticeTimer >= 0) { clearTimeout(this.noticeTimer); } }
  open(name: string, param: string = ''): void {
    this.stack.pushPath({ name: name, param: param, onPop: (info: PopInfo) => {
      const result = info.result as ReturnResult;
      if (result?.changed) { this.model.load(); }
      if (result?.published) {
        this.notice = '发布成功，新的线索已经送达。';
        if (this.noticeTimer >= 0) { clearTimeout(this.noticeTimer); }
        this.noticeTimer = setTimeout(() => { this.notice = ''; this.noticeTimer = -1; }, 4500);
      }
    } });
  }
  @Builder
  destination(name: string) {
    if (name === 'Detail') { DetailPage() }
    else if (name === 'Publish') { PublishPage() }
    else if (name === 'My') { MyPage({ onOpen: (id: string) => this.open('Detail', id) }) }
    else if (name === 'Statistics') { StatisticsPage() }
  }
  @Builder
  nav(label: string, symbol: string, route: string) {
    Column({ space: 3 }) {
      Text(symbol).fontSize(21).fontWeight(FontWeight.Bold).fontColor(Colors.green)
      Text(label).fontSize(11).fontColor(Colors.green)
    }.layoutWeight(1).height(53).justifyContent(FlexAlign.Center).onClick(() => {
      if (route.length) { this.open(route); } else { this.model.load(); }
    })
  }
  build() {
    Navigation(this.stack) {
      Column({ space: 12 }) {
        PageHeader({ title: '拾光校园', subtitle: 'LOST & FOUND  /  校园互助' })
        Row() {
          Column({ space: 8 }) {
            Text('让每一份遗失\n都有回音').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').lineHeight(32)
            Text('找回物品，也遇见校园里的善意').fontSize(11).fontColor('#D6E5D3')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text('⌕').fontSize(70).fontColor('#F3D28F').margin({ right: 5 })
        }.width('90%').height(132).padding(20).backgroundColor(Colors.green).borderRadius(23)
        if (this.notice.length) { Text(this.notice).fontSize(12).fontColor(Colors.green).onClick(() => { this.notice = ''; }) }
        FeedContent({ model: this.model, onOpen: (id: string) => this.open('Detail', id) }).layoutWeight(1)
        Row() {
          this.nav('广场', '⌂', '')
          this.nav('统计', '▥', 'Statistics')
          this.nav('发布', '＋', 'Publish')
          this.nav('我的', '○', 'My')
        }.width('100%').padding({ left: 10, right: 10, top: 5, bottom: 8 }).backgroundColor('#FFFFFF')
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).navDestination(this.destination).mode(NavigationMode.Stack)
      .onNavBarStateChange((visible: boolean) => { if (visible) { this.model.load(); } })
  }
}
