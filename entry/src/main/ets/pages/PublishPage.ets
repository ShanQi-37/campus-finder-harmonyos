import { CATEGORIES, PublishInput } from '../model/Models';
import { Api } from '../service/Api';
import { ChoiceChip, Colors, PageHeader } from '../components/Common';
@ComponentV2
export struct PublishPage {
  @Local kind: string = 'lost';
  @Local category: string = '证件卡片';
  @Local title: string = '';
  @Local location: string = '';
  @Local description: string = '';
  @Local contact: string = '校园服务台转接（演示）';
  @Local busy: boolean = false;
  @Local error: string = '';
  private stack: NavPathStack = new NavPathStack();
  async submit(): Promise<void> {
    if (this.busy) { return; }
    if (this.title.trim().length < 2 || this.location.trim().length < 2 || this.description.trim().length < 8 || this.contact.trim().length < 2) {
      this.error = '请填写标题、地点和联系指引，描述至少 8 个字。'; return;
    }
    this.busy = true; this.error = '';
    const input: PublishInput = { title: this.title, category: this.category, kind: this.kind, location: this.location, description: this.description, contact: this.contact };
    try { await Api.publish(input); this.stack.pop({ changed: true, published: true }); }
    catch (error) { this.error = (error as Error).message; }
    finally { this.busy = false; }
  }
  @Builder
  label(text: string) { Text(text).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%') }
  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '发布信息', subtitle: '写下线索，让物品更快回家', back: true, onBack: () => { if (!this.busy) { this.stack.pop(); } } })
        Scroll() {
          Column({ space: 15 }) {
            Row({ space: 12 }) {
              ChoiceChip({ label: '我丢了 · 寻物', selected: this.kind === 'lost', onSelect: () => { this.kind = 'lost'; } })
              ChoiceChip({ label: '我捡到 · 招领', selected: this.kind === 'found', onSelect: () => { this.kind = 'found'; } })
            }.width('100%')
            this.label('物品分类')
            Grid() {
              ForEach(CATEGORIES, (category: string) => {
                GridItem() { ChoiceChip({ label: category, selected: this.category === category, onSelect: () => { this.category = category; } }) }
              }, (category: string) => category)
            }.columnsTemplate('1fr 1fr').rowsGap(10).columnsGap(10).height(80).width('100%')
            this.label('标题')
            TextInput({ placeholder: '例如：图书馆捡到一张校园卡', text: this.title }).height(44).fontSize(14).maxLength(36).backgroundColor('#FFFFFF').onChange((value: string) => { this.title = value; })
            this.label('遗失或拾取地点')
            TextInput({ placeholder: '请写明楼栋、楼层等具体线索', text: this.location }).height(44).fontSize(14).maxLength(30).backgroundColor('#FFFFFF').onChange((value: string) => { this.location = value; })
            this.label('物品描述')
            TextArea({ placeholder: '描述颜色、外观等特征，至少 8 个字', text: this.description }).height(108).fontSize(14).maxLength(300).backgroundColor('#FFFFFF').onChange((value: string) => { this.description = value; })
            this.label('联系指引')
            TextInput({ text: this.contact, placeholder: '建议通过校园服务台核实' }).height(44).fontSize(14).maxLength(60).backgroundColor('#FFFFFF').onChange((value: string) => { this.contact = value; })
            Text('请勿发布完整证件号码、密码等信息。当前为课程演示，请使用虚构内容。').fontSize(12).fontColor(Colors.muted).lineHeight(20)
            if (this.error.length) { Text(this.error).fontColor('#B54837').fontSize(13).width('100%') }
            Button(this.busy ? '正在发布…' : '发布到失物广场').width('100%').height(48).backgroundColor(Colors.green).enabled(!this.busy).onClick(() => { this.submit(); })
          }.width('100%').padding({ left: 20, right: 20, bottom: 30 })
        }.layoutWeight(1).scrollBar(BarState.Off).enabled(!this.busy)
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; })
      .onBackPressed(() => { if (!this.busy) { this.stack.pop(); } return true; })
  }
}
