import { Item, emptyItem } from '../model/Models';
export class Colors {
  static ink: string = '#173E38';
  static green: string = '#17685B';
  static soft: string = '#E4F0E9';
  static paper: string = '#F3F6F2';
  static surface: string = '#FFFFFF';
  static stroke: string = '#DFE8E0';
  static muted: string = '#526A61';
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
export function claimColor(status: string): string { return status === 'accepted' ? Colors.green : (status === 'rejected' ? Colors.red : (status === 'cancelled' ? Colors.muted : '#A17C3C')); }
@ComponentV2
export struct PageHeader {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param back: boolean = false;
  @Event onBack: () => void = () => {};
  build() {
    Row({ space: 10 }) {
      if (this.back) {
        Button('‹').fontSize(28).fontColor(Colors.green).backgroundColor(Colors.surface)
          .width(44).height(44).borderRadius(14).accessibilityText('返回').onClick(() => this.onBack())
      }
      Column({ space: 3 }) {
        Text(this.title).fontSize(23).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle.length) { Text(this.subtitle).fontSize(11).fontColor(Colors.muted).maxLines(1) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.app_icon')).width(38).height(38).borderRadius(12).accessibilityLevel('no')
    }.width('100%').height(62).padding({ left: 16, right: 16, top: 5, bottom: 5 })
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
      .accessibilitySelected(this.selected)
  }
}
@ComponentV2
export struct SegmentTab {
  @Param label: string = '';
  @Param selected: boolean = false;
  @Event onSelect: () => void = () => {};
  build() {
    Button(this.label).width('100%').height(40).padding({ left: 3, right: 3 })
      .fontSize(13).fontWeight(this.selected ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.selected ? Colors.green : Colors.muted)
      .backgroundColor(this.selected ? Colors.surface : '#00000000').borderRadius(10)
      .border({ width: 1, color: this.selected ? Colors.stroke : '#00000000' })
      .accessibilitySelected(this.selected).onClick(() => this.onSelect())
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
        if (this.phase === 'error' && this.error.length) {
          Text(this.error).fontSize(12).maxLines(3).fontColor(Colors.muted).textAlign(TextAlign.Center)
            .padding({ left: 22, right: 22 })
        }
        Button(this.phase === 'error' ? '重新加载' : this.emptyAction).height(42).fontSize(13)
          .fontColor('#FFFFFF').backgroundColor(Colors.green).onClick(() => this.onRetry())
      }
    }.width('100%').padding({ top: 16, bottom: 16 }).justifyContent(FlexAlign.Center)
  }
}
@ComponentV2
export struct NoticeStatus {
  @Param status: string = 'open';
  statusInk(): string {
    if (this.status === 'resolved') { return Colors.green; }
    return this.status === 'withdrawn' ? Colors.muted : '#77531C';
  }
  statusFill(): string {
    if (this.status === 'resolved') { return '#E5F1E8'; }
    return this.status === 'withdrawn' ? '#ECF0ED' : '#FCF0D8';
  }
  build() {
    Text(statusText(this.status)).fontSize(11).fontWeight(FontWeight.Medium).fontColor(this.statusInk())
      .backgroundColor(this.statusFill()).padding({ left: 7, right: 7, top: 2, bottom: 2 }).borderRadius(7)
  }
}
@ComponentV2
export struct ItemCard {
  @Param item: Item = emptyItem();
  @Event onOpen: (id: string) => void = () => {};
  build() {
    Row({ space: 11 }) {
      Image(categoryArt(this.item.category)).width(62).height(72).objectFit(ImageFit.Contain)
        .backgroundColor(this.item.kind === 'found' ? '#EAF2E6' : '#FBF0D9').borderRadius(14).accessibilityLevel('no')
      Column({ space: 5 }) {
        Row({ space: 6 }) {
          Text((this.item.kind === 'found' ? '招领' : '寻物') + ' · ' + this.item.category)
            .fontSize(11).fontColor(Colors.muted).maxLines(1).layoutWeight(1)
          NoticeStatus({ status: this.item.status })
        }.width('100%')
        Text(this.item.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Row({ space: 5 }) {
          Text(this.item.location + ' · ' + this.item.occurredAt.slice(5)).fontSize(12).fontColor(Colors.muted)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          if (this.item.saved) { Text('★').fontSize(13).fontColor(Colors.green).accessibilityText('已收藏') }
        }.width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(21).fontColor(Colors.green).accessibilityLevel('no')
    }.width('100%').padding(11).backgroundColor(Colors.surface).borderRadius(16)
      .border({ width: 1, color: Colors.stroke }).onClick(() => this.onOpen(this.item.id))
      .accessibilityText(this.item.title + '，' + statusText(this.item.status) + '，' + this.item.location)
  }
}
