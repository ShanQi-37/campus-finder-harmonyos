import { Colors } from './Common';
@ComponentV2
export struct TaskTile {
  @Param label: string = '';
  @Param value: string = '0';
  @Param failed: boolean = false;
  @Event onOpen: () => void = () => {};
  build() {
    Column({ space: 4 }) {
      Text(this.failed ? '—' : this.value).fontSize(23).fontWeight(FontWeight.Bold).fontColor(Colors.greenDeep)
      Text(this.label).fontSize(12).fontColor(Colors.ink).textAlign(TextAlign.Center)
    }.width('100%').constraintSize({ minHeight: 68 }).padding({ left: 6, right: 6, top: 7, bottom: 7 })
      .justifyContent(FlexAlign.Center).backgroundColor(Colors.surface).borderRadius(12)
      .border({ width: 1, color: Colors.stroke }).onClick(() => this.onOpen())
      .accessibilityText(this.label + '，' + (this.failed ? '数量暂不可用' : this.value))
  }
}
