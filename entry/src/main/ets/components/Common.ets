import { Item, emptyItem } from '../model/Models';
import { Api } from '../service/Api';

/**
 * ────────────────────────────────────────────────
 *  Design Token · 拾光校园设计令牌
 *  「克制的留白美学」——单一品牌绿 + 中性灰阶，
 *  去除描边/阴影叠用，用留白与字号层级建立秩序。
 * ────────────────────────────────────────────────
 */

/** 颜色令牌：一个品牌绿 + 中性灰阶，其余只作语义点缀。 */
export class Colors {
  // 品牌主色（唯一的强调色，克制使用）
  static green: string = '#226953';
  static greenDeep: string = '#175846';
  static greenSoft: string = '#E0EFE6';   // 浅底强调，只用于选中态/关键点缀
  static soft: string = '#EAF4EE';        // 浅色表面（入口按钮、选中背景）

  // 中性灰阶（背景与文字，构成画面主体）
  static paper: string = '#F5F8F6';       // 页面底色
  static surface: string = '#FFFFFF';     // 卡片底色
  static ink: string = '#182A23';         // 主文字
  static muted: string = '#536960';       // 次级文字
  static faint: string = '#61736B';       // 辅助/占位文字
  static stroke: string = '#DAE5DF';      // 分隔线及边框

  // 语义点缀（只在表达状态/情感时出现，不参与常态配色）
  static gold: string = '#C8890E';
  static goldSoft: string = '#FBF3E3';
  static goldInk: string = '#8A5A0A';
  static red: string = '#A8343E';
  static redSoft: string = '#FDF0F0';
  static blue: string = '#3B82F6';
  static blueSoft: string = '#EDF4FE';

  static foundFill: string = '#EAF4EE';
  static lostFill: string = '#FBF3E3';

  static bgTop: string = '#E2F0E8';
  static bgQuiet: string = '#EDF5F0';
  static bgBottom: string = '#F8F6F0';
  static glass: string = '#FFFFFF';
  static glassStroke: string = '#DDE8E1';
}

/** 间距令牌：4px 基础节奏，向上倍增。 */
export class Spacing {
  static xs: number = 4;    // 图标与文字的最小间距
  static sm: number = 8;    // 元素内间距
  static md: number = 12;   // 卡片内边距
  static lg: number = 16;   // 页面左右留白 / 卡片间距
  static xl: number = 20;   // 区块间距
  static xxl: number = 24;  // 大区块留白
}

/** 圆角令牌：三档，克制。 */
export class Radius {
  static sm: number = 10;   // 小组件：按钮、chip、输入框
  static md: number = 14;   // 卡片、图片缩略
  static lg: number = 20;   // 大容器、hero
}

/** 字号令牌：五档，覆盖全场景，去除 1px 碎差异。 */
export class FontSize {
  static caption: number = 13;  // 辅助说明、时间、标签
  static body: number = 14;     // 正文
  static title: number = 16;    // 列表标题、卡片小标题
  static heading: number = 22;  // 页面大标题
  static display: number = 28;  // 数字大屏、关键指标
}

export function categoryArt(category: string): Resource {
  if (category === '电子数码') { return $r('app.media.category_digital'); }
  if (category === '生活用品') { return $r('app.media.category_life'); }
  if (category === '学习文具') { return $r('app.media.category_study'); }
  return $r('app.media.category_card');
}
/**
 * 优先使用已发布的照片或视频封面。
 */
export function itemPhoto(item: Item): string {
  if (!item.mediaId || item.status === 'withdrawn') { return ''; }
  if (item.mediaType === 'photo') { return Api.mediaUrl(item.id, item.mediaId); }
  if (item.mediaType === 'video') { return Api.mediaCoverUrl(item.id, item.mediaId); }
  return '';
}
/**
 * 列表和详情共用缩略图，媒体不可用时显示分类插画。
 */
@ComponentV2
export struct ItemThumb {
  @Param item: Item = emptyItem();
  @Param w: number = 60;
  @Param h: number = 68;
  @Param radius: number = 14;
  @Param bg: string = '';
  @Local failedPhoto: string = '';

