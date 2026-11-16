import { CATEGORIES, PublishInput } from '../model/Models';
import { Api } from '../service/Api';
import { categoryArt, Colors, PageHeader, SegmentTab, StatePanel } from '../components/Common';
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
  @Local issue: string = '';
  @Local notice: string = '';
  @Local step: number = 1;
  @Local phase: string = 'loading';
  @Local editing: boolean = false;
  @Local hasSavedDraft: boolean = false;
  private itemId: string = '';
  private requestId: string = 'draft-' + Date.now() + '-' + Math.random().toString(36).slice(2);
  private stack: NavPathStack = new NavPathStack();
  private formScroll: Scroller = new Scroller();
  private active: boolean = true;
  private baseline: string = '';
  private savedDraftAt: string = '';
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
          this.hasSavedDraft = true; this.savedDraftAt = draft.updatedAt;
          this.notice = '已恢复草稿 · 可继续编辑后发布';
        }
      }
      this.baseline = JSON.stringify(this.input()); this.phase = 'ready';
    } catch (error) { if (this.active) { this.phase = 'error'; this.error = (error as Error).message; } }
  }
  example(): void {
    this.kind = 'lost'; this.category = '证件卡片'; this.title = '寻找蓝色校园卡套'; this.location = '图书馆一楼';
    this.description = '蓝色卡套，背面贴有白色贴纸；这是用于课程演示的虚构信息。'; this.contact = '校园服务台转接（演示）';
    this.occurredAt = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' });
    this.goTo(1); this.notice = '已填入虚构示例';
  }
  offerExample(): void {
    if (!this.title.trim() && !this.location.trim() && !this.description.trim() && !this.hasSavedDraft &&
      JSON.stringify(this.input()) === this.baseline) {
      this.example();
      return;
    }
    this.getUIContext().showAlertDialog({ title: '用虚构示例替换当前内容？',
      message: '替换后可继续编辑，保存草稿时会更新已保存内容。',
      primaryButton: { value: '继续填写', action: () => {} },
      secondaryButton: { value: '填入示例', action: () => this.example() } });
  }
  goTo(step: number): void {
    if (this.busy) { return; }
    this.step = step;
    this.error = '';
    this.issue = '';
    this.formScroll.scrollEdge(Edge.Top);
  }
  back(): void {
    if (this.busy) { return; }
    if (this.step > 1) { this.goTo(this.step - 1); return; }
    if (this.phase !== 'ready' || JSON.stringify(this.input()) === this.baseline) { this.stack.pop(); return; }
    this.getUIContext().showAlertDialog({ title: this.editing ? '修改还未保存' : '保存草稿，下次接着写？',
      message: this.editing ? '继续填写可保留当前内容；放弃后原启事保持原样。' : '草稿按当前体验身份保存在本机服务中，发布成功后自动移出草稿。',
      primaryButton: { value: '继续填写', action: () => {} },
      secondaryButton: { value: this.editing ? '放弃修改' : '保存并离开', action: () => { if (this.editing) { this.stack.pop(); } else { this.saveDraft(true); } } } });
  }
  async saveDraft(leave: boolean = false): Promise<void> {
    if (this.busy || this.editing) { return; } this.busy = true; this.error = ''; this.issue = ''; this.notice = '';
    try { const draft = await Api.saveDraft(this.input()); if (this.active) { this.hasSavedDraft = true; this.savedDraftAt = draft.updatedAt; this.baseline = JSON.stringify(this.input()); this.notice = '草稿已保存 · 可在我的校园中继续填写'; if (leave) { this.stack.pop({ changed: true }); } } }
    catch (error) { if (this.active) { this.error = (error as Error).message; } }
    finally { if (this.active) { this.busy = false; } }
  }
  confirmDiscard(): void {
    if (this.busy || !this.hasSavedDraft) { return; }
    this.getUIContext().showAlertDialog({ title: '舍弃这份草稿？', message: '将清除已保存草稿和本页尚未保存的改动，重新填写空白启事。已发布的启事不会受影响。',
      primaryButton: { value: '继续填写', action: () => {} }, secondaryButton: { value: '确认舍弃', action: () => { this.discardDraft(); } } });
  }
  async discardDraft(): Promise<void> {
    if (this.busy || !this.hasSavedDraft) { return; } this.busy = true; this.error = ''; this.issue = ''; this.notice = '';
    try {
      await Api.discardDraft(this.requestId, this.savedDraftAt);
      if (this.active) {
        this.kind = 'lost'; this.category = '证件卡片'; this.title = ''; this.location = ''; this.description = ''; this.contact = '校园服务台转接（演示）';
        this.occurredAt = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' });
        this.requestId = 'draft-' + Date.now() + '-' + Math.random().toString(36).slice(2); this.savedDraftAt = ''; this.hasSavedDraft = false; this.step = 1;
        this.baseline = JSON.stringify(this.input()); this.notice = '旧草稿已清除 · 可以重新填写';
      }
    } catch (error) { if (this.active) { this.error = (error as Error).message; } }
    finally { this.busy = false; }
  }
  reject(field: string, message: string, step: number): boolean {
    if (this.step !== step) { this.formScroll.scrollEdge(Edge.Top); }
    this.issue = field;
    this.error = message;
    this.step = step;
    return false;
  }
  clearIssue(field: string): void {
    if (this.issue === field) { this.issue = ''; this.error = ''; }
  }
  validateBasics(): boolean {
    if (this.title.trim().length < 2) { return this.reject('title', '标题至少填写 2 个字。', 1); }
    if (this.location.trim().length < 2) { return this.reject('location', '地点至少填写 2 个字。', 1); }
    return true;
  }
  validate(): boolean {
    if (!this.validateBasics()) { return false; }
    if (this.description.trim().length < 8) { return this.reject('description', '物品描述至少填写 8 个字。', 2); }
    if (this.contact.trim().length < 2) { return this.reject('contact', '联系指引至少填写 2 个字。', 2); }
    const stamp = Date.parse(this.occurredAt);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(this.occurredAt) || !Number.isFinite(stamp) || new Date(stamp).toISOString().slice(0, 10) !== this.occurredAt || this.occurredAt > new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' })) {
      return this.reject('date', '请填写有效日期 YYYY-MM-DD，且不能晚于今天。', 2);
    }
    return true;
  }
  next(): void {
    if (this.step === 1 && !this.validateBasics()) { return; }
    if (this.step === 2 && !this.validate()) { return; }
    this.goTo(this.step + 1);
  }
  async submit(): Promise<void> {
    if (this.busy || !this.validate()) { return; } this.busy = true; this.error = '';
    try { await Api.publish(this.input(), this.itemId); if (this.active) { this.stack.pop({ changed: true, published: !this.editing }); } }
    catch (error) { if (this.active) { this.error = (error as Error).message; } }
    finally { if (this.active) { this.busy = false; } }
  }
  @Builder
  fieldLabel(label: string, hint: string) {
    Row({ space: 8 }) {
      Text(label).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.ink).layoutWeight(1)
      Text(hint).fontSize(11).fontColor(Colors.muted)
    }.width('100%')
  }

  @Builder
  progress(text: string, index: number) {
    Column({ space: 6 }) {
      Text(index + '  ' + text).fontSize(12).fontWeight(this.step === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.step === index ? Colors.green : Colors.muted).maxLines(1)
      Rect().width('100%').height(3).radius(2).fill(this.step >= index ? Colors.green : Colors.stroke)
    }.layoutWeight(1).alignItems(HorizontalAlign.Start).accessibilitySelected(this.step === index)
  }

  @Builder
  basics() {
    Column({ space: 9 }) {
      Row({ space: 4 }) {
        SegmentTab({ label: '寻物启事', selected: this.kind === 'lost', onSelect: () => { this.kind = 'lost'; } }).layoutWeight(1)
        SegmentTab({ label: '招领启事', selected: this.kind === 'found', onSelect: () => { this.kind = 'found'; } }).layoutWeight(1)
      }.width('100%').padding(3).backgroundColor(Colors.soft).borderRadius(12)
      this.fieldLabel('物品分类', '')
      Grid() {
        ForEach(CATEGORIES, (category: string) => {
          GridItem() {
            SegmentTab({ label: category, selected: this.category === category, onSelect: () => { this.category = category; } })
          }.backgroundColor(this.category === category ? Colors.soft : Colors.paper).borderRadius(10)
        }, (category: string) => category)
      }.width('100%').height(88).columnsTemplate('1fr 1fr').rowsTemplate('1fr 1fr').rowsGap(6).columnsGap(6)
      this.fieldLabel('启事标题', this.title.length + ' / 36')
      TextInput({ placeholder: '例如：寻找蓝色校园卡套', text: this.title }).constraintSize({ minHeight: 46 })
        .fontSize(14).maxLength(36).backgroundColor(Colors.paper).borderRadius(10)
        .border({ width: 1, color: this.issue === 'title' ? Colors.red : Colors.stroke }).accessibilityText('启事标题')
        .id('publishTitle').enterKeyType(EnterKeyType.Next).onSubmit(() => { focusControl.requestFocus('publishLocation'); })
        .onChange((value: string) => { this.title = value; this.clearIssue('title'); })
      this.fieldLabel('遗失或拾取地点', this.location.length + ' / 30')
      TextInput({ placeholder: '例如：图书馆一楼', text: this.location }).constraintSize({ minHeight: 46 })
        .fontSize(14).maxLength(30).backgroundColor(Colors.paper).borderRadius(10)
        .border({ width: 1, color: this.issue === 'location' ? Colors.red : Colors.stroke }).accessibilityText('遗失或拾取地点')
        .id('publishLocation').enterKeyType(EnterKeyType.Done).onSubmit(() => this.next())
        .onChange((value: string) => { this.location = value; this.clearIssue('location'); })
      if (!this.editing) {
        Button('填入虚构示例').height(39).fontSize(12).fontColor(Colors.green)
          .backgroundColor(Colors.soft).onClick(() => this.offerExample())
      }
    }.width('100%').padding(14).alignItems(HorizontalAlign.Start).backgroundColor(Colors.surface)
      .borderRadius(16).border({ width: 1, color: Colors.stroke })
  }

  @Builder
  details() {
    Column({ space: 10 }) {
      this.fieldLabel('物品描述', this.description.length + ' / 300')
      TextArea({ placeholder: '描述颜色、外观或特殊标记，至少 8 字', text: this.description })
        .height(106).fontSize(14).maxLength(300).backgroundColor(Colors.paper).borderRadius(10)
        .border({ width: 1, color: this.issue === 'description' ? Colors.red : Colors.stroke }).accessibilityText('物品描述')
        .onChange((value: string) => { this.description = value; this.clearIssue('description'); })
      this.fieldLabel('联系指引', '核对通过后可见')
      TextInput({ text: this.contact, placeholder: '例如：校园服务台转接' }).constraintSize({ minHeight: 46 }).fontSize(14)
        .maxLength(60).backgroundColor(Colors.paper).borderRadius(10)
        .border({ width: 1, color: this.issue === 'contact' ? Colors.red : Colors.stroke }).accessibilityText('联系指引')
        .id('publishContact').enterKeyType(EnterKeyType.Next).onSubmit(() => { focusControl.requestFocus('publishDate'); })
        .onChange((value: string) => { this.contact = value; this.clearIssue('contact'); })
      this.fieldLabel('发生日期', 'YYYY-MM-DD')
      TextInput({ text: this.occurredAt, placeholder: 'YYYY-MM-DD' }).constraintSize({ minHeight: 46 })
        .fontSize(14).maxLength(10).backgroundColor(Colors.paper).borderRadius(10)
        .border({ width: 1, color: this.issue === 'date' ? Colors.red : Colors.stroke }).accessibilityText('发生日期')
        .id('publishDate').enterKeyType(EnterKeyType.Done).onSubmit(() => this.next())
        .onChange((value: string) => { this.occurredAt = value; this.clearIssue('date'); })
    }.width('100%').padding(14).backgroundColor(Colors.surface).borderRadius(16)
      .border({ width: 1, color: Colors.stroke })
    Text('请使用虚构演示内容，避免填写完整证件号码或密码。').fontSize(12).fontColor('#77531C')
      .lineHeight(19).width('100%').padding(12).backgroundColor('#FCF0D8').borderRadius(12)
  }

  @Builder
  review() {
    Column({ space: 12 }) {
      Row() {
        Text('公开启事').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.ink).layoutWeight(1)
        Button('修改基本信息').height(35).fontSize(11).fontColor(Colors.green)
          .backgroundColor(Colors.soft).onClick(() => this.goTo(1))
      }.width('100%')
      Row({ space: 12 }) {
        Image(categoryArt(this.category)).width(62).height(68).objectFit(ImageFit.Contain)
          .backgroundColor(Colors.soft).borderRadius(12).accessibilityLevel('no')
        Column({ space: 6 }) {
          Text((this.kind === 'lost' ? '寻物' : '招领') + ' · ' + this.category).fontSize(12).fontColor(Colors.muted)
          Text(this.title).fontSize(19).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%')
      Text(this.location + '  ·  ' + this.occurredAt).fontSize(13).fontColor(Colors.muted).width('100%')
      Text(this.description).fontSize(14).lineHeight(22).fontColor(Colors.ink).width('100%')
    }.width('100%').padding(14).backgroundColor(Colors.surface).borderRadius(16)
      .border({ width: 1, color: Colors.stroke })
    Column({ space: 6 }) {
      Row() {
        Text('联系指引').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.ink).layoutWeight(1)
        Button('修改补充线索').height(35).fontSize(11).fontColor(Colors.green)
          .backgroundColor(Colors.surface).onClick(() => this.goTo(2))
      }.width('100%')
      Text(this.contact).fontSize(14).fontColor(Colors.ink).width('100%')
      Text('核对通过后对申请者可见').fontSize(11).fontColor(Colors.muted).width('100%')
    }.width('100%').padding(14).backgroundColor(Colors.soft).borderRadius(16)
  }

  build() {
    NavDestination() {
      Column({ space: 9 }) {
        PageHeader({ title: this.editing ? '编辑启事' : '发布启事', back: true, onBack: () => this.back() })
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, onRetry: () => { this.load(); } }).layoutWeight(1)
        } else {
          Row({ space: 10 }) {
            this.progress('基本信息', 1)
            this.progress('补充线索', 2)
            this.progress('预览确认', 3)
          }.width('100%').padding({ left: 16, right: 16, bottom: 2 })
          if (!this.editing) {
            Row({ space: 4 }) {
              Text(this.notice.length ? this.notice : (this.hasSavedDraft ? '已恢复草稿' : '可保存未填完的启事'))
                .fontSize(11).fontColor(Colors.muted).maxLines(2).layoutWeight(1)
              if (this.hasSavedDraft) {
                Button('舍弃').height(36).fontSize(12).fontColor(Colors.red).backgroundColor(Colors.surface)
                  .onClick(() => this.confirmDiscard())
              }
              Button('存草稿').height(36).fontSize(12).fontColor(Colors.green).backgroundColor(Colors.soft)
                .onClick(() => { this.saveDraft(); })
            }.width('100%').padding({ left: 16, right: 16 }).enabled(!this.busy)
          }
          Scroll(this.formScroll) {
            Column({ space: 10 }) {
              if (this.step === 1) { this.basics() }
              else if (this.step === 2) { this.details() }
              else { this.review() }
            }.width('100%').padding({ left: 16, right: 16, bottom: 16 })
          }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top).enabled(!this.busy)
          Column({ space: 6 }) {
            if (this.error.length) {
              Text(this.error).fontColor(Colors.red).fontSize(12).width('100%').padding({ bottom: 2 })
            }
            Row({ space: 8 }) {
              if (this.step > 1) {
                Button('上一步').constraintSize({ minHeight: 46 }).fontSize(13).fontColor(Colors.green).backgroundColor(Colors.soft)
                  .onClick(() => this.goTo(this.step - 1))
              }
              Button(this.busy ? '正在保存…' : (this.step === 1 ? '下一步 · 补充线索' :
                (this.step === 2 ? '下一步 · 预览确认' : (this.editing ? '保存修改' : '确认发布'))))
                .layoutWeight(1).constraintSize({ minHeight: 46 }).fontSize(14).fontWeight(FontWeight.Bold).backgroundColor(Colors.green)
                .onClick(() => { if (this.step < 3) { this.next(); } else { this.submit(); } })
            }.width('100%').enabled(!this.busy)
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 12 }).backgroundColor(Colors.surface)
            .border({ width: { top: 1 }, color: Colors.stroke })
        }
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
      this.itemId = context.pathInfo.param as string;
      this.editing = this.itemId.length > 0;
      this.load();
    }).onBackPressed(() => { this.back(); return true; }).onDisAppear(() => { this.active = false; })
  }
}
