import { FeedContent } from '../components/FeedContent';
import { Colors, PageHeader, statusText } from '../components/Common';
import { FeedModel } from '../model/FeedModel';
import { StatisticsScope } from '../model/Models';

@ComponentV2
export struct StatisticsItemsPage {
  @Local model: FeedModel = new FeedModel();
  @Local scope: StatisticsScope = { window: { start: '', end: '' }, category: 'all', status: 'all', dateType: 'published' };
  private stack: NavPathStack = new NavPathStack();

  @Builder
  scopeCard() {
    Row({ space: 8 }) {
      Column({ space: 5 }) {
        Text(this.scope.window.start === this.scope.window.end ? this.scope.window.start :
          this.scope.window.start + ' 至 ' + this.scope.window.end).fontSize(15).fontWeight(FontWeight.Bold)
          .fontColor(Colors.ink).width('100%')
        Text((this.scope.category === 'all' ? '全部分类' : this.scope.category) + ' · ' +
          (this.scope.status === 'all' ? '有效启事' : statusText(this.scope.status)))
          .fontSize(12).fontColor(Colors.muted).width('100%')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.model.phase === 'ready' || this.model.phase === 'empty') {
        Text(this.model.total + ' 条').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.green)
      }
    }.width('100%').padding(12).backgroundColor(Colors.soft).borderRadius(14)
  }

  build() {
    NavDestination() {
      Column({ space: 10 }) {
        PageHeader({ title: this.scope.dateType === 'resolved' ? '确认寻回明细' : '统计启事明细',
          subtitle: this.scope.dateType === 'resolved' ? '按实际确认寻回日期筛选' : '按发布日期筛选', back: true,
          onBack: () => { this.stack.pop(); } })
        Column() { this.scopeCard() }.width('100%').padding({ left: 16, right: 16 })
        FeedContent({ model: this.model, filters: false,
          showPublishedDate: this.scope.dateType !== 'resolved', showResolvedDate: this.scope.dateType === 'resolved',
          onOpen: (id: string) => { this.stack.pushPath({ name: 'Detail', param: id }); } }).layoutWeight(1)
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
      this.scope = context.pathInfo.param as StatisticsScope;
      this.model.category = this.scope.category;
      this.model.status = this.scope.status;
      if (this.scope.dateType === 'resolved') { this.model.resolutionWindow = this.scope.window; }
      else { this.model.publicationWindow = this.scope.window; }
    }).onShown(() => { this.model.load(false); }).onHidden(() => this.model.cancel())
  }
}
