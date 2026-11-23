import { CountPoint, Statistics, TrendPoint, emptyStatistics } from '../model/Models';
import { Colors } from './Common';
@ComponentV2
export struct CategoryChart {
  @Param points: CountPoint[] = [];
  @Param title: string = '物品类别分布';
  @Param unit: string = '条';
  @Local selected: string = '';
  maxCount(): number { return Math.max(1, ...this.points.map((p: CountPoint) => p.count)); }
  build() {
    Column({ space: 15 }) {
      Row({ space: 8 }) {
        Text(this.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(Colors.ink).layoutWeight(1)
        Text('单位：' + this.unit).fontSize(11).fontColor(Colors.muted)
      }.width('100%')
      ForEach(this.points, (point: CountPoint) => {
        Column({ space: 7 }) {
          Row() { Text(point.label).fontSize(13).fontColor(Colors.ink); Blank(); Text(point.count.toString()).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.green) }.width('100%')
          Stack({ alignContent: Alignment.Start }) {
            Rect().width('100%').height(12).fill('#EAF0E6').radius(6)
            Rect().width((point.count / this.maxCount() * 100) + '%').height(12).fill(this.selected === point.label ? Colors.gold : '#62937A').radius(6)
          }.width('100%').height(12)
        }.width('100%').onClick(() => { this.selected = point.label; })
          .accessibilityText(point.label + ' ' + point.count + this.unit)
      }, (point: CountPoint) => point.label)
      if (this.selected.length) {
        Text('已选中 ' + this.selected).fontSize(12).fontColor(Colors.ink).width('100%')
      }
    }.width('100%').padding(16).backgroundColor(Colors.surface).borderRadius(16)
      .border({ width: 1, color: Colors.stroke })
  }
}
@ComponentV2
export struct TrendChart {
  @Param points: TrendPoint[] = [];
  @Param selectedDay: number = 0;
  @Param recovery: boolean = false;
  @Param undatedResolved: number = 0;
  @Event onSelectDay: (day: number) => void = () => {};
  @Event onBrowseDay: (index: number) => void = () => {};
  @Local chartWidth: number = 270;
  maxCount(): number { return Math.max(1, ...this.points.map((point: TrendPoint) => point.count)); }
  dayIndex(): number {
    return this.selectedDay === 0 ? this.points.length - 1 : Math.min(this.selectedDay, this.points.length) - 1;
  }
  dateX(index: number): number {
    return 24 + index * Math.max(0, this.chartWidth - 48) / Math.max(1, this.points.length - 1);
  }
  showDateLabel(index: number): boolean {
    const last = this.points.length - 1;
    if (index === 0 || index === last) { return true; }
    const segments = Math.min(last, Math.max(1, Math.floor((this.chartWidth - 48) / 54)));
    for (let i = 1; i < segments; i++) {
      if (index === Math.round(i * last / segments)) { return true; }
    }
    return false;
  }
  countY(count: number, max: number): number {
    return 110 - count / max * 90;
  }
  coordinates(resolved: boolean): number[][] {
    const max = this.maxCount();
    return this.points.map((point: TrendPoint, index: number) =>
      [this.dateX(index), this.countY(resolved ? point.resolved : point.count, max)]);
  }
  build() {
    Column({ space: 14 }) {
      Row() {
        Text(this.recovery ? this.points.length + '日确认寻回' : this.points.length + '日发布与寻回')
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Colors.ink).layoutWeight(1)
        Text('单位：条').fontSize(11).fontColor(Colors.muted)
      }.width('100%')
      Column({ space: 4 }) {
        Text((this.recovery ? '━ 实际确认寻回 ' : '━ 有效启事 ') +
          this.points.reduce((sum: number, point: TrendPoint) => sum + point.count, 0)).fontSize(11).fontColor('#31654C')
        if (!this.recovery) {
          Text('━ 其中已寻回 ' + this.points.reduce((sum: number, point: TrendPoint) => sum + point.resolved, 0)).fontSize(11).fontColor('#8D5917')
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
      Stack({ alignContent: Alignment.TopStart }) {
        Column() { Divider().color('#EFF2EA'); Blank(); Divider().color('#EFF2EA'); Blank(); Divider().color('#D5DECE') }.height(90).width('100%').position({ x: 0, y: 20 })
        if (this.points.length > 0) {
          Divider().vertical(true).height(90).color('#C4D4C5').position({ x: this.dateX(this.dayIndex()), y: 20 })
        }
        Polyline().points(this.coordinates(false)).stroke('#447C60').strokeWidth(4).fillOpacity(0).width('100%').height(120)
        if (!this.recovery) {
          Polyline().points(this.coordinates(true)).stroke('#B57C2B').strokeWidth(2).fillOpacity(0).width('100%').height(120)
        }
        if (this.points.length > 0) {
          Circle().width(10).height(10).fill('#447C60')
            .position({ x: this.dateX(this.dayIndex()) - 5, y: this.countY(this.points[this.dayIndex()].count, this.maxCount()) - 5 })
          if (!this.recovery) {
            Circle().width(5).height(5).fill('#B57C2B')
              .position({ x: this.dateX(this.dayIndex()) - 2.5, y: this.countY(this.points[this.dayIndex()].resolved, this.maxCount()) - 2.5 })
          }
        }
        Text(this.maxCount().toString()).fontSize(9).fontColor(Colors.muted).position({ x: 0, y: 15 })
        Text('0').fontSize(9).fontColor(Colors.muted).position({ x: 0, y: 103 })
      }.width('100%').height(120).onAreaChange((_oldArea: Area, newArea: Area) => {
        const width = Number(newArea.width);
        if (width > 0) { this.chartWidth = width; }
      })
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(this.points, (p: TrendPoint, index: number) => {
          if (this.showDateLabel(index)) {
            Text(p.label).fontSize(9).fontColor(Colors.muted).width(42).height(16).textAlign(TextAlign.Center)
              .position({ x: this.dateX(index) - 21, y: 0 })
          }
        }, (p: TrendPoint, index: number) => p.label + ':' + index)
      }.width('100%').height(16)
      if (this.points.length > 0) {
        Column({ space: 5 }) {
          Column({ space: 6 }) {
            Text(this.points[this.dayIndex()].label + (this.recovery ? ' 确认寻回' : ' 发布')).fontSize(14).fontWeight(FontWeight.Bold)
              .fontColor(Colors.ink).width('100%')
            Button('查看当日启事 ›').constraintSize({ minHeight: 40 }).width('100%').fontSize(12)
              .fontColor(Colors.green).backgroundColor(Colors.surface)
              .enabled(this.points[this.dayIndex()].count > 0).onClick(() => this.onBrowseDay(this.dayIndex()))
          }.width('100%')
          Text(this.recovery ? '实际确认寻回 ' + this.points[this.dayIndex()].count + ' 条' :
            '有效启事 ' + this.points[this.dayIndex()].count + ' 条 · 其中已寻回 ' + this.points[this.dayIndex()].resolved + ' 条')
            .fontSize(12).fontColor(Colors.ink).width('100%')
          if (this.points.length > 1) {
            Slider({ value: this.dayIndex() + 1, min: 1, max: this.points.length, step: 1 })
              .selectedColor('#447C60').width('100%').height(44)
              .accessibilityText(this.recovery ? '选择确认寻回日期' : '选择发布日期').accessibilityDescription(this.points[this.dayIndex()].label)
              .onChange((value: number) => this.onSelectDay(Math.round(value)))
          }
        }.width('100%').backgroundColor('#F1F5EF').borderRadius(12).padding({ left: 12, right: 12, top: 8, bottom: 3 })
      }
      Text(this.recovery ? '横轴为发布者实际确认寻回的上海日期。' : '横轴为发布日期。已寻回按启事当前状态统计。')
        .fontSize(11).fontColor(Colors.muted).width('100%')
      if (this.recovery) {
        Text(this.undatedResolved > 0 ?
          '另有 ' + this.undatedResolved + ' 条已寻回旧记录缺少可靠确认日期，仍计入寻回总览，不计入本趋势与单日明细。' :
          '仅统计具有可靠确认时间或交接动态的记录。')
          .fontSize(11).fontColor(this.undatedResolved > 0 ? '#8D5917' : Colors.muted).lineHeight(17).width('100%')
      }
    }.width('100%').padding(16).backgroundColor(Colors.surface).borderRadius(16)
      .border({ width: 1, color: Colors.stroke })
  }
}
@ComponentV2
export struct RecoveryChart {
  @Param data: Statistics = emptyStatistics();
  build() {
    Column({ space: 12 }) {
      Text('寻回率').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
      Row({ space: 15 }) {
        Stack() {
          DataPanel({ values: [this.data.resolved], max: Math.max(1, this.data.total), type: DataPanelType.Circle })
            .width(112).height(112).valueColors(['#447C60']).trackBackgroundColor('#EAF0E6').strokeWidth(10).closeEffect(true)
          Column({ space: 3 }) {
            Text(this.data.recoveryRate + '%').fontSize(28).fontWeight(FontWeight.Bold).fontColor(Colors.green)
          }
        }
        Column({ space: 8 }) {
          Text('已寻回  ' + this.data.resolved + ' 条').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.green)
          Text('待寻回  ' + this.data.open + ' 条').fontSize(13).fontColor(Colors.muted)
          Text('已寻回 ÷ 有效启事').fontSize(11).fontColor(Colors.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
    }.width('100%').padding(16).backgroundColor(Colors.surface).borderRadius(16)
      .border({ width: 1, color: Colors.stroke })
  }
}
