import { Colors } from './Common';
@ComponentV2
struct NavGlyph {
  @Param route: string = 'Home';
  @Param tint: string = Colors.green;
  path(): string {
    // Path command coordinates are physical pixels; convert design vp to the current density.
    const s: number = this.getUIContext().vp2px(1);
    if (this.route === 'Statistics') { return `M${4*s} ${3*s} L${4*s} ${21*s} L${21*s} ${21*s} M${8*s} ${16*s} L${8*s} ${11*s} M${13*s} ${16*s} L${13*s} ${6*s} M${18*s} ${16*s} L${18*s} ${9*s}`; }
    if (this.route === 'My') { return `M${16*s} ${7*s} A${4*s} ${4*s} 0 1 1 ${8*s} ${7*s} A${4*s} ${4*s} 0 1 1 ${16*s} ${7*s} M${4*s} ${21*s} L${4*s} ${19*s} A${8*s} ${8*s} 0 0 1 ${20*s} ${19*s} L${20*s} ${21*s}`; }
    if (this.route === 'Publish') { return `M${12*s} ${5*s} L${12*s} ${19*s} M${5*s} ${12*s} L${19*s} ${12*s}`; }
    return `M${3*s} ${10*s} L${12*s} ${3*s} L${21*s} ${10*s} L${21*s} ${21*s} L${15*s} ${21*s} L${15*s} ${14*s} L${9*s} ${14*s} L${9*s} ${21*s} L${3*s} ${21*s} Z`;
  }
  build() {
    Path().commands(this.path()).width(24).height(24).fillOpacity(0).stroke(this.tint)
      .strokeWidth(1.7).strokeLineCap(LineCapStyle.Round).strokeLineJoin(LineJoinStyle.Round)
  }
}
@ComponentV2
export struct BottomNav {
  @Param active: string = 'Home';
  @Event onNavigate: (route: string) => void = () => {};
  @Builder
  tab(label: string, route: string) {
    Column({ space: 3 }) {
      Stack() {
        NavGlyph({ route: route, tint: this.active === route ? Colors.green : Colors.muted })
      }.width(49).height(28).borderRadius(14).backgroundColor(this.active === route ? Colors.soft : '#00000000')
      Text(label).fontSize(11).fontWeight(this.active === route ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.active === route ? Colors.green : Colors.muted)
    }.layoutWeight(1).constraintSize({ minHeight: 50 }).justifyContent(FlexAlign.Center).onClick(() => this.onNavigate(route))
      .accessibilityText(label).accessibilitySelected(this.active === route)
  }
  build() {
    Row({ space: 6 }) {
      this.tab('广场', 'Home')
      this.tab('统计', 'Statistics')
      Row({ space: 2 }) {
        NavGlyph({ route: 'Publish', tint: '#FFFFFF' }).accessibilityLevel('no')
        Text('发布').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
      }.layoutWeight(1).constraintSize({ minHeight: 44 }).backgroundColor(Colors.green).borderRadius(14)
        .justifyContent(FlexAlign.Center).onClick(() => this.onNavigate('Publish')).accessibilityText('发布启事')
      this.tab('我的', 'My')
    }.width('100%').padding({ left: 12, right: 12, top: 5, bottom: 7 })
      .backgroundColor(Colors.surface).border({ width: { top: 1 }, color: Colors.stroke })
  }
}
