import { Colors } from './Common';
@ComponentV2
export struct TaskTile {
  @Param label: string = '';
  @Param value: string = '0';
  @Param failed: boolean = false;
  @Event onOpen: () => void = () => {};
  build() {
    Row({ space: 6 }) {
      Text(this.failed ? '—' : this.value).fontSize(22).fontWeight(FontWeight.Bold).fontColor(Colors.green)
      Text(this.label).fontSize(12).fontColor(Colors.ink).maxLines(1).layoutWeight(1)
      Text('›').fontSize(19).fontColor(Colors.muted).accessibilityLevel('no')
    }.width('100%').height(52).padding({ left: 10, right: 8 }).backgroundColor(Colors.surface).borderRadius(13)
      .border({ width: 1, color: Colors.stroke }).onClick(() => this.onOpen())
      .accessibilityText(this.label + '，' + (this.failed ? '数量暂不可用' : this.value))
  }
}
