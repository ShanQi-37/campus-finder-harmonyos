import { Claim } from '../model/Models';
import { Api } from '../service/Api';
import { categoryArt, claimColor, claimText, Colors, PageHeader, SegmentTab, StatePanel } from '../components/Common';

@ComponentV2
export struct ClaimCenterPage {
  @Local claims: Claim[] = [];
  @Local boxDirection: string = 'received';
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local busy: boolean = false;
  @Local resultStatus: string = '';
  @Local claimStatus: string = 'pending';
  private readonly statuses: string[] = ['all', 'pending', 'accepted', 'rejected', 'cancelled'];
  private readonly statusOptions: SelectOption[] = [{ value: '全部申请' }, { value: '待核对' },
    { value: '已通过' }, { value: '未通过' }, { value: '已取消' }];
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;
  private active: boolean = true;

  async load(): Promise<void> {
    const ticket = ++this.generation;
    this.phase = 'loading';
    this.error = '';
    try {
      const result = await Api.claims(this.boxDirection, this.claimStatus);
      if (this.active && ticket === this.generation) {
        this.claims = result.claims;
        this.phase = result.claims.length ? 'ready' : 'empty';
      }
    } catch (error) {
      if (this.active && ticket === this.generation) {
        this.error = (error as Error).message;
        this.phase = 'error';
      }
    }
  }

  selectDirection(direction: string): void {
    if (this.busy || direction === this.boxDirection) { return; }
    this.boxDirection = direction;
    this.claimStatus = 'pending';
    this.resultStatus = '';
    this.load();
  }

  selectStatus(status: string): void {
    if (this.busy || status === this.claimStatus) { return; }
    this.claimStatus = status;
    this.load();
  }

