import { common } from '@kit.AbilityKit';
import { Colors, ItemCard, PageHeader, AmbientBackground } from '../components/Common';
import { MatchLead, PhotoCandidate, PhotoMatches } from '../model/Models';
import { Api } from '../service/Api';
import { MediaPicker } from '../service/MediaPicker';

@ComponentV2
export struct PhotoSearchPage {
  @Local busy: boolean = false;
  @Local error: string = '';
  @Local result: PhotoMatches | null = null;
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;

  async search(fromAlbum: boolean): Promise<void> {
    if (this.busy) { return; }
    const ticket = ++this.generation;
    this.busy = true;
    this.error = '';
    try {
      const bytes = await MediaPicker.choose(this.getUIContext().getHostContext() as common.UIAbilityContext, false, fromAlbum);
      if (bytes === null || ticket !== this.generation) { return; }
      this.result = null;
      const result = await Api.searchPhoto(bytes);
      if (ticket === this.generation) { this.result = result; }
    } catch (error) {
      if (ticket === this.generation) { this.error = (error as Error).message || '无法读取照片，请重试'; }
    } finally {
      if (ticket === this.generation) { this.busy = false; }
    }
  }

  openCandidate(id: string): void {
    const searchId = this.result?.searchId;
    if (!searchId) { this.stack.pushPath({ name: 'Detail', param: id }); return; }
    const candidate: PhotoCandidate = { itemId: id, searchId: searchId };
    this.stack.pushPath({ name: 'Detail', param: candidate });
  }

  build() {
    NavDestination() {
      Stack() {
        AmbientBackground()
        Column({ space: 8 }) {
        PageHeader({ title: '拍照找物', back: true, onBack: () => { this.stack.pop(); } })
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 8 }) {
              Row({ space: 10 }) {
                Text('📷').fontSize(28).width(52).height(52).textAlign(TextAlign.Center)
                  .backgroundColor(Colors.greenSoft).borderRadius(16)
                Column({ space: 3 }) {
                  Text('拍下物品、同款或外观相近的物品，查找正在招领的启事。').fontSize(15)
                    .fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
                  Text('照片将提交给视觉识别服务，本应用不会保存查找用照片。请避开人脸和证件号码。')
                    .fontSize(12).fontColor(Colors.muted).lineHeight(19).width('100%')
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }.width('100%').alignItems(VerticalAlign.Top)
              Button(this.busy ? '正在处理照片…' : '拍照并查找').width('100%').constraintSize({ minHeight: 46 })
                .fontColor('#FFFFFF').backgroundColor(Colors.greenDeep)
                .enabled(!this.busy).onClick(() => { this.search(false); })
              Button('从相册选照片').width('100%').constraintSize({ minHeight: 44 }).backgroundColor(Colors.soft)
                .fontColor(Colors.green).enabled(!this.busy).onClick(() => { this.search(true); })
            }.padding(14).width('100%').borderRadius(16).backgroundColor(Colors.glass)
              .border({ width: 1, color: Colors.glassStroke })
            if (this.error.length) {
              Text(this.error).fontSize(13).fontColor(Colors.red).width('100%')
            }
            if (this.result !== null) {
              Text('识别到 ' + this.result.recognition.object + ' · ' + this.result.recognition.category)
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
              if (this.result.recognition.features.length) {
                Text(this.result.recognition.features.join(' · ')).fontSize(13).fontColor(Colors.muted).width('100%')
              }
              if (this.result.matches.length === 0) {
                Text('暂时没有相近的招领启事，可以换一张照片或返回广场搜索。')
                  .fontSize(13).fontColor(Colors.muted).width('100%')
              }
              ForEach(this.result.matches, (lead: MatchLead) => {
                Column({ space: 4 }) {
                  ItemCard({ item: lead.item, onOpen: (id: string) => this.openCandidate(id) })
                  Text(lead.reasons.join(' · ')).fontSize(12).fontColor(Colors.green).width('100%')
                }.width('100%')
              }, (lead: MatchLead) => lead.item.id)
            }
          }.width('100%').padding({ left: 16, right: 16, bottom: 16 })
        }.layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top)
        }.width('100%').height('100%')
      }.width('100%').height('100%')
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
    }).onDisAppear(() => { this.generation++; })
  }
}
