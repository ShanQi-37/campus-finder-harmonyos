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
  static green: string = '#0E9F6E';
  static greenDeep: string = '#0B6E4F';
  static greenSoft: string = '#E8F5EF';   // 浅底强调，只用于选中态/关键点缀
  static soft: string = '#EAF4EE';        // 浅色表面（入口按钮、选中背景）

  // 中性灰阶（背景与文字，构成画面主体）
  static paper: string = '#F7F9F7';       // 页面底色
  static surface: string = '#FFFFFF';     // 卡片底色
  static ink: string = '#1F2D28';         // 主文字
  static muted: string = '#6B7C74';       // 次级文字
  static faint: string = '#9AA8A1';       // 辅助/占位文字
  static stroke: string = '#ECF0ED';      // 极淡分隔线（仅用于必要分隔）

  // 语义点缀（只在表达状态/情感时出现，不参与常态配色）
  static gold: string = '#C8890E';
  static goldSoft: string = '#FBF3E3';
  static goldInk: string = '#8A5A0A';
  static red: string = '#E5484D';
  static redSoft: string = '#FDF0F0';
  static blue: string = '#3B82F6';
  static blueSoft: string = '#EDF4FE';

  // 渐变（hero 与主 CTA）
  static heroStart: string = '#12A87A';
  static heroEnd: string = '#0B6E4F';
  static foundFill: string = '#EAF4EE';
  static lostFill: string = '#FBF3E3';

  // 背景氛围（「不背单词」式的柔光渐变，非纯平色）
  static bgTop: string = '#ECF3EF';       // 顶部淡青绿（更柔和）
  static bgBottom: string = '#F8F6F0';    // 底部浅米白（更柔和）
  static bgGlowA: string = '#1FFFFFFF';   // 雾化光斑（淡青，略强化）
  static bgGlowB: string = '#1AF7E4C8';   // 雾化光斑（淡暖，略强化）
  // 毛玻璃卡片（半透明白 + 背景模糊）
  static glass: string = '#B8FFFFFF';     // 半透明卡片底（更通透）
  static glassStroke: string = '#24FFFFFF'; // 毛玻璃边缘高光
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
  static caption: number = 12;  // 辅助说明、时间、标签
  static body: number = 14;     // 正文
  static title: number = 16;    // 列表标题、卡片小标题
  static heading: number = 20;  // 页面大标题、hero
  static display: number = 28;  // 数字大屏、关键指标
}

/** 阴影令牌：三档层级，克制使用（卡片统一用 sm，浮层/悬浮按钮用 md）。 */
export class Shadow {
  static sm: string = '#0D1F2D1F';   // 卡片
  static md: string = '#26201F2D26';  // 悬浮元素
  static lg: string = '#33201F2D40';  // 弹层
}
export function categoryArt(category: string): Resource {
  if (category === '电子数码') { return $r('app.media.category_digital'); }
  if (category === '生活用品') { return $r('app.media.category_life'); }
  if (category === '学习文具') { return $r('app.media.category_study'); }
  return $r('app.media.category_card');
}
/**
 * 物品主图：实拍图优先，插画兜底。
 * 有 mediaId（用户上传的照片）时返回可加载的媒体 URL，否则返回 null 走分类插画。
 */
export function itemPhoto(item: Item): string {
  if (item.mediaId && item.mediaType === 'photo') { return Api.mediaUrl(item.id, item.mediaId); }
  return '';
}
/**
 * 物品缩略图组件：有实拍照片就显示实物（圆角裁剪），没有则显示分类插画占位。
 * 统一列表卡、详情页、发布预览、认领表单的物品图逻辑。
 */
@ComponentV2
export struct ItemThumb {
  @Param item: Item = emptyItem();
  @Param w: number = 60;
  @Param h: number = 68;
  @Param radius: number = 14;
  @Param bg: string = '';
  photo: string = '';
  aboutToAppear(): void {
    this.photo = itemPhoto(this.item);
  }
  build() {
    if (this.photo.length) {
      Image(this.photo).width(this.w).height(this.h).objectFit(ImageFit.Cover)
        .borderRadius(this.radius).accessibilityLevel('no')
        .onError(() => { this.photo = ''; })
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
          .width(40).height(40).borderRadius(Radius.sm).accessibilityText('返回').onClick(() => this.onBack())
      }
      Column({ space: 2 }) {
        Text(this.title).fontSize(FontSize.heading).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle.length) { Text(this.subtitle).fontSize(FontSize.caption).fontColor(Colors.faint).maxLines(1) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.app_icon')).width(36).height(36).borderRadius(Radius.sm).accessibilityLevel('no')
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
    Button(this.label).width('100%').constraintSize({ minHeight: 38 }).padding({ left: 3, right: 3, top: 8, bottom: 8 })
      .fontSize(FontSize.caption).fontWeight(this.selected ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.selected ? Colors.ink : Colors.muted)
      .backgroundColor(this.selected ? Colors.surface : '#00000000').borderRadius(Radius.sm)
      .shadow(this.selected ? { radius: 4, color: '#0D1F2D14', offsetX: 0, offsetY: 1 } : { radius: 0, color: '#00000000' })
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
          .fontColor('#FFFFFF').linearGradient({ angle: 135, colors: [[Colors.heroStart, 0.0], [Colors.heroEnd, 1.0]] })
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
      ItemThumb({ item: this.item, w: 60, h: 68, radius: Radius.md })
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Text((this.item.kind === 'found' ? '招领' : '寻物') + ' · ' + this.item.category)
            .fontSize(FontSize.caption).fontColor(Colors.faint).maxLines(1).layoutWeight(1)
          NoticeStatus({ status: this.item.status })
        }.width('100%')
        Text(this.item.title).fontSize(FontSize.title).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Row({ space: 5 }) {
          Text(this.item.location + ' · ' + this.itemDate()).fontSize(FontSize.caption).fontColor(Colors.muted)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          if (this.item.saved) { Text('★').fontSize(13).fontColor(Colors.green).accessibilityText('已收藏') }
        }.width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(20).fontColor(Colors.faint).accessibilityLevel('no')
    }.width('100%').padding(Spacing.md).backgroundColor(Colors.glass).borderRadius(Radius.md)
      .backdropBlur(20).border({ width: 1, color: Colors.glassStroke })
      .shadow({ radius: 8, color: Shadow.sm, offsetX: 0, offsetY: 2 })
      .onClick(() => this.onOpen(this.item.id))
      .accessibilityText(this.item.title + '，' + statusText(this.item.status) + '，' + this.item.location)
  }
}
/**
 * 氛围背景层：复刻「不背单词」的柔光渐变 + 雾化光斑。
 * 用纵向渐变替代纯平底色，叠两个极淡的雾化光斑营造空间感。
 */
@ComponentV2
export struct AmbientBackground {
  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[Colors.bgTop, 0.0], [Colors.bgBottom, 1.0]] })
      Circle().width(280).height(280).fill(Colors.bgGlowA).blur(70)
        .position({ x: -80, y: 80 })
      Circle().width(240).height(240).fill(Colors.bgGlowB).blur(70)
        .position({ x: 240, y: 520 })
      Circle().width(180).height(180).fill(Colors.bgGlowA).blur(60)
        .position({ x: -40, y: 780 })
    }.width('100%').height('100%')
  }
}
