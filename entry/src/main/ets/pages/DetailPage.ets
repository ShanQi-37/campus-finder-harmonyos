import { Item, MatchLead, TimelineEvent, emptyItem } from '../model/Models';
import { Session } from '../model/Session';
import { Api } from '../service/Api';
import { categoryArt, Colors, ItemCard, PageHeader, StatePanel, statusText, ChoiceChip } from '../components/Common';
@ComponentV2
export struct DetailPage {
  @Local item: Item = emptyItem();
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local section: string = 'info';
  @Local busy: boolean = false;
  @Local leads: MatchLead[] = [];
  @Local matchPhase: string = 'loading';
  @Local matchError: string = '';
  private matchGeneration: number = 0;
  private stack: NavPathStack = new NavPathStack();
  private itemId: string = '';
  private changed: boolean = false;
  private active: boolean = true;
  private generation: number = 0;
  async load(): Promise<void> {
    if (!this.itemId.length) { return; }
    const ticket = ++this.generation; this.phase = 'loading'; this.error = '';
    try { const result = await Api.detail(this.itemId); if (this.active && ticket === this.generation) { this.item = result; this.phase = 'ready'; } }
    catch (error) { if (this.active && ticket === this.generation) { this.error = (error as Error).message; this.phase = 'error'; } }
  }
  async action(action: string): Promise<void> {
    if (this.busy) { return; } this.busy = true; this.error = '';
    try { const result = action === 'favorite' ? await Api.favorite(this.itemId, !this.item.saved) : await Api.action(this.itemId, action); if (this.active) { this.item = result; this.changed = true; if (this.section === 'matches') { this.loadMatches(); } } }
    catch (error) { if (this.active) { this.error = (error as Error).message; } }
    finally { this.busy = false; }
  }
  async loadMatches(): Promise<void> {
    this.section = 'matches'; const ticket = ++this.matchGeneration; this.matchPhase = 'loading'; this.matchError = '';
    try { const result = await Api.matches(this.itemId); if (this.active && ticket === this.matchGeneration) { this.leads = result.matches; this.matchPhase = result.matches.length ? 'ready' : 'empty'; } }
    catch (error) { if (this.active && ticket === this.matchGeneration) { this.matchError = (error as Error).message; this.matchPhase = 'error'; } }
  }
  confirm(action: string): void {
    this.getUIContext().showAlertDialog({ title: action === 'resolve' ? '已核对并完成交接？' : '确定撤回这条启事？',
      message: action === 'resolve' ? '确认后标记为已寻回，待核对申请会关闭，统计同步更新。' : '撤回后广场不再展示，待核对申请会取消；可在我的记录中恢复。',
      primaryButton: { value: '再想想', action: () => {} }, secondaryButton: { value: action === 'resolve' ? '确认寻回' : '撤回启事', action: () => { this.action(action); } } });
  }
  back(): void { if (!this.busy) { this.stack.pop({ changed: this.changed }); } }
  build() {
    NavDestination() {
      Column({ space: 10 }) {
        PageHeader({ title: '线索详情', subtitle: '认真核对，让物品安心回家', back: true, onBack: () => this.back() })
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error, onRetry: () => { this.load(); } }).layoutWeight(1)
        } else {
          Row({ space: 16 }) {
            Image(categoryArt(this.item.category)).width(104).height(116).objectFit(ImageFit.Contain).backgroundColor('#E8EFE1').borderRadius(20)
            Column({ space: 10 }) {
              Text(this.item.kind === 'found' ? 'FOUND / 拾物招领' : 'LOST / 寻物启事').fontSize(10).fontColor(Colors.green)
              Text(this.item.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(2)
              Text(statusText(this.item.status)).fontSize(11).fontColor(Colors.green).backgroundColor(Colors.soft).padding(6).borderRadius(6)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%').padding({ left: 18, right: 18 })
          Row({ space: 8 }) {
            ChoiceChip({ label: '物品信息', selected: this.section === 'info', onSelect: () => { this.section = 'info'; } })
            ChoiceChip({ label: '动态记录', selected: this.section === 'history', onSelect: () => { this.section = 'history'; } })
            ChoiceChip({ label: '相似线索', selected: this.section === 'matches', onSelect: () => { this.loadMatches(); } })
          }.width('100%').padding({ left: 18, right: 18 })
          Scroll() {
            Column({ space: 14 }) {
              if (this.section === 'info') {
                Column({ space: 13 }) {
                  Text('⌖  ' + this.item.location).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.green).width('100%')
                  Text(this.item.occurredAt + '  ·  ' + this.item.ownerName).fontSize(11).fontColor(Colors.muted).width('100%')
                  Divider().color('#E9EEE6')
                  Text(this.item.description).fontSize(14).lineHeight(23).fontColor('#526F63').width('100%')
                }.padding(17).width('100%').backgroundColor('#FFFFFF').borderRadius(18)
                Column({ space: 7 }) {
                  Text(this.item.contactVisible ? '联系与交接' : '核对后，安心交接').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
                  Text(this.item.contact).fontSize(12).fontColor(Colors.muted).lineHeight(20).width('100%')
                  Text('请勿提供密码、付款或公开完整证件号码。').fontSize(10).fontColor('#A88449').width('100%')
                }.padding(16).backgroundColor('#FFF6E6').borderRadius(16).width('100%')
              } else if (this.section === 'matches') {
                Text('同类物品、相反启事类型；优先展示相近地点和日期。线索仅供核对，不代表认领结果。').fontSize(11).lineHeight(19).fontColor(Colors.muted).width('100%')
                if (this.matchPhase !== 'ready') {
                  StatePanel({ phase: this.matchPhase, error: this.matchError, emptyText: this.item.status === 'open' ? '暂未找到可核对的相似线索' : '启事已结束，无需继续匹配', onRetry: () => { this.loadMatches(); } })
                } else {
                  ForEach(this.leads, (lead: MatchLead) => {
                    Column({ space: 6 }) {
                      Text(lead.reasons.join(' · ')).fontSize(11).fontColor(Colors.green).width('100%').padding({ left: 5 })
                      ItemCard({ item: lead.item, onOpen: (id: string) => { this.stack.pushPath({ name: 'Detail', param: id }); } })
                    }.width('100%')
                  }, (lead: MatchLead) => lead.item.id)
                }
              } else {
                ForEach(this.item.history, (entry: TimelineEvent) => {
                  Row({ space: 12 }) {
                    Text('•').fontSize(24).fontColor(Colors.green)
                    Column({ space: 7 }) {
                      Text(entry.label).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
                      Text(new Date(entry.at).toLocaleString()).fontSize(11).fontColor(Colors.muted)
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  }.width('100%').padding(15).backgroundColor('#FFFFFF').borderRadius(14)
                }, (entry: TimelineEvent) => entry.at + entry.label)
                Text('仅记录真实操作；当前内容均为虚构演示数据。').fontSize(11).fontColor(Colors.muted).width('100%')
              }
            }.width('100%').padding({ left: 18, right: 18, bottom: 10 })
          }.layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top).enabled(!this.busy)
          Column({ space: 8 }) {
            if (this.error.length) { Text(this.error).fontSize(12).fontColor(Colors.red).width('100%') }
            if (this.item.owner === Session.actor) {
              if (this.item.status === 'open') {
                Row({ space: 10 }) {
                  Button('编辑线索').height(34).fontSize(12).fontColor(Colors.green).backgroundColor(Colors.soft).layoutWeight(1).onClick(() => { this.stack.pushPath({ name: 'Publish', param: this.itemId }); })
                  Button('撤回启事').height(34).fontSize(12).fontColor(Colors.red).backgroundColor('#FFF0E8').layoutWeight(1).onClick(() => this.confirm('withdraw'))
                }.width('100%')
                Button(this.busy ? '正在保存…' : '确认已寻回').width('100%').height(44).fontSize(14).backgroundColor(Colors.green).onClick(() => this.confirm('resolve'))
              } else if (this.item.status === 'withdrawn') {
                Button('恢复到失物广场').width('100%').height(44).backgroundColor(Colors.green).onClick(() => { this.action('restore'); })
              } else { Text('✓ 已完成交接，感谢你的善意').fontSize(14).fontColor(Colors.green).padding(12) }
            } else {
              Row({ space: 10 }) {
                Button(this.item.saved ? '★ 已收藏' : '☆ 收藏').height(44).fontSize(12).fontColor(Colors.green).backgroundColor(Colors.soft).onClick(() => { this.action('favorite'); })
                Button(this.item.status === 'open' ? (this.item.myPending ? '已提交 · 查看申请' : (this.item.kind === 'found' ? '这是我的 · 申请认领' : '我有线索 · 联系发布者')) : '查看我的申请').height(44).fontSize(12).backgroundColor(Colors.green).layoutWeight(1)
                  .onClick(() => { this.stack.pushPath({ name: this.item.status === 'open' && !this.item.myPending ? 'ClaimForm' : 'ClaimCenter', param: this.item.status === 'open' && !this.item.myPending ? this.itemId : 'sent' }); })
              }.width('100%')
            }
          }.enabled(!this.busy).width('100%').padding({ left: 18, right: 18, top: 8, bottom: 20 }).backgroundColor('#FFFFFF')
        }
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => { this.stack = context.pathStack; this.itemId = context.pathInfo.param as string; })
      .onShown(() => { this.active = true; this.load(); if (this.section === 'matches') { this.loadMatches(); } }).onHidden(() => { this.active = false; this.generation++; this.matchGeneration++; })
      .onBackPressed(() => { this.back(); return true; })
  }
}
