import { CATEGORIES, PublishInput } from '../model/Models';
import { Api } from '../service/Api';
import { categoryArt, ChoiceChip, Colors, PageHeader, StatePanel } from '../components/Common';
@ComponentV2
export struct PublishPage {
  @Local kind: string = 'lost';
  @Local category: string = '证件卡片';
  @Local title: string = '';
  @Local location: string = '';
  @Local description: string = '';
  @Local contact: string = '校园服务台转接（演示）';
  @Local occurredAt: string = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' });
  @Local busy: boolean = false;
  @Local error: string = '';
  @Local notice: string = '';
  @Local step: number = 1;
  @Local phase: string = 'loading';
  @Local editing: boolean = false;
  private itemId: string = '';
  private requestId: string = 'draft-' + Date.now() + '-' + Math.random().toString(36).slice(2);
  private stack: NavPathStack = new NavPathStack();
  private active: boolean = true;
  private baseline: string = '';
  input(): PublishInput { return { title: this.title, category: this.category, kind: this.kind, location: this.location, description: this.description, contact: this.contact, occurredAt: this.occurredAt, requestId: this.requestId }; }
  async load(): Promise<void> {
    this.phase = 'loading'; this.error = '';
    try {
      if (this.editing) {
        const item = await Api.detail(this.itemId); if (!this.active) { return; }
        this.kind = item.kind; this.category = item.category; this.title = item.title; this.location = item.location;
        this.description = item.description; this.contact = item.contact; this.occurredAt = item.occurredAt;
      } else {
        const draft = await Api.draft(); if (!this.active) { return; }
        const input = draft.input;
        if (draft.exists && input !== null) {
          this.kind = input.kind; this.category = input.category; this.title = input.title; this.location = input.location;
          this.description = input.description; this.contact = input.contact; this.occurredAt = input.occurredAt; this.requestId = input.requestId;
          this.notice = '已恢复草稿 · 可继续编辑后发布';
        }
      }
      this.baseline = JSON.stringify(this.input()); this.phase = 'ready';
    } catch (error) { if (this.active) { this.phase = 'error'; this.error = (error as Error).message; } }
  }
  example(): void {
    this.kind = 'lost'; this.category = '证件卡片'; this.title = '寻找蓝色校园卡套'; this.location = '图书馆一楼';
    this.description = '蓝色卡套，背面贴有白色贴纸；这是用于课程演示的虚构信息。'; this.contact = '校园服务台转接（演示）';
    this.occurredAt = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' }); this.error = ''; this.notice = '已填入虚构示例，可修改后使用'; this.step = 1;
  }
  back(): void {
    if (this.busy) { return; }
    if (this.step > 1) { this.step--; this.error = ''; return; }
    if (this.phase !== 'ready' || JSON.stringify(this.input()) === this.baseline) { this.stack.pop(); return; }
    this.getUIContext().showAlertDialog({ title: this.editing ? '修改还未保存' : '保存草稿，下次接着写？',
      message: this.editing ? '继续填写可保留当前内容；放弃后原启事保持原样。' : '草稿按当前体验身份保存在本机服务中，发布成功后自动移出草稿。',
      primaryButton: { value: '继续填写', action: () => {} },
      secondaryButton: { value: this.editing ? '放弃修改' : '保存并离开', action: () => { if (this.editing) { this.stack.pop(); } else { this.saveDraft(true); } } } });
  }
  async saveDraft(leave: boolean = false): Promise<void> {
    if (this.busy || this.editing) { return; } this.busy = true; this.error = ''; this.notice = '';
    try { await Api.saveDraft(this.input()); if (this.active) { this.baseline = JSON.stringify(this.input()); this.notice = '草稿已保存 · 可在我的校园中继续填写'; if (leave) { this.stack.pop({ changed: true }); } } }
    catch (error) { if (this.active) { this.error = (error as Error).message; } }
    finally { if (this.active) { this.busy = false; } }
  }
  validate(): boolean {
    if (this.title.trim().length < 2 || this.location.trim().length < 2 || this.description.trim().length < 8 || this.contact.trim().length < 2) { this.error = '请填全信息，物品描述至少 8 个字。'; return false; }
    const stamp = Date.parse(this.occurredAt);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(this.occurredAt) || !Number.isFinite(stamp) || new Date(stamp).toISOString().slice(0, 10) !== this.occurredAt || this.occurredAt > new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' })) { this.error = '请填写有效日期 YYYY-MM-DD，且不能晚于今天。'; return false; }
    return true;
  }
  next(): void {
    if (this.step === 1 && (this.title.trim().length < 2 || this.location.trim().length < 2)) { this.error = '标题和地点都至少填写 2 个字。'; return; }
    if (this.step === 2 && !this.validate()) { return; }
    this.error = ''; this.step++;
  }
  async submit(): Promise<void> {
    if (this.busy || !this.validate()) { return; } this.busy = true; this.error = '';
    try { await Api.publish(this.input(), this.itemId); if (this.active) { this.stack.pop({ changed: true, published: !this.editing }); } }
    catch (error) { if (this.active) { this.error = (error as Error).message; } }
    finally { if (this.active) { this.busy = false; } }
  }
  @Builder
  label(text: string) { Text(text).fontSize(13).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%') }
  @Builder
  stepLabel(index: number, label: string) {
    Column({ space: 6 }) {
      Text('0' + index + '  ' + label).fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.step === index ? Colors.green : Colors.muted)
      Rect().width('100%').height(3).radius(2).fill(this.step >= index ? Colors.green : '#DEE7DE')
    }.layoutWeight(1)
  }
  build() {
    NavDestination() {
      Column({ space: 12 }) {
        PageHeader({ title: this.editing ? '编辑启事' : '发布启事', subtitle: '把细节写清楚，让重逢少一些等待', back: true, onBack: () => this.back() })
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, onRetry: () => { this.load(); } }).layoutWeight(1)
        } else {
          Row({ space: 12 }) { this.stepLabel(1, '基本信息'); this.stepLabel(2, '补充线索'); this.stepLabel(3, '预览确认') }.width('100%').padding({ left: 18, right: 18 })
          if (!this.editing) {
            Row() {
              Text(this.notice.length ? this.notice : '暂时没写完？先保存草稿').fontSize(10).fontColor(Colors.green).maxLines(2).layoutWeight(1)
              Button('存草稿').fontSize(11).height(29).fontColor(Colors.green).backgroundColor(Colors.soft).onClick(() => { this.saveDraft(); })
            }.width('100%').padding({ left: 18, right: 18 }).enabled(!this.busy)
          }
          Scroll() {
            Column({ space: 12 }) {
              if (this.step === 1) {
                Row({ space: 10 }) {
                  ChoiceChip({ label: '我丢了 · 寻物', selected: this.kind === 'lost', onSelect: () => { this.kind = 'lost'; } })
                  ChoiceChip({ label: '我捡到 · 招领', selected: this.kind === 'found', onSelect: () => { this.kind = 'found'; } })
                }.width('100%')
                this.label('物品分类')
                Grid() { ForEach(CATEGORIES, (category: string) => { GridItem() { ChoiceChip({ label: category, selected: this.category === category, onSelect: () => { this.category = category; } }) } }, (category: string) => category) }.columnsTemplate('1fr 1fr').rowsGap(8).columnsGap(8).height(72).width('100%')
                this.label('标题 / 2–36字')
                TextInput({ placeholder: '例如：图书馆捡到校园卡', text: this.title }).height(42).fontSize(13).maxLength(36).backgroundColor('#FFFFFF').onChange((value: string) => { this.title = value; })
                this.label('遗失或拾取地点')
                TextInput({ placeholder: '请写明楼栋、楼层等线索', text: this.location }).height(42).fontSize(13).maxLength(30).backgroundColor('#FFFFFF').onChange((value: string) => { this.location = value; })
                if (!this.editing) { Text('填入一份虚构示例 ›').fontSize(12).fontColor(Colors.green).padding({ top: 6, bottom: 6 }).onClick(() => this.example()) }
              } else if (this.step === 2) {
                this.label('物品描述 / ' + this.description.length + ' / 300字')
                TextArea({ placeholder: '描述颜色、外观、特殊标记，至少8字', text: this.description }).height(105).fontSize(13).maxLength(300).backgroundColor('#FFFFFF').onChange((value: string) => { this.description = value; })
                this.label('联系指引 / 核对通过后对申请者可见')
                TextInput({ text: this.contact, placeholder: '建议通过校园服务台转接' }).height(42).fontSize(13).maxLength(60).backgroundColor('#FFFFFF').onChange((value: string) => { this.contact = value; })
                this.label('发生日期 / YYYY-MM-DD')
                TextInput({ text: this.occurredAt }).height(42).fontSize(13).maxLength(10).backgroundColor('#FFFFFF').onChange((value: string) => { this.occurredAt = value; })
                Text('请使用虚构演示内容，不填写完整证件号码、密码或付款信息。').fontSize(11).fontColor('#92703C').lineHeight(19).padding(12).backgroundColor('#FFF5E3').borderRadius(12)
              } else {
                Column({ space: 15 }) {
                  Row({ space: 12 }) {
                    Image(categoryArt(this.category)).width(65).height(75).objectFit(ImageFit.Contain).backgroundColor(Colors.soft).borderRadius(14)
                    Column({ space: 7 }) {
                      Text(this.kind === 'lost' ? '寻物启事 · ' + this.category : '拾物招领 · ' + this.category).fontSize(11).fontColor(Colors.green)
                      Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(2)
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  }.width('100%')
                  Divider().color('#E5EBE3')
                  Text(this.location + '  ·  ' + this.occurredAt).fontSize(12).fontColor(Colors.green).width('100%')
                  Text(this.description).fontSize(14).lineHeight(23).fontColor(Colors.ink).width('100%')
                  Text('联系指引（核对通过后开放）\n' + this.contact).fontSize(12).lineHeight(21).fontColor(Colors.muted).width('100%')
                }.width('100%').padding(18).backgroundColor('#FFFFFF').borderRadius(20)
                Text('确认物品特征和地点无误后提交。发布后可在“我的”中编辑、撤回或确认寻回。').fontSize(12).fontColor(Colors.muted).lineHeight(21).width('100%')
              }
            }.width('100%').padding({ left: 18, right: 18, bottom: 18 })
          }.layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top).enabled(!this.busy)
          Column({ space: 8 }) {
            if (this.error.length) { Text(this.error).fontColor(Colors.red).fontSize(12).width('100%') }
            Button(this.busy ? '正在保存…' : (this.step === 1 ? '下一步 · 补充线索' : (this.step === 2 ? '下一步 · 预览确认' : (this.editing ? '确认保存修改' : '确认发布到广场')))).width('100%').height(46).fontSize(14).backgroundColor(Colors.green).enabled(!this.busy)
              .onClick(() => { if (this.step < 3) { this.next(); } else { this.submit(); } })
          }.width('100%').padding({ left: 18, right: 18, top: 10, bottom: 20 }).backgroundColor('#FFFFFF')
        }
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; this.itemId = context.pathInfo.param as string; this.editing = this.itemId.length > 0; this.load(); })
      .onBackPressed(() => { this.back(); return true; }).onDisAppear(() => { this.active = false; })
  }
}
