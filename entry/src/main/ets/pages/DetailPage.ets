import { Item, emptyItem } from '../model/Models';
import { Api } from '../service/Api';
import { Colors, PageHeader, StatePanel } from '../components/Common';
@ComponentV2
export struct DetailPage {
  @Local item: Item = emptyItem();
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local contactVisible: boolean = false;
  @Local busy: boolean = false;
  private stack: NavPathStack = new NavPathStack();
  private itemId: string = '';
  private changed: boolean = false;
  private active: boolean = true;
  async load(): Promise<void> {
    this.phase = 'loading';
    try { const result = await Api.detail(this.itemId); if (this.active) { this.item = result; this.phase = 'ready'; } }
    catch (error) { if (this.active) { this.error = (error as Error).message; this.phase = 'error'; } }
  }
  async resolve(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true; this.error = '';
    try { this.item = await Api.resolve(this.itemId); this.changed = true; }
    catch (error) { this.error = (error as Error).message; }
    finally { this.busy = false; }
  }
  back(): void { this.stack.pop({ changed: this.changed }); }
  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '物品详情', subtitle: '留意线索，认真核对', back: true, onBack: () => this.back() })
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, onRetry: () => { this.load(); } })
        } else {
          Scroll() {
            Column({ space: 20 }) {
              Stack() {
                Column({ space: 12 }) {
                  Text(this.item.category.slice(0, 2)).fontSize(48).fontWeight(FontWeight.Bold).fontColor(Colors.green)
                  Text(this.item.category).fontSize(13).fontColor(Colors.green)
                }
              }.width('100%').height(180).backgroundColor('#E6EDDE').borderRadius(24)
              Row({ space: 8 }) {
                Text(this.item.kind === 'found' ? '拾物招领' : '寻物启事').fontSize(12).fontColor(Colors.green).backgroundColor(Colors.soft).padding(8).borderRadius(7)
                Text(this.item.status === 'resolved' ? '已寻回' : '待寻回').fontSize(12).fontColor('#A97D31')
                Blank()
                Text(this.item.occurredAt).fontSize(12).fontColor(Colors.muted)
              }.width('100%')
              Text(this.item.title).fontSize(23).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
              Column({ space: 16 }) {
                Text('地点  ·  ' + this.item.location).fontSize(14).fontColor(Colors.green).width('100%')
                Divider().color('#E6EAE1')
                Text('物品描述').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
                Text(this.item.description).fontSize(15).lineHeight(25).fontColor('#56685C').width('100%')
              }.padding(20).width('100%').backgroundColor('#FFFFFF').borderRadius(18)
              if (this.item.status === 'resolved') {
                Text('这份遗失已画上句号，感谢校园里的善意。').fontSize(14).fontColor(Colors.green).width('100%')
              } else {
                Button(this.contactVisible ? '已展开联系指引' : '查看联系指引').width('100%').height(48).backgroundColor(Colors.green).onClick(() => { this.contactVisible = !this.contactVisible; })
                if (this.contactVisible) {
                  Text(this.item.contact + '\n请先说明物品特征，再到校园服务台核实；不要公开证件号码和密码。').fontSize(14).lineHeight(24).fontColor(Colors.ink).width('100%')
                }
                if (this.item.owner === 'demo-user') {
                  Button(this.busy ? '正在确认…' : '确认已寻回').width('100%').height(46).fontColor(Colors.green).backgroundColor(Colors.soft).enabled(!this.busy)
                    .onClick(() => {
                      this.getUIContext().showAlertDialog({ title: '确认物品已寻回？', message: '核实并完成交接后，信息将标为已寻回，统计也会更新。',
                        primaryButton: { value: '再等等', action: () => {} }, secondaryButton: { value: '确认寻回', action: () => { this.resolve(); } } });
                    })
                }
              }
              if (this.error.length) { Text(this.error).fontSize(13).fontColor('#B54837').width('100%') }
              Text('校园演示数据 · 联系信息为虚构内容').fontSize(11).fontColor(Colors.muted).padding({ bottom: 15 })
            }.padding({ left: 20, right: 20 }).width('100%')
          }.layoutWeight(1).scrollBar(BarState.Off)
        }
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack; this.itemId = context.pathInfo.param as string; this.active = true; this.load();
    }).onBackPressed(() => { this.back(); return true; }).onDisAppear(() => { this.active = false; })
  }
}
