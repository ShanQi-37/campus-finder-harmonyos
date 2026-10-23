import { Item, emptyItem } from '../model/Models';
export class Colors {
  static ink: string = '#233A31';
  static green: string = '#235D49';
  static soft: string = '#E6EEE5';
  static paper: string = '#F7F8F2';
  static muted: string = '#748179';
  static gold: string = '#E7B967';
}
@ComponentV2
export struct PageHeader {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param back: boolean = false;
  @Event onBack: () => void = () => {};
  build() {
    Row({ space: 12 }) {
      if (this.back) { Button('‹').fontSize(29).fontColor(Colors.green).backgroundColor(Colors.soft).width(40).height(40).onClick(() => this.onBack()) }
      Column({ space: 4 }) {
        Text(this.title).fontSize(24).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
        if (this.subtitle.length) { Text(this.subtitle).fontSize(12).fontColor(Colors.muted) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('拾光').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Colors.green).padding(10).backgroundColor(Colors.soft).borderRadius(12)
    }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 16 })
  }
}
@ComponentV2
export struct ChoiceChip {
  @Param label: string = '';
  @Param selected: boolean = false;
  @Event onSelect: () => void = () => {};
  build() {
    Button(this.label).fontSize(13).fontWeight(this.selected ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selected ? '#FFFFFF' : Colors.muted).backgroundColor(this.selected ? Colors.green : '#FFFFFF')
      .height(34).padding({ left: 14, right: 14 }).borderRadius(10).onClick(() => this.onSelect())
  }
}
@ComponentV2
export struct StatePanel {
  @Param phase: string = 'loading';
  @Param error: string = '';
  @Param emptyText: string = '暂时没有匹配的信息';
  @Event onRetry: () => void = () => {};
  build() {
    Column({ space: 10 }) {
      if (this.phase === 'loading') {
        LoadingProgress().width(40).height(40).color(Colors.green)
        Text('正在寻找校园里的线索…').fontSize(14).fontColor(Colors.muted)
      } else {
        Text(this.phase === 'error' ? '!' : '⌕').fontSize(30).fontColor(Colors.green)
        Text(this.phase === 'error' ? '暂时未能加载' : this.emptyText).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
        Text(this.phase === 'error' ? this.error : '换个关键词或分类试试，也可以发布一条信息。')
          .fontSize(12).maxLines(2).fontColor(Colors.muted).textAlign(TextAlign.Center).padding({ left: 20, right: 20 })
        Button(this.phase === 'error' ? '重新加载' : '刷新信息').height(36).fontColor('#FFFFFF').backgroundColor(Colors.green).onClick(() => this.onRetry())
      }
    }.width('100%').padding({ top: 16, bottom: 16 }).justifyContent(FlexAlign.Center)
  }
}
@ComponentV2
export struct ItemCard {
  @Param item: Item = emptyItem();
  @Event onOpen: (id: string) => void = () => {};
  build() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack() {
          Text(this.item.category.slice(0, 2)).fontSize(19).fontWeight(FontWeight.Bold).fontColor(Colors.green)
        }.width(62).height(65).backgroundColor(this.item.kind === 'found' ? '#EDF1DF' : '#F7ECD7').borderRadius(15)
        Column({ space: 8 }) {
          Row({ space: 6 }) {
            Text(this.item.kind === 'found' ? '拾物招领' : '寻物启事').fontSize(10).fontColor(Colors.green).backgroundColor(Colors.soft).padding({ left: 6, right: 6, top: 3, bottom: 3 }).borderRadius(4)
            Text(this.item.status === 'resolved' ? '已寻回' : '待寻回').fontSize(10).fontColor(this.item.status === 'resolved' ? Colors.green : '#AC7A28')
          }.width('100%')
          Text(this.item.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          Text(this.item.location + '  ·  ' + this.item.occurredAt.slice(5)).fontSize(12).fontColor(Colors.muted).maxLines(1)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('›').fontSize(24).fontColor('#A0A99F')
      }.width('100%')
      Text(this.item.description).fontSize(12).fontColor(Colors.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
    }.width('100%').padding(15).backgroundColor('#FFFFFF').borderRadius(18)
      .onClick(() => this.onOpen(this.item.id)).accessibilityText(this.item.title)
  }
}