  async review(id: string, action: string): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    this.error = '';
    this.resultStatus = '';
    try {
      const result = await Api.review(id, action);
      if (this.active) {
        this.resultStatus = result.status;
        await this.load();
      }
    } catch (error) {
      if (this.active) { this.error = (error as Error).message; }
    } finally {
      this.busy = false;
    }
  }

  confirm(claim: Claim, action: string): void {
    const title = action === 'accept' ? '已核实并完成交接？' : (action === 'reject' ? '不通过这份申请？' : '取消这份申请？');
    const label = action === 'accept' ? '确认寻回' : (action === 'reject' ? '确认不通过' : '确认取消');
    this.getUIContext().showAlertDialog({
      title: title,
      message: action === 'accept' ? '确认后，启事将标记为已寻回，并关闭同一物品的其他待核对申请。'
        : '处理结果会同步给申请双方。',
      primaryButton: { value: '返回', action: () => {} },
      secondaryButton: { value: label, action: () => { this.review(claim.id, action); } }
    });
  }

  back(): void { if (!this.busy) { this.stack.pop({ changed: true }); } }

  resultLabel(): string {
    if (this.resultStatus === 'accepted') { return '已确认寻回'; }
    return this.resultStatus === 'rejected' ? '已标记为未通过' : '已取消申请';
  }

  statusFill(status: string): string {
    if (status === 'accepted') { return Colors.soft; }
    if (status === 'rejected') { return '#FAEBE7'; }
    if (status === 'cancelled') { return Colors.paper; }
    return '#FCF0D8';
  }

  guidanceTitle(status: string): string {
    if (status === 'pending') {
      return this.boxDirection === 'received' ? '等你核对' : '等待发布者核对';
    }
    if (status === 'accepted') { return '已确认寻回'; }
    return status === 'rejected' ? '本次申请未通过' : '本次申请已取消';
  }

  guidanceText(status: string): string {
    if (status === 'pending') {
      return this.boxDirection === 'received'
        ? '先查看核对说明。线下核实并交接后，再点「确认寻回」。'
        : '请留意联系指引中的约定。需要撤销时，可从此处取消申请。';
    }
    if (status === 'accepted') { return '交接已完成，可打开启事查看最新状态。'; }
    return this.boxDirection === 'sent' ? '可打开启事查看当前状态。' : '这条申请已结束。';
  }

  @Builder
  controls() {
    Column({ space: 8 }) {
      Row({ space: 4 }) {
        SegmentTab({ label: '我收到的', selected: this.boxDirection === 'received',
          onSelect: () => this.selectDirection('received') }).layoutWeight(1)
        SegmentTab({ label: '我发出的', selected: this.boxDirection === 'sent',
          onSelect: () => this.selectDirection('sent') }).layoutWeight(1)
      }.width('100%').padding(3).borderRadius(13).backgroundColor(Colors.soft)
      Row({ space: 7 }) {
        Select(this.statusOptions).selected(this.statuses.indexOf(this.claimStatus))
          .value(this.statusOptions[this.statuses.indexOf(this.claimStatus)].value as string)
          .font({ size: 13 }).constraintSize({ minHeight: 42 }).backgroundColor(Colors.surface).width(118).accessibilityText('申请状态筛选')
          .onSelect((index: number) => this.selectStatus(this.statuses[index]))
        Text(this.phase === 'loading' ? '正在同步…' :
          (this.phase === 'error' ? '同步失败' : this.claims.length + ' 条记录'))
          .fontSize(12).fontColor(Colors.muted).layoutWeight(1)
        Button('刷新').constraintSize({ minHeight: 42 }).fontSize(12).fontColor(Colors.green).backgroundColor(Colors.surface)
          .onClick(() => { this.load(); })
      }.width('100%')
      if (this.resultStatus.length) {
        Row({ space: 7 }) {
          Text(this.resultLabel()).fontSize(13).fontWeight(FontWeight.Bold).fontColor(Colors.ink).layoutWeight(1)
          if (this.claimStatus !== 'all' && this.claimStatus !== this.resultStatus) {
            Button('查看结果').constraintSize({ minHeight: 36 }).fontSize(12).fontColor(Colors.green).backgroundColor(Colors.surface)
              .onClick(() => this.selectStatus(this.resultStatus))
          }
        }.width('100%').padding(9).backgroundColor(Colors.soft).borderRadius(12)
      }
    }.width('100%').padding({ left: 16, right: 16 }).enabled(!this.busy)
  }

  @Builder
  claimCard(claim: Claim) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Image(categoryArt(claim.category)).width(49).height(52).objectFit(ImageFit.Contain)
          .backgroundColor(Colors.soft).borderRadius(11).accessibilityLevel('no')
        Column({ space: 5 }) {
          Text(claim.itemTitle).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Colors.ink).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(claim.kind === 'found' ? '认领申请' : '寻物线索').fontSize(11).fontColor(Colors.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(claimText(claim.status)).fontSize(11).fontWeight(FontWeight.Bold)
          .fontColor(claim.status === 'pending' ? '#77531C' : claimColor(claim.status))
          .backgroundColor(this.statusFill(claim.status)).padding({ left: 7, right: 7, top: 4, bottom: 4 }).borderRadius(8)
      }.width('100%')
      Text((this.boxDirection === 'received' ? '申请人  ' + claim.senderName : '发布者  ' + claim.ownerName))
        .fontSize(12).fontColor(Colors.muted).width('100%')
      Column({ space: 5 }) {
        Text(this.guidanceTitle(claim.status)).fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor(Colors.ink).width('100%')
        Text(this.guidanceText(claim.status)).fontSize(12).fontColor(Colors.ink)
          .lineHeight(19).width('100%')
      }.width('100%').padding(10).backgroundColor(this.statusFill(claim.status)).borderRadius(10)
      Text('核对说明').fontSize(12).fontWeight(FontWeight.Bold).fontColor(Colors.ink).width('100%')
      Text(claim.proof).fontSize(13).lineHeight(21).fontColor(Colors.ink).width('100%')
      Column({ space: 4 }) {
        Text('联系指引').fontSize(11).fontColor(Colors.muted).width('100%')
        Text(claim.contact).fontSize(13).lineHeight(20).fontColor(Colors.ink).width('100%')
      }.width('100%').padding(9).backgroundColor(Colors.paper).borderRadius(10)
      Row() {
        Text((claim.status === 'pending' ? '提交  ' : '更新  ') +
          new Date(claim.status === 'pending' ? claim.createdAt : claim.updatedAt)
            .toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false }))
          .fontSize(11).fontColor(Colors.muted).layoutWeight(1)
        Button('查看启事 ›').constraintSize({ minHeight: 36 }).fontSize(12).fontColor(Colors.green).backgroundColor(Colors.surface)
          .onClick(() => { this.stack.pushPath({ name: 'Detail', param: claim.itemId }); })
      }.width('100%')
      if (claim.status === 'pending') {
        if (this.boxDirection === 'received') {
          Row({ space: 8 }) {
            Button('不通过').constraintSize({ minHeight: 43 }).fontSize(13).fontColor(Colors.red).backgroundColor('#FAEBE7')
              .layoutWeight(1).onClick(() => this.confirm(claim, 'reject'))
            Button('确认寻回').constraintSize({ minHeight: 43 }).fontSize(13).fontWeight(FontWeight.Bold).backgroundColor(Colors.green)
              .layoutWeight(2).onClick(() => this.confirm(claim, 'accept'))
          }.width('100%')
        } else {
          Button('取消申请').constraintSize({ minHeight: 42 }).width('100%').fontSize(13).fontColor(Colors.red)
            .backgroundColor('#FAEBE7').onClick(() => this.confirm(claim, 'cancel'))
        }
      }
    }.padding(13).width('100%').backgroundColor(Colors.surface).borderRadius(16)
      .border({ width: 1, color: Colors.stroke })
  }

  build() {
    NavDestination() {
      Column({ space: 8 }) {
        PageHeader({ title: '认领与线索', back: true, onBack: () => this.back() })
        this.controls()
        if (this.phase !== 'ready') {
          StatePanel({ phase: this.phase, error: this.error,
            emptyText: this.claimStatus === 'pending' ? '暂无待核对申请' : '当前筛选没有申请',
            emptyAction: this.claimStatus === 'all' ? '刷新信息' : '查看全部申请', onRetry: () => {
              if (this.phase === 'empty') { this.claimStatus = 'all'; }
              this.load();
            } }).layoutWeight(1)
        } else {
          if (this.error.length) { Text(this.error).fontSize(12).fontColor(Colors.red).width('90%') }
          List({ space: 10 }) {
            ForEach(this.claims, (claim: Claim) => {
              ListItem() { this.claimCard(claim) }
            }, (claim: Claim) => claim.id)
          }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 16 }).width('100%')
            .enabled(!this.busy).scrollBar(BarState.Auto)
        }
      }.width('100%').height('100%').backgroundColor(Colors.paper)
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
      const destination = context.pathInfo.param as string;
      this.boxDirection = destination === 'sent' || destination === 'sent-history' ? 'sent' : 'received';
      this.claimStatus = destination === 'sent-history' ? 'all' : 'pending';
    }).onShown(() => { this.active = true; this.load(); })
      .onHidden(() => { this.active = false; this.generation++; })
      .onBackPressed(() => { this.back(); return true; })
  }
}
