import { common } from '@kit.AbilityKit';
import { Item, ClaimInput, PhotoCandidate, emptyItem } from '../model/Models';
import { Api } from '../service/Api';
import { MediaPicker } from '../service/MediaPicker';
import { categoryArt, Colors, ItemThumb, PageHeader, StatePanel, AmbientBackground } from '../components/Common';

@ComponentV2
export struct ClaimFormPage {
  @Local item: Item = emptyItem();
  @Local proof: string = '';
  @Local contact: string = '校园服务台留言（虚构）';
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local issue: string = '';
  @Local busy: boolean = false;
  @Local evidenceId: string = '';
  @Local evidenceType: string = '';
  @Local evidenceError: string = '';
  @Local uploadingEvidence: boolean = false;
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

  async addEvidence(video: boolean): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    this.uploadingEvidence = true;
    this.evidenceError = '';
    try {
      const bytes = await MediaPicker.choose(this.getUIContext().getHostContext() as common.UIAbilityContext, video, true);
      if (bytes === null || !this.active) { return; }
      const attachment = await Api.uploadClaimEvidence(this.itemId, video ? 'video' : 'photo', bytes);
      if (this.active) {
        this.evidenceId = attachment.id;
        this.evidenceType = attachment.type;
      }
    } catch (error) {
      if (this.active) { this.evidenceError = (error as Error).message || '附件上传失败，请重试'; }
    } finally {
      this.uploadingEvidence = false;
      this.busy = false;
    }
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
    const input: ClaimInput = { proof: this.proof, contact: this.contact, photoSearchId: this.photoSearchId,
      evidenceId: this.evidenceId || undefined };
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
      ItemThumb({ item: this.item, w: 59, h: 64, radius: 12 })
      Column({ space: 5 }) {
        Text(this.item.kind === 'found' ? '招领启事' : '寻物启事').fontSize(11).fontColor(Colors.muted)
        Text(this.item.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.item.location).fontSize(12).fontColor(Colors.muted).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').padding(11).backgroundColor(Colors.glass).borderRadius(15)
      .border({ width: 1, color: Colors.glassStroke })
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
      if (this.item.kind === 'found') {
        this.evidenceFields()
      }
      Row({ space: 8 }) {
        Text('联系指引').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.ink).layoutWeight(1)
        Text('仅申请双方可见').fontSize(11).fontColor(Colors.muted)
      }.width('100%')
      TextInput({ text: this.contact, placeholder: '例如：校园服务台留言' }).constraintSize({ minHeight: 46 }).fontSize(14)
        .maxLength(60).backgroundColor(Colors.paper).borderRadius(10).enterKeyType(EnterKeyType.Done)
        .border({ width: 1, color: this.issue === 'contact' ? Colors.red : Colors.stroke })
        .accessibilityText('联系指引').onChange((value: string) => { this.contact = value; this.clearIssue('contact'); })
    }.width('100%').padding(14).backgroundColor(Colors.glass).borderRadius(15)
      .border({ width: 1, color: Colors.glassStroke })
  }

  @Builder
  evidenceFields() {
    Column({ space: 7 }) {
      Text('核对附件（选填）').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
      Text('可提供一张物品旧照或一段短视频，仅申请双方可见。')
        .fontSize(12).fontColor(Colors.muted).lineHeight(19).width('100%')
      Row({ space: 8 }) {
        Button('选图片').constraintSize({ minHeight: 40 }).fontSize(13).fontColor(Colors.green)
          .backgroundColor(Colors.surface).layoutWeight(1).onClick(() => { this.addEvidence(false); })
        Button('选视频').constraintSize({ minHeight: 40 }).fontSize(13).fontColor(Colors.green)
          .backgroundColor(Colors.surface).layoutWeight(1).onClick(() => { this.addEvidence(true); })
      }.width('100%')
      if (this.uploadingEvidence) {
        Text('正在添加附件…').fontSize(12).fontColor(Colors.muted).width('100%')
      }
      if (this.evidenceId.length) {
        Row({ space: 8 }) {
          Text(this.evidenceType === 'video' ? '已添加短视频' : '已添加图片')
            .fontSize(12).fontColor(Colors.ink).layoutWeight(1)
          Button('移除').constraintSize({ minHeight: 36 }).fontSize(12).fontColor(Colors.red)
            .backgroundColor(Colors.surface).onClick(() => {
              this.evidenceId = '';
              this.evidenceType = '';
              this.evidenceError = '';
            })
        }.width('100%')
      }
      if (this.evidenceError.length) {
        Text(this.evidenceError).fontSize(12).fontColor(Colors.red).width('100%')
      }
    }.width('100%').padding(10).backgroundColor(Colors.soft).borderRadius(10)
  }

  build() {
    NavDestination() {
      Stack() {
        AmbientBackground()
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
            Button(this.uploadingEvidence ? '正在添加附件…' : (this.busy ? '正在提交…' :
              (this.item.kind === 'found' ? '提交认领申请' : '提交寻物线索')))
              .constraintSize({ minHeight: 46 }).fontSize(14).fontWeight(FontWeight.Bold).width('100%')
              .fontColor('#FFFFFF').backgroundColor(Colors.greenDeep)
              .enabled(!this.busy).onClick(() => { this.submit(); })
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 12 }).backgroundColor(Colors.surface)
            .border({ width: { top: 1 }, color: Colors.stroke })
        }
        }.width('100%').height('100%')
      }.width('100%').height('100%')
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
