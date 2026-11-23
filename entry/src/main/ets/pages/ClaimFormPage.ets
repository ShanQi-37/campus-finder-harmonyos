import { Item, ClaimInput, PhotoCandidate, emptyItem } from '../model/Models';
import { Api } from '../service/Api';
import { categoryArt, Colors, PageHeader, StatePanel } from '../components/Common';

@ComponentV2
export struct ClaimFormPage {
  @Local item: Item = emptyItem();
  @Local proof: string = '';
  @Local contact: string = '校园服务台留言（虚构）';
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local issue: string = '';
  @Local busy: boolean = false;
  private stack: NavPathStack = new NavPathStack();
  private itemId: string = '';
  private photoSearchId?: string;
  private active: boolean = true;

  async load(): Promise<void> {
    this.phase = 'loading';
    this.error = '';
    try {
      const item = await Api.detail(this.itemId);
      if (this.active) { this.item = item; this.phase = 'ready'; }
    } catch (error) {
      if (this.active) { this.phase = 'error'; this.error = (error as Error).message; }
    }
  }

  clearIssue(field: string): void {
    if (this.issue === field) { this.issue = ''; this.error = ''; }
  }

  fillExample(): void {
    this.proof = this.item.kind === 'found'
      ? '我可以说明物品的独特标记，并在校园服务台当面出示证明。这是一份虚构的认领申请。'
      : '我在校园服务台看到类似物品，可携带特征说明前往核实。这是一条虚构的寻物线索。';
    this.clearIssue('proof');
  }

  offerExample(): void {
    if (!this.proof.trim()) { this.fillExample(); return; }
    this.getUIContext().showAlertDialog({
      title: '替换核对说明？',
      message: '虚构示例会替换已填写的核对说明。',
      primaryButton: { value: '保留现有内容', action: () => {} },
      secondaryButton: { value: '填入示例', action: () => this.fillExample() }
    });
  }

  async submit(): Promise<void> {
    if (this.busy) { return; }
    if (this.proof.trim().length < 8) {
      this.issue = 'proof';
      this.error = '核对说明至少填写 8 个字。';
      return;
    }
    if (this.contact.trim().length < 2) {
      this.issue = 'contact';
      this.error = '联系指引至少填写 2 个字。';
      return;
    }
    this.busy = true;
    this.issue = '';
    this.error = '';
    const input: ClaimInput = { proof: this.proof, contact: this.contact, photoSearchId: this.photoSearchId };
    try {
      await Api.claim(this.itemId, input);
      if (this.active) { this.stack.pop({ changed: true }); }
    } catch (error) {
      if (this.active) { this.error = (error as Error).message; }
    } finally {
      this.busy = false;
    }
  }

  back(): void { if (!this.busy) { this.stack.pop(); } }

  @Builder
  itemSummary() {
    Row({ space: 10 }) {
      Image(categoryArt(this.item.category)).width(59).height(64).objectFit(ImageFit.Contain)
        .backgroundColor(Colors.soft).borderRadius(12).accessibilityLevel('no')
      Column({ space: 5 }) {
        Text(this.item.kind === 'found' ? '招领启事' : '寻物启事').fontSize(11).fontColor(Colors.muted)
        Text(this.item.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.item.location).fontSize(12).fontColor(Colors.muted).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').padding(11).backgroundColor(Colors.surface).borderRadius(15)
      .border({ width: 1, color: Colors.stroke })
  }

  @Builder
  inputFields() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text('核对说明').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
          Text(this.proof.length + ' / 240 字').fontSize(11).fontColor(Colors.muted)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button('填入虚构示例').constraintSize({ minHeight: 38 }).fontSize(12).fontColor(Colors.green)
          .backgroundColor(Colors.soft).onClick(() => this.offerExample())
      }.width('100%')
      TextArea({ text: this.proof, placeholder: this.item.kind === 'found'
        ? '描述能证明归属的特征，例如外壳标记或配对记录' : '说明发现的地点、时间或可供核对的特征' })
        .height(114).fontSize(14).maxLength(240).backgroundColor(Colors.paper).borderRadius(10)
        .border({ width: 1, color: this.issue === 'proof' ? Colors.red : Colors.stroke })
        .accessibilityText('核对说明').onChange((value: string) => { this.proof = value; this.clearIssue('proof'); })
      Row({ space: 8 }) {
        Text('联系指引').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.ink).layoutWeight(1)
        Text('仅申请双方可见').fontSize(11).fontColor(Colors.muted)
      }.width('100%')
      TextInput({ text: this.contact, placeholder: '例如：校园服务台留言' }).constraintSize({ minHeight: 46 }).fontSize(14)
        .maxLength(60).backgroundColor(Colors.paper).borderRadius(10).enterKeyType(EnterKeyType.Done)
        .border({ width: 1, color: this.issue === 'contact' ? Colors.red : Colors.stroke })
        .accessibilityText('联系指引').onChange((value: string) => { this.contact = value; this.clearIssue('contact'); })
    }.width('100%').padding(14).backgroundColor(Colors.surface).borderRadius(15)
      .border({ width: 1, color: Colors.stroke })
  }

  build() {
    NavDestination() {
      Column({ space: 8 }) {
        PageHeader({ title: this.phase !== 'ready' ? '申请与核对' : (this.item.kind === 'found' ? '申请认领' : '提供线索'),
          back: true, onBack: () => this.back() })
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, onRetry: () => { this.load(); } }).layoutWeight(1)
        } else {
          Scroll() {
            Column({ space: 10 }) {
              this.itemSummary()
              this.inputFields()
              Column({ space: 5 }) {
                Text('提交后等待发布者核对').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
                Text('在「我的校园」的「我的申请」查看结果。联系指引可填写校内交接方式，请勿提供密码或完整证件号码。')
                  .fontSize(12).fontColor(Colors.muted).lineHeight(20).width('100%')
              }.width('100%').padding(12).backgroundColor(Colors.soft).borderRadius(13)
            }.width('100%').padding({ left: 16, right: 16, bottom: 16 })
          }.width('100%').layoutWeight(1).enabled(!this.busy).scrollBar(BarState.Auto).align(Alignment.Top)
          Column({ space: 7 }) {
            if (this.error.length) { Text(this.error).fontSize(12).fontColor(Colors.red).width('100%') }
            Button(this.busy ? '正在提交…' : (this.item.kind === 'found' ? '提交认领申请' : '提交寻物线索'))
              .constraintSize({ minHeight: 46 }).fontSize(14).fontWeight(FontWeight.Bold).width('100%').backgroundColor(Colors.green)
              .enabled(!this.busy).onClick(() => { this.submit(); })
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 12 }).backgroundColor(Colors.surface)
            .border({ width: { top: 1 }, color: Colors.stroke })
        }
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
      const param = context.pathInfo.param as string | PhotoCandidate;
      if (typeof param === 'string') {
        this.itemId = param;
      } else {
        this.itemId = param.itemId;
        this.photoSearchId = param.searchId;
      }
      this.load();
    }).onBackPressed(() => { this.back(); return true; }).onDisAppear(() => { this.active = false; })
  }
}
