import { FeedModel } from '../model/FeedModel';
import { Colors, PageHeader } from '../components/Common';
import { FeedContent } from '../components/FeedContent';
@ComponentV2
export struct MyPage {
  @Local model: FeedModel = new FeedModel();
  @Event onOpen: (id: string) => void = () => {};
  private stack: NavPathStack = new NavPathStack();
  aboutToAppear(): void { this.model.owner = 'demo-user'; }
  aboutToDisappear(): void { this.model.cancel(); }
  build() {
    NavDestination() {
      Column({ space: 12 }) {
        PageHeader({ title: '我的记录', subtitle: '每一次发布，都是一份期待', back: true, onBack: () => { this.stack.pop(); } })
        Row({ space: 13 }) {
          Text('同').fontSize(22).fontColor(Colors.green).padding(16).backgroundColor(Colors.soft).borderRadius(18)
          Column({ space: 6 }) {
            Text('校园体验同学').fontSize(18).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
            Text('课程演示身份 · 只展示此身份发布的记录').fontSize(11).fontColor(Colors.muted)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text('刷新').fontSize(13).fontColor(Colors.green).padding(8).onClick(() => { this.model.load(); })
        }.padding({ left: 20, right: 20, bottom: 10 }).width('100%')
        FeedContent({ model: this.model, filters: false, onOpen: (id: string) => this.onOpen(id) }).layoutWeight(1)
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; })
      .onShown(() => { this.model.load(); })
  }
}
