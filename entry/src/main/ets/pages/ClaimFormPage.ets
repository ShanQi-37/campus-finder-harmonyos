import { Item, ClaimInput, emptyItem } from '../model/Models';
import { Api } from '../service/Api';
import { categoryArt, Colors, PageHeader, StatePanel } from '../components/Common';
@ComponentV2
export struct ClaimFormPage {
  @Local item: Item = emptyItem();
  @Local proof: string = '';
  @Local contact: string = '校园服务台留言（虚构）';
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local busy: boolean = false;
  private stack: NavPathStack = new NavPathStack();
  private itemId: string = '';
  private active: boolean = true;
  async load(): Promise<void> {
    this.phase = 'loading';
    try { const item = await Api.detail(this.itemId); if (this.active) { this.item = item; this.phase = 'ready'; } }
    catch (error) { if (this.active) { this.phase = 'error'; this.error = (error as Error).message; } }
  }
  async submit(): Promise<void> {
    if (this.busy) { return; }
    if (this.proof.trim().length < 8 || this.contact.trim().length < 2) { this.error = '请填写至少8字的核对说明和联系指引。'; return; }
    this.busy = true; this.error = '';
    const input: ClaimInput = { proof: this.proof, contact: this.contact };
    try { await Api.claim(this.itemId, input); if (this.active) { this.stack.pop({ changed: true }); } }
    catch (error) { if (this.active) { this.error = (error as Error).message; } }
    finally { if (this.active) { this.busy = false; } }
  }
  back(): void { if (!this.busy) { this.stack.pop(); } }
  build() {
    NavDestination() {
      Column({ space: 12 }) {
        PageHeader({ title: this.item.kind === 'found' ? '申请认领' : '提供线索', subtitle: '先核实特征，再安心交接', back: true, onBack: () => this.back() })
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, onRetry: () => { this.load(); } }).layoutWeight(1)
        } else {
          Row({ space: 13 }) {
            Image(categoryArt(this.item.category)).width(62).height(70).objectFit(ImageFit.Contain)
            Column({ space: 7 }) { Text(this.item.title).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(2); Text(this.item.location).fontSize(11).fontColor(Colors.muted) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('90%').padding(12).backgroundColor('#E8EFE1').borderRadius(18)
          Scroll() {
            Column({ space: 12 }) {
              Row() {
                Text('核对说明 / 8–240字').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Colors.ink).layoutWeight(1)
                Button('虚构示例').height(28).fontSize(10).fontColor(Colors.green).backgroundColor(Colors.soft).onClick(() => { this.proof = this.item.kind === 'found' ? '我可以描述物品的独特标记，并到校园服务台当面出示证明。这是虚构的课程演示申请。' : '我在校园服务台看到类似物品，建议携带特征说明前往核实。这是虚构的课程演示线索。'; this.error = ''; })
              }.width('100%')
              TextArea({ text: this.proof, placeholder: '描述未公开的特征、购买或配对证明；请勿填写密码' }).height(132).fontSize(13).maxLength(240).backgroundColor('#FFFFFF').onChange((value: string) => { this.proof = value; })
              Text('联系指引 / 仅申请双方可见').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
              TextInput({ text: this.contact }).height(42).fontSize(13).maxLength(60).backgroundColor('#FFFFFF').onChange((value: string) => { this.contact = value; })
              Text('提交 → 发布者核对 → 当面交接 → 确认寻回\n申请结果可在“我的 · 认领与线索中心”查看。').fontSize(11).lineHeight(20).fontColor('#937B4D').padding(14).backgroundColor('#FFF5E2').borderRadius(14).width('100%')
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.layoutWeight(1).enabled(!this.busy).scrollBar(BarState.Auto).align(Alignment.Top)
          Column({ space: 8 }) {
            if (this.error.length) { Text(this.error).fontSize(12).fontColor(Colors.red).width('100%') }
            Button(this.busy ? '正在提交…' : '提交，等待核对').height(46).fontSize(14).width('100%').backgroundColor(Colors.green).enabled(!this.busy).onClick(() => { this.submit(); })
          }.width('100%').padding({ left: 18, right: 18, top: 10, bottom: 20 }).backgroundColor('#FFFFFF')
        }
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; this.itemId = context.pathInfo.param as string; this.load(); })
      .onBackPressed(() => { this.back(); return true; }).onDisAppear(() => { this.active = false; })
  }
}
