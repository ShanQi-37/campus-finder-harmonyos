import { CountPoint, Statistics, emptyStatistics } from '../model/Models';
import { Colors } from './Common';
@ComponentV2
export struct CategoryChart {
  @Param points: CountPoint[] = [];
  @Local selected: string = '';
  maxCount(): number { return Math.max(1, ...this.points.map((p: CountPoint) => p.count)); }
  build() {
    Column({ space: 15 }) {
      Row() { Text('物品类别分布').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Colors.ink); Blank(); Text('单位：条').fontSize(11).fontColor(Colors.muted) }.width('100%')
      ForEach(this.points, (point: CountPoint) => {
        Column({ space: 7 }) {
          Row() { Text(point.label).fontSize(13).fontColor(Colors.ink); Blank(); Text(point.count.toString()).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.green) }.width('100%')
          Stack({ alignContent: Alignment.Start }) {
            Rect().width('100%').height(12).fill('#EAF0E6').radius(6)
            Rect().width((point.count / this.maxCount() * 100) + '%').height(12).fill(this.selected === point.label ? Colors.gold : '#62937A').radius(6)
          }.width('100%').height(12)
        }.width('100%').onClick(() => { this.selected = point.label; }).accessibilityText(point.label + ' ' + point.count + '条')
      }, (point: CountPoint) => point.label)
      Text(this.selected.length ? '已选中：' + this.selected : '点击类别可高亮查看').fontSize(11).fontColor(Colors.muted).width('100%')
    }.width('100%').padding(20).backgroundColor('#FFFFFF').borderRadius(20)
  }
}
@ComponentV2
export struct TrendChart {
  @Param points: CountPoint[] = [];
  @Local chartWidth: number = 270;
  coordinates(): number[][] {
    const max = Math.max(1, ...this.points.map((p: CountPoint) => p.count));
    return this.points.map((p: CountPoint, index: number) => [24 + index * (this.chartWidth - 48) / Math.max(1, this.points.length - 1), 110 - p.count / max * 90]);
  }
  build() {
    Column({ space: 14 }) {
      Row() { Text('近' + this.points.length + '日发布趋势').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Colors.ink); Blank(); Text('单位：条').fontSize(11).fontColor(Colors.muted) }.width('100%')
      Text('单日峰值 ' + Math.max(0, ...this.points.map((p: CountPoint) => p.count)) + ' 条 · 区间合计 ' + this.points.reduce((sum: number, p: CountPoint) => sum + p.count, 0) + ' 条').fontSize(11).fontColor(Colors.green).width('100%')
      Stack({ alignContent: Alignment.TopStart }) {
        Column() { Divider().color('#EFF2EA'); Blank(); Divider().color('#EFF2EA'); Blank(); Divider().color('#D5DECE') }.height(110).width('100%')
        Polyline().points(this.coordinates()).stroke('#447C60').strokeWidth(3).fillOpacity(0).width('100%').height(120)
        Text(Math.max(1, ...this.points.map((p: CountPoint) => p.count)).toString()).fontSize(9).fontColor(Colors.muted).position({ x: 0, y: 15 })
        Text('0').fontSize(9).fontColor(Colors.muted).position({ x: 0, y: 103 })
      }.width('100%').height(120).onAreaChange((_oldArea: Area, newArea: Area) => { this.chartWidth = Number(newArea.width); })
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(this.points, (p: CountPoint, index: number) => {
          if (index === 0 || index === this.points.length - 1 || (index % Math.ceil(this.points.length / 4) === 0 && index < this.points.length - 2)) {
            Text(p.label).fontSize(9).fontColor(Colors.muted).width(42).height(16).textAlign(TextAlign.Center)
              .position({ x: 24 + index * (this.chartWidth - 48) / Math.max(1, this.points.length - 1) - 21, y: 0 })
          }
        }, (p: CountPoint) => p.label)
      }.width('100%').height(16)
      Text('横轴：日期 · 纵轴：有效启事数量').fontSize(11).fontColor(Colors.muted).width('100%')
    }.width('100%').padding(20).backgroundColor('#FFFFFF').borderRadius(20)
  }
}
@ComponentV2
export struct RecoveryChart {
  @Param data: Statistics = emptyStatistics();
  build() {
    Column({ space: 18 }) {
      Text('寻回进度').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
      Row({ space: 22 }) {
        Stack() {
          DataPanel({ values: [this.data.resolved], max: Math.max(1, this.data.total), type: DataPanelType.Circle })
            .width(140).height(140).valueColors(['#447C60']).trackBackgroundColor('#EAF0E6').strokeWidth(12).closeEffect(true)
          Column({ space: 5 }) {
            Text(this.data.recoveryRate + '%').fontSize(28).fontWeight(FontWeight.Bold).fontColor(Colors.green)
            Text('总体寻回率').fontSize(11).fontColor(Colors.muted)
          }
        }
        Column({ space: 16 }) {
          Text('已寻回  ' + this.data.resolved + ' 条').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.green)
          Text('待寻回  ' + this.data.open + ' 条').fontSize(13).fontColor(Colors.muted)
          Text('寻回率 = 已寻回 / 有效启事').fontSize(10).fontColor(Colors.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
    }.width('100%').padding(20).backgroundColor('#FFFFFF').borderRadius(20)
  }
}
