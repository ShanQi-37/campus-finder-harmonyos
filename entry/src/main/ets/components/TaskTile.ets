import { Colors } from './Common';
@ComponentV2
export struct TaskTile {
  @Param label: string = '';
  @Param value: string = '0';
  @Param failed: boolean = false;
  @Event onOpen: () => void = () => {};
  build() {
    Column({ space: 5 }) {
      Text(this.failed ? '—' : this.value).fontSize(23).fontWeight(FontWeight.Bold).fontColor(Colors.green)
      Text(this.label + ' ›').fontSize(11).fontColor(Colors.muted)
    }.width('100%').height(72).justifyContent(FlexAlign.Center).backgroundColor('#FFFFFF').borderRadius(15).onClick(() => this.onOpen())
  }
}
