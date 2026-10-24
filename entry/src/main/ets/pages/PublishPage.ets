import { CATEGORIES, PublishInput } from '../model/Models';
import { Api } from '../service/Api';
import { ChoiceChip, Colors, PageHeader, StatePanel } from '../components/Common';
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
  @Local step: number = 1;
  @Local phase: string = 'ready';
  @Local editing: boolean = false;
  private itemId: string = '';
  private requestId: string = 'draft-' + Date.now() + '-' + Math.random().toString(36).slice(2);
  private stack: NavPathStack = new NavPathStack();
  private active: boolean = true;
  async load(): Promise<void> {
    this.phase = 'loading';
    try { const item = await Api.detail(this.itemId); if (!this.active) { return; } this.kind = item.kind; this.category = item.category; this.title = item.title; this.location = item.location; this.description = item.description; this.contact = item.contact; this.occurredAt = item.occurredAt; this.phase = 'ready'; }
    catch (error) { if (this.active) { this.phase = 'error'; this.error = (error as Error).message; } }
  }
  example(): void {
    this.kind = 'lost'; this.category = '证件卡片'; this.title = '寻找蓝色校园卡套'; this.location = '图书馆一楼';
    this.description = '蓝色卡套，背面贴有白色贴纸；这是用于课程演示的虚构信息。'; this.contact = '校园服务台转接（演示）'; this.error = ''; this.step = 1;
  }
  back(): void { if (this.busy) { return; } if (this.step === 2) { this.step = 1; this.error = ''; } else { this.stack.pop(); } }
  next(): void {
    if (this.title.trim().length < 2 || this.location.trim().length < 2) { this.error = '标题和地点都至少填写 2 个字。'; return; }
    this.error = ''; this.step = 2;
  }
  async submit(): Promise<void> {
    if (this.busy) { return; }
    if (this.title.trim().length < 2 || this.location.trim().length < 2 || this.description.trim().length < 8 || this.contact.trim().length < 2) { this.error = '请填全信息，物品描述至少 8 个字。'; return; }
    this.busy = true; this.error = '';
    const input: PublishInput = { title: this.title, category: this.category, kind: this.kind, location: this.location, description: this.description, contact: this.contact, occurredAt: this.occurredAt, requestId: this.requestId };
    try { await Api.publish(input, this.itemId); if (this.active) { this.stack.pop({ changed: true, published: !this.editing }); } }
    catch (error) { if (this.active) { this.error = (error as Error).message; } }
    finally { if (this.active) { this.busy = false; } }
  }
  @Builder
  label(text: string) { Text(text).fontSize(13).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%') }
  build() {
    NavDestination() {
      Column({ space: 12 }) {
        PageHeader({ title: this.editing ? '编辑启事' : '发布启事', subtitle: '描述越清晰，重逢越靠近', back: true, onBack: () => this.back() })
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, onRetry: () => { this.load(); } }).layoutWeight(1)
        } else {
          Row({ space: 10 }) {
            Text('01  基本信息').fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.step === 1 ? Colors.green : Colors.muted)
            Text('──').fontSize(13).fontColor('#C9D9CD')
            Text('02  线索与联系').fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.step === 2 ? Colors.green : Colors.muted)
          }.width('100%').padding({ left: 18, right: 18 })
          if (!this.editing) {
            Row() {
              Text('首次发布？参考一份虚构示例').fontSize(10).fontColor(Colors.muted).layoutWeight(1)
              Button('填入示例').fontSize(11).height(28).fontColor(Colors.green).backgroundColor(Colors.soft).onClick(() => this.example())
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
              } else {
                this.label('物品描述 / 8–300字')
                TextArea({ placeholder: '描述颜色、外观、特殊标记', text: this.description }).height(105).fontSize(13).maxLength(300).backgroundColor('#FFFFFF').onChange((value: string) => { this.description = value; })
                this.label('联系指引 / 核对通过后对申请者可见')
                TextInput({ text: this.contact, placeholder: '建议通过校园服务台转接' }).height(42).fontSize(13).maxLength(60).backgroundColor('#FFFFFF').onChange((value: string) => { this.contact = value; })
                this.label('发生日期 / YYYY-MM-DD')
                TextInput({ text: this.occurredAt }).height(42).fontSize(13).maxLength(10).backgroundColor('#FFFFFF').onChange((value: string) => { this.occurredAt = value; })
                Text('请使用虚构演示内容，不要填写完整证件号码、密码或付款信息。').fontSize(11).fontColor('#A38349').lineHeight(19).padding(12).backgroundColor('#FFF5E3').borderRadius(12)
              }
            }.width('100%').padding({ left: 18, right: 18, bottom: 18 })
          }.layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top).enabled(!this.busy)
          Column({ space: 8 }) {
            if (this.error.length) { Text(this.error).fontColor(Colors.red).fontSize(12).width('100%') }
            Button(this.step === 1 ? '下一步 · 补充线索  →' : (this.busy ? '正在保存…' : (this.editing ? '保存修改' : '发布到失物广场'))).width('100%').height(46).fontSize(14).backgroundColor(Colors.green).enabled(!this.busy)
              .onClick(() => { if (this.step === 1) { this.next(); } else { this.submit(); } })
          }.width('100%').padding({ left: 18, right: 18, top: 10, bottom: 20 }).backgroundColor('#FFFFFF')
        }
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; this.itemId = context.pathInfo.param as string; this.editing = this.itemId.length > 0; if (this.editing) { this.load(); } })
      .onBackPressed(() => { this.back(); return true; }).onDisAppear(() => { this.active = false; })
  }
}
