import { CATEGORIES, Item } from '../model/Models';
import { FeedModel } from '../model/FeedModel';
import { ChoiceChip, Colors, ItemCard, StatePanel } from './Common';
@ComponentV2
export struct FeedContent {
  @Param model: FeedModel = new FeedModel();
  @Param filters: boolean = true;
  @Event onOpen: (id: string) => void = () => {};
  build() {
    Column({ space: 12 }) {
      if (this.filters) {
        Row({ space: 8 }) {
          TextInput({ placeholder: '搜索物品、地点或线索', text: this.model.keyword }).height(42).fontSize(13).maxLength(80)
            .backgroundColor('#FFFFFF').layoutWeight(1).onChange((value: string) => { this.model.keyword = value; })
            .onSubmit(() => { this.model.load(); })
          Button('搜索').height(40).fontSize(13).backgroundColor(Colors.green).onClick(() => { this.model.load(); })
        }.padding({ left: 20, right: 20 })
        Row({ space: 8 }) {
          ChoiceChip({ label: '全部', selected: this.model.kind === 'all', onSelect: () => { this.model.kind = 'all'; this.model.load(); } })
          ChoiceChip({ label: '我丢了', selected: this.model.kind === 'lost', onSelect: () => { this.model.kind = 'lost'; this.model.load(); } })
          ChoiceChip({ label: '我捡到', selected: this.model.kind === 'found', onSelect: () => { this.model.kind = 'found'; this.model.load(); } })
          Blank()
          Text('刷新').fontSize(12).fontColor(Colors.green).padding(8).onClick(() => { this.model.load(); })
        }.width('100%').padding({ left: 20, right: 20 })
        Scroll() {
          Row({ space: 8 }) {
            ChoiceChip({ label: '所有分类', selected: this.model.category === 'all', onSelect: () => { this.model.category = 'all'; this.model.load(); } })
            ForEach(CATEGORIES, (category: string) => {
              ChoiceChip({ label: category, selected: this.model.category === category, onSelect: () => { this.model.category = category; this.model.load(); } })
            }, (category: string) => category)
          }.padding({ left: 20, right: 20 })
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').height(34)
      }
      if (this.model.phase !== 'ready') {
        StatePanel({ phase: this.model.phase, error: this.model.error, emptyAction: this.filters ? '清空筛选' : '刷新信息', onRetry: () => {
          if (this.filters && this.model.phase === 'empty') {
            this.model.keyword = ''; this.model.kind = 'all'; this.model.category = 'all';
          }
          this.model.load();
        } }).layoutWeight(1)
      } else {
        List({ space: 12 }) {
          ForEach(this.model.items, (item: Item) => {
            ListItem() { ItemCard({ item: item, onOpen: (id: string) => this.onOpen(id) }) }
          }, (item: Item) => item.id)
          ListItem() {
            Text('共 ' + this.model.items.length + ' 条 · 更新于 ' + this.model.updated).fontSize(11).fontColor(Colors.muted).width('100%').textAlign(TextAlign.Center).padding(12)
          }
        }.layoutWeight(1).padding({ left: 20, right: 20 }).scrollBar(BarState.Off).width('100%')
      }
    }.width('100%').height('100%')
  }
}
