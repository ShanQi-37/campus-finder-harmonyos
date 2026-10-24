import { Claim } from '../model/Models';
import { Api } from '../service/Api';
import { categoryArt, claimColor, claimText, ChoiceChip, Colors, PageHeader, StatePanel } from '../components/Common';
@ComponentV2
export struct ClaimCenterPage {
  @Local claims: Claim[] = [];
  @Local boxDirection: string = 'received';
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local busy: boolean = false;
  @Local notice: string = '';
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;
  private active: boolean = true;
  async load(): Promise<void> {
    const ticket = ++this.generation; this.phase = 'loading'; this.error = '';
    try { const result = await Api.claims(this.boxDirection); if (this.active && ticket === this.generation) { this.claims = result.claims; this.phase = result.claims.length ? 'ready' : 'empty'; } }
    catch (error) { if (this.active && ticket === this.generation) { this.error = (error as Error).message; this.phase = 'error'; } }
  }
  async review(id: string, action: string): Promise<void> {
    if (this.busy) { return; } this.busy = true; this.error = '';
    try { await Api.review(id, action); if (this.active) { this.notice = action === 'accept' ? '已确认寻回，物品状态和统计已同步更新。' : '申请状态已更新。'; await this.load(); } }
    catch (error) { if (this.active) { this.error = (error as Error).message; } }
    finally { if (this.active) { this.busy = false; } }
  }
  confirm(claim: Claim, action: string): void {
    this.getUIContext().showAlertDialog({ title: action === 'accept' ? '已核实并完成交接？' : (action === 'reject' ? '不通过这份申请？' : '取消这份申请？'),
      message: action === 'accept' ? '确认后启事将标记为已寻回，同一物品的其他待核对申请会关闭。' : '处理结果会同步给申请双方，可返回列表查看。',
      primaryButton: { value: '再想想', action: () => {} }, secondaryButton: { value: '确认', action: () => { this.review(claim.id, action); } } });
  }
  back(): void { if (!this.busy) { this.stack.pop({ changed: true }); } }
  build() {
    NavDestination() {
      Column({ space: 12 }) {
        PageHeader({ title: '认领与线索', subtitle: '让每一份申请，都有明确的回应', back: true, onBack: () => this.back() })
        Row({ space: 10 }) {
          ChoiceChip({ label: '我收到的', selected: this.boxDirection === 'received', onSelect: () => { this.boxDirection = 'received'; this.notice = ''; this.load(); } })
          ChoiceChip({ label: '我发出的', selected: this.boxDirection === 'sent', onSelect: () => { this.boxDirection = 'sent'; this.notice = ''; this.load(); } })
          Blank()
          Text('刷新').fontSize(11).fontColor(Colors.green).padding(7).onClick(() => { this.load(); })
        }.width('100%').padding({ left: 18, right: 18 }).enabled(!this.busy)
        if (this.notice.length) { Text(this.notice).fontSize(11).fontColor(Colors.green).width('90%').padding(12).backgroundColor(Colors.soft).borderRadius(12) }
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, emptyText: '还没有相关申请', onRetry: () => { this.load(); } }).layoutWeight(1)
        } else {
          if (this.error.length) { Text(this.error).fontSize(12).fontColor(Colors.red).width('90%') }
          List({ space: 12 }) {
            ForEach(this.claims, (claim: Claim) => {
              ListItem() {
                Column({ space: 12 }) {
                  Row({ space: 11 }) {
                    Image(categoryArt(claim.category)).width(50).height(60).objectFit(ImageFit.Contain).backgroundColor('#EDF2E7').borderRadius(12)
                    Column({ space: 7 }) {
                      Text(claim.itemTitle).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(2)
                      Text((this.boxDirection === 'received' ? claim.senderName : claim.ownerName) + ' · ' + (claim.kind === 'found' ? '认领申请' : '寻物线索')).fontSize(10).fontColor(Colors.muted)
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    Text(claimText(claim.status)).fontSize(10).fontColor(claimColor(claim.status))
                  }.width('100%').onClick(() => { this.stack.pushPath({ name: 'Detail', param: claim.itemId }); })
                  Divider().color('#EDF0E9')
                  Text(claim.proof).fontSize(13).lineHeight(21).fontColor('#526F63').width('100%')
                  Text('联系：' + claim.contact).fontSize(11).fontColor(Colors.muted).width('100%')
                  Text(new Date(claim.createdAt).toLocaleString()).fontSize(10).fontColor(Colors.muted).width('100%')
                  if (claim.status === 'pending') {
                    Row({ space: 10 }) {
                      if (this.boxDirection === 'received') {
                        Button('不通过').height(35).fontSize(12).fontColor(Colors.red).backgroundColor('#FFF0E8').layoutWeight(1).onClick(() => this.confirm(claim, 'reject'))
                        Button('核实交接 · 确认寻回').height(35).fontSize(12).backgroundColor(Colors.green).layoutWeight(2).onClick(() => this.confirm(claim, 'accept'))
                      } else {
                        Button('取消申请').height(35).fontSize(12).fontColor(Colors.green).backgroundColor(Colors.soft).layoutWeight(1).onClick(() => this.confirm(claim, 'cancel'))
                      }
                    }.width('100%').enabled(!this.busy)
                  }
                }.padding(16).width('100%').backgroundColor('#FFFFFF').borderRadius(18)
              }
            }, (claim: Claim) => claim.id)
          }.layoutWeight(1).padding({ left: 18, right: 18, bottom: 18 }).width('100%').scrollBar(BarState.Auto)
        }
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; this.boxDirection = context.pathInfo.param as string; if (this.boxDirection !== 'sent') { this.boxDirection = 'received'; } })
      .onShown(() => { this.active = true; this.load(); }).onHidden(() => { this.active = false; this.generation++; })
      .onBackPressed(() => { this.back(); return true; })
  }
}