  @Builder
  mediaThumb(source: string) {
    Image(source).width(this.w).height(this.h).objectFit(ImageFit.Cover)
      .borderRadius(this.radius).accessibilityLevel('no')
      .onError(() => { this.failedPhoto = source; })
  }

  build() {
    if (itemPhoto(this.item).length && this.failedPhoto !== itemPhoto(this.item)) {
      this.mediaThumb(itemPhoto(this.item))
    } else {
      Image(categoryArt(this.item.category)).width(this.w).height(this.h).objectFit(ImageFit.Contain)
        .backgroundColor(this.bg.length ? this.bg : (this.item.kind === 'found' ? Colors.foundFill : Colors.lostFill))
        .borderRadius(this.radius).accessibilityLevel('no')
    }
  }
}
export function statusText(status: string): string { return status === 'resolved' ? '已寻回' : (status === 'withdrawn' ? '已撤回' : '待寻回'); }
export function claimText(status: string): string { return status === 'accepted' ? '已通过' : (status === 'rejected' ? '未通过' : (status === 'cancelled' ? '已取消' : '待核对')); }
export function claimColor(status: string): string { return status === 'accepted' ? Colors.green : (status === 'rejected' ? Colors.red : (status === 'cancelled' ? Colors.muted : Colors.goldInk)); }
@ComponentV2
export struct PageHeader {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param back: boolean = false;
  @Event onBack: () => void = () => {};
  build() {
    Row({ space: Spacing.sm }) {
      if (this.back) {
        Button('‹').fontSize(26).fontColor(Colors.ink).backgroundColor('#00000000')
          .width(44).height(44).borderRadius(Radius.sm).accessibilityText('返回').onClick(() => this.onBack())
      }
      Column({ space: 2 }) {
        Text(this.title).fontSize(FontSize.heading).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle.length) { Text(this.subtitle).fontSize(FontSize.caption).fontColor(Colors.faint).maxLines(1) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').constraintSize({ minHeight: 60 }).padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.sm, bottom: Spacing.sm })
  }
}
@ComponentV2
export struct ChoiceChip {
  @Param label: string = '';
  @Param selected: boolean = false;
  @Event onSelect: () => void = () => {};
  build() {
    Button(this.label).fontSize(FontSize.caption).fontWeight(this.selected ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selected ? Colors.greenDeep : Colors.muted)
      .backgroundColor(this.selected ? Colors.greenSoft : Colors.paper)
      .constraintSize({ minHeight: 30 }).padding({ left: Spacing.md, right: Spacing.md }).borderRadius(Radius.sm)
      .onClick(() => this.onSelect()).accessibilitySelected(this.selected)
  }
}
@ComponentV2
export struct SegmentTab {
  @Param label: string = '';
  @Param selected: boolean = false;
  @Event onSelect: () => void = () => {};
  build() {
    Button(this.label, { type: ButtonType.ROUNDED_RECTANGLE }).width('100%').constraintSize({ minHeight: 40 })
      .padding({ left: 4, right: 4, top: 8, bottom: 8 })
      .fontSize(FontSize.caption).fontWeight(this.selected ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.selected ? Colors.greenDeep : Colors.muted)
      .backgroundColor(this.selected ? Colors.greenSoft : Colors.surface)
      .border({ width: 1, color: this.selected ? '#A4C4B5' : Colors.stroke, radius: Radius.sm })
      .accessibilitySelected(this.selected).onClick(() => this.onSelect())
  }
}
@ComponentV2
export struct EmptyGlyph {
  @Param error: boolean = false;
  build() {
    Text(this.error ? '!' : '⌕').fontSize(this.error ? 30 : 34)
      .fontWeight(this.error ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.error ? Colors.greenDeep : Colors.green)
      .width(64).height(64).textAlign(TextAlign.Center)
      .backgroundColor(Colors.greenSoft).borderRadius(Radius.lg)
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
    Column({ space: Spacing.sm }) {
      if (this.phase === 'loading') {
        LoadingProgress().width(34).height(34).color(Colors.green)
        Text('正在同步校园线索…').fontSize(FontSize.caption).fontColor(Colors.faint)
      } else {
        EmptyGlyph({ error: this.phase === 'error' })
        Text(this.phase === 'error' ? '暂时未能加载' : this.emptyText).fontSize(FontSize.title).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
        if (this.phase === 'error' && this.error.length) {
          Text(this.error).fontSize(FontSize.caption).maxLines(3).fontColor(Colors.muted).textAlign(TextAlign.Center)
            .padding({ left: Spacing.xl, right: Spacing.xl })
        }
        Button(this.phase === 'error' ? '重新加载' : this.emptyAction).constraintSize({ minHeight: 40 }).fontSize(FontSize.body)
          .fontColor('#FFFFFF').backgroundColor(Colors.greenDeep)
          .borderRadius(Radius.sm)
          .onClick(() => this.onRetry())
      }
    }.width('100%').padding({ top: Spacing.lg, bottom: Spacing.lg }).justifyContent(FlexAlign.Center)
  }
}
@ComponentV2
export struct NoticeStatus {
  @Param status: string = 'open';
  statusInk(): string {
    if (this.status === 'resolved') { return Colors.greenDeep; }
    return this.status === 'withdrawn' ? Colors.faint : Colors.goldInk;
  }
  statusFill(): string {
    if (this.status === 'resolved') { return Colors.greenSoft; }
    return this.status === 'withdrawn' ? Colors.paper : Colors.goldSoft;
  }
  build() {
    Text(statusText(this.status)).fontSize(11).fontWeight(FontWeight.Medium).fontColor(this.statusInk())
      .backgroundColor(this.statusFill()).padding({ left: 7, right: 7, top: 2, bottom: 2 }).borderRadius(6)
  }
}
@ComponentV2
export struct ItemCard {
  @Param item: Item = emptyItem();
  @Param showPublishedDate: boolean = false;
  @Param showResolvedDate: boolean = false;
  @Event onOpen: (id: string) => void = () => {};
  itemDate(): string {
    if (this.showResolvedDate && this.item.resolvedAt.length) {
      return new Date(this.item.resolvedAt).toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' }).slice(5) + ' 确认寻回';
    }
    if (this.showPublishedDate) {
      return new Date(this.item.createdAt).toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' }).slice(5) + ' 发布';
    }
    return this.item.occurredAt.slice(5);
  }
  build() {
    Row({ space: Spacing.md }) {
      ItemThumb({ item: this.item, w: 64, h: 64, radius: Radius.sm })
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text((this.item.kind === 'found' ? '招领' : '寻物') + ' · ' + this.item.category)
            .fontSize(12).fontColor(this.item.kind === 'found' ? Colors.greenDeep : Colors.muted)
            .maxLines(1).layoutWeight(1)
          NoticeStatus({ status: this.item.status })
        }.width('100%')
        Text(this.item.title).fontSize(FontSize.title).fontWeight(FontWeight.Medium).fontColor(Colors.ink)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Row({ space: 5 }) {
          Text(this.item.location + ' · ' + this.itemDate()).fontSize(FontSize.caption).fontColor(Colors.muted)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          if (this.item.saved) { Text('★').fontSize(13).fontColor(Colors.green).accessibilityText('已收藏') }
        }.width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(Spacing.md).backgroundColor(Colors.surface).borderRadius(14)
      .border({ width: 1, color: '#E5EBE7' })
      .onClick(() => this.onOpen(this.item.id))
      .accessibilityText(this.item.title + '，' + statusText(this.item.status) + '，' + this.item.location)
  }
}
@ComponentV2
export struct AmbientBackground {
  @Param prominent: boolean = false;
  @Param login: boolean = false;
  build() {
    Column().width('100%').height('100%')
      .linearGradient({ angle: 180, colors: [[this.prominent || this.login ? Colors.bgTop : Colors.bgQuiet, 0.0],
        [Colors.paper, this.login ? 0.56 : (this.prominent ? 0.34 : 0.22)], [Colors.bgBottom, 1.0]] })
  }
}
