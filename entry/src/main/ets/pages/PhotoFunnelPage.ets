import { CategoryChart } from '../components/Charts';
import { Colors, PageHeader, SegmentTab, StatePanel, AmbientBackground } from '../components/Common';
import { CountPoint, PhotoFunnel } from '../model/Models';
import { Api } from '../service/Api';

@ComponentV2
export struct PhotoFunnelPage {
  @Local days: number = 7;
  @Local phase: string = 'loading';
  @Local error: string = '';
  @Local data: PhotoFunnel | null = null;
  private stack: NavPathStack = new NavPathStack();
  private generation: number = 0;

  async load(): Promise<void> {
    const ticket = ++this.generation;
    this.phase = 'loading';
    this.error = '';
    try {
      const data = await Api.photoFunnel(this.days);
      if (ticket !== this.generation) { return; }
      this.data = data;
      this.phase = data.recognized ? 'ready' : 'empty';
    } catch (error) {
      if (ticket !== this.generation) { return; }
      this.error = (error as Error).message;
      this.phase = 'error';
    }
  }

  points(): CountPoint[] {
    if (this.data === null) { return []; }
    return [
      { label: '完成识别', count: this.data.recognized },
      { label: '找到候选', count: this.data.matched },
      { label: '提交申请', count: this.data.applied },
      { label: '确认寻回', count: this.data.recovered }
    ];
  }

  build() {
    NavDestination() {
      Stack() {
        AmbientBackground()
        Column({ space: 10 }) {
        PageHeader({ title: '拍照找物统计', back: true, onBack: () => { this.stack.pop(); } })
        Row({ space: 4 }) {
          ForEach([7, 14, 30], (days: number) => {
            SegmentTab({ label: days + ' 日', selected: this.days === days, onSelect: () => {
              if (this.days !== days) { this.days = days; this.load(); }
            } }).layoutWeight(1)
          }, (days: number) => days.toString())
        }.width('100%').padding(4).backgroundColor(Colors.soft).borderRadius(13)
        if (this.data !== null && (this.phase === 'ready' || this.phase === 'empty')) {
          Text(this.data.start + ' 至 ' + this.data.end + ' · 按查找日期').fontSize(12)
            .fontColor(Colors.muted).width('100%')
        }
        if (this.phase === 'ready') {
          Scroll() {
            Column({ space: 12 }) {
              CategoryChart({ title: '拍照找物各阶段', unit: '次', points: this.points() })
              Text('同一次查找在每个阶段最多计一次。只有从该次查找的候选启事发起的申请才计入；寻回以发布者确认交接为准。')
                .fontSize(12).fontColor(Colors.muted).lineHeight(19).width('100%')
              Button('刷新统计').width('100%').constraintSize({ minHeight: 44 }).backgroundColor(Colors.soft)
                .fontColor(Colors.green).onClick(() => { this.load(); })
            }.width('100%')
          }.layoutWeight(1).align(Alignment.Top)
        } else {
          StatePanel({ phase: this.phase, error: this.error, emptyText: '这段时间还没有完成识别的拍照查找',
            emptyAction: '刷新统计', onRetry: () => { this.load(); } }).layoutWeight(1)
        }
        }.width('100%').height('100%').padding({ left: 16, right: 16 })
      }.width('100%').height('100%')
    }.hideTitleBar(true).onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
    }).onShown(() => { this.load(); }).onHidden(() => { this.generation++; })
  }
}
