import { CATEGORY_OPTIONS, CATEGORIES, STATUS_OPTIONS, Item } from '../model/Models';
import { FeedModel } from '../model/FeedModel';
import { ChoiceChip, Colors, ItemCard, StatePanel } from './Common';
@ComponentV2
export struct FeedContent {
  @Param model: FeedModel = new FeedModel();
  @Param filters: boolean = true;
  @Event onOpen: (id: string) => void = () => {};
  build() {
    Column({ space: 10 }) {
      if (this.filters) {
        Row({ space: 8 }) {
          TextInput({ placeholder: '搜索物品 / 地点 / 线索', text: this.model.keyword }).height(40).fontSize(12).maxLength(80)
            .backgroundColor('#FFFFFF').layoutWeight(1).onChange((value: string) => { this.model.keyword = value; }).onSubmit(() => { this.model.load(); })
          Button('搜索').height(38).fontSize(12).backgroundColor(Colors.green).onClick(() => { this.model.load(); })
        }.padding({ left: 18, right: 18 })
        Row({ space: 8 }) {
          ChoiceChip({ label: '全部', selected: this.model.kind === 'all', onSelect: () => { this.model.kind = 'all'; this.model.load(); } })
          ChoiceChip({ label: '我丢了', selected: this.model.kind === 'lost', onSelect: () => { this.model.kind = 'lost'; this.model.load(); } })
          ChoiceChip({ label: '我捡到', selected: this.model.kind === 'found', onSelect: () => { this.model.kind = 'found'; this.model.load(); } })
          Blank()
          Text('重置').fontSize(12).fontColor(Colors.green).padding(6).onClick(() => this.model.reset())
        }.width('100%').padding({ left: 18, right: 18 })
        Row({ space: 6 }) {
          Select(CATEGORY_OPTIONS).value(this.model.category === 'all' ? '全部分类' : this.model.category).selected(CATEGORIES.indexOf(this.model.category) + 1).font({ size: 12 }).height(30).backgroundColor('#E9EFEB').layoutWeight(1)
            .onSelect((index: number) => { this.model.category = index === 0 ? 'all' : CATEGORIES[index - 1]; this.model.load(); })
          Select(STATUS_OPTIONS).value(this.model.status === 'all' ? '全部状态' : (this.model.status === 'open' ? '待寻回' : '已寻回')).font({ size: 12 }).height(30).backgroundColor('#E9EFEB').layoutWeight(1)
            .onSelect((index: number) => { this.model.status = index === 0 ? 'all' : (index === 1 ? 'open' : 'resolved'); this.model.load(); })
          Text(this.model.sort === 'latest' ? '最新 ↓' : '最早 ↑').fontSize(11).fontColor(Colors.green).padding(6).onClick(() => { this.model.sort = this.model.sort === 'latest' ? 'oldest' : 'latest'; this.model.load(); })
        }.padding({ left: 18, right: 18 }).width('100%')
      }
      if (this.filters && this.model.phase === 'ready') {
        Row() {
          Text('校园线索').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
          Blank()
          Text(this.model.total + ' 条结果 · 已同步').fontSize(10).fontColor(Colors.muted)
        }.width('100%').padding({ left: 20, right: 20 })
      }
      if (this.model.phase !== 'ready') {
        StatePanel({ phase: this.model.phase, error: this.model.error, emptyAction: this.filters ? '清空筛选' : '刷新信息', onRetry: () => { if (this.filters && this.model.phase === 'empty') { this.model.reset(); } else { this.model.load(); } } }).layoutWeight(1)
      } else {
        List({ space: 10 }) {
          ForEach(this.model.items, (item: Item) => { ListItem() { ItemCard({ item: item, onOpen: (id: string) => this.onOpen(id) }) } }, (item: Item) => item.id)
        }.layoutWeight(1).padding({ left: 18, right: 18 }).scrollBar(BarState.Auto).width('100%')
      }
      if (this.model.phase === 'ready') {
      Row({ space: 8 }) {
        Button('‹ 上一页').height(28).fontSize(10).fontColor(Colors.green).backgroundColor('#FFFFFF').enabled(this.model.page > 1).onClick(() => this.model.turn(-1))
        Text('第 ' + this.model.page + ' 页 / 共 ' + this.model.total + ' 条').fontSize(10).fontColor(Colors.muted).layoutWeight(1).textAlign(TextAlign.Center)
        Button('下一页 ›').height(28).fontSize(10).fontColor(Colors.green).backgroundColor('#FFFFFF').enabled(this.model.hasMore).onClick(() => this.model.turn(1))
      }.width('100%').padding({ left: 18, right: 18, bottom: 4 })
      }
    }.width('100%').height('100%')
  }
}
