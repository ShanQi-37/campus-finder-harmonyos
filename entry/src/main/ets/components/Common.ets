import { Item, emptyItem } from '../model/Models';
export class Colors {
  static ink: string = '#173E38';
  static green: string = '#17685B';
  static soft: string = '#E4F0E9';
  static paper: string = '#F4F6F2';
  static muted: string = '#778A83';
  static gold: string = '#EDBA65';
  static red: string = '#BA563E';
}
export function categoryArt(category: string): Resource {
  if (category === '电子数码') { return $r('app.media.category_digital'); }
  if (category === '生活用品') { return $r('app.media.category_life'); }
  if (category === '学习文具') { return $r('app.media.category_study'); }
  return $r('app.media.category_card');
}
export function statusText(status: string): string { return status === 'resolved' ? '已寻回' : (status === 'withdrawn' ? '已撤回' : '待寻回'); }
export function claimText(status: string): string { return status === 'accepted' ? '已通过' : (status === 'rejected' ? '未通过' : (status === 'cancelled' ? '已取消' : '待核对')); }
@ComponentV2
export struct PageHeader {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param back: boolean = false;
  @Event onBack: () => void = () => {};
  build() {
    Row({ space: 10 }) {
      if (this.back) { Button('‹').fontSize(30).fontColor(Colors.green).backgroundColor('#FFFFFF').width(36).height(36).borderRadius(12).onClick(() => this.onBack()) }
      Column({ space: 3 }) {
        Text(this.title).fontSize(22).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
        if (this.subtitle.length) { Text(this.subtitle).fontSize(10).fontColor(Colors.muted).maxLines(1) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.app_icon')).width(34).height(34).borderRadius(12)
    }.width('100%').height(76).padding({ left: 18, right: 18, top: 10, bottom: 10 })
  }
}
@ComponentV2
export struct ChoiceChip {
  @Param label: string = '';
  @Param selected: boolean = false;
  @Event onSelect: () => void = () => {};
  build() {
    Button(this.label).fontSize(12).fontWeight(this.selected ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selected ? '#FFFFFF' : Colors.muted).backgroundColor(this.selected ? Colors.green : '#FFFFFF')
      .height(32).padding({ left: 12, right: 12 }).borderRadius(10).onClick(() => this.onSelect())
  }
}
@ComponentV2
export struct StatePanel {
  @Param phase: string = 'loading';
  @Param error: string = '';
  @Param emptyText: string = '暂时没有匹配的信息';
  @Param emptyAction: string = '刷新信息';
  @Event onRetry: () => void = () => {};
  build() {
    Column({ space: 10 }) {
      if (this.phase === 'loading') {
        LoadingProgress().width(36).height(36).color(Colors.green)
        Text('正在同步校园线索…').fontSize(13).fontColor(Colors.muted)
      } else {
        Text(this.phase === 'error' ? '!' : '⌕').fontSize(30).fontColor(Colors.green).width(54).height(54).textAlign(TextAlign.Center).backgroundColor(Colors.soft).borderRadius(18)
        Text(this.phase === 'error' ? '暂时未能加载' : this.emptyText).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
        Text(this.phase === 'error' ? this.error : '校园里的每一份善意，都在等待回音。').fontSize(11).maxLines(3).fontColor(Colors.muted).textAlign(TextAlign.Center).padding({ left: 22, right: 22 })
        Button(this.phase === 'error' ? '重新加载' : this.emptyAction).height(34).fontSize(12).fontColor('#FFFFFF').backgroundColor(Colors.green).onClick(() => this.onRetry())
      }
    }.width('100%').padding({ top: 16, bottom: 16 }).justifyContent(FlexAlign.Center)
  }
}
@ComponentV2
export struct ItemCard {
  @Param item: Item = emptyItem();
  @Event onOpen: (id: string) => void = () => {};
  build() {
    Row({ space: 12 }) {
      Image(categoryArt(this.item.category)).width(76).height(88).objectFit(ImageFit.Contain).backgroundColor(this.item.kind === 'found' ? '#EEF4E8' : '#FFF3DF').borderRadius(15)
      Column({ space: 7 }) {
        Row({ space: 6 }) {
          Text(this.item.kind === 'found' ? '拾物招领' : '寻物启事').fontSize(9).fontColor(Colors.green).backgroundColor(Colors.soft).padding({ left: 6, right: 6, top: 3, bottom: 3 }).borderRadius(4)
          Blank()
          Text(statusText(this.item.status)).fontSize(10).fontColor(this.item.status === 'resolved' ? Colors.green : '#B5873E')
        }.width('100%')
        Text(this.item.title).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text('⌖ ' + this.item.location + ' · ' + this.item.occurredAt.slice(5)).fontSize(10).fontColor(Colors.muted).maxLines(1)
        Text(this.item.saved ? '★ 已收藏  ·  查看线索  ›' : this.item.category + '  ·  查看线索  ›').fontSize(10).fontColor(Colors.green)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(12).backgroundColor('#FFFFFF').borderRadius(18)
      .border({ width: 1, color: '#EAF0E9' }).onClick(() => this.onOpen(this.item.id)).accessibilityText(this.item.title)
  }
}
