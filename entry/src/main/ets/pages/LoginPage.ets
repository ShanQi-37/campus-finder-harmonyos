import { AmbientBackground, Colors, FontSize, Radius, SegmentTab } from '../components/Common';
import { LoginSession } from '../model/Session';
import { Api } from '../service/Api';

interface DemoAccount {
  label: string;
  phone: string;
  student: string;
}

@ComponentV2
export struct LoginPage {
  @Param note: string = '';
  @Event onLogin: (session: LoginSession) => void = () => {};
  @Local method: string = 'phone';
  @Local account: string = '';
  @Local password: string = '';
  @Local error: string = '';
  @Local pending: boolean = false;
  @Local showDemo: boolean = false;
  @Local registering: boolean = false;
  @Local phone: string = '';
  @Local student: string = '';
  @Local displayName: string = '';
  private readonly demoAccounts: DemoAccount[] = [
    { label: '校园同学', phone: '10000000001', student: '20260001' },
    { label: '互助同学', phone: '10000000002', student: '20260002' },
    { label: '志愿同学', phone: '10000000003', student: '20260003' }
  ];

  selectMethod(method: string): void {
    if (this.method === method) { return; }
    this.method = method;
    this.account = '';
    this.password = '';
    this.error = '';
  }

  setRegistration(registering: boolean): void {
    this.registering = registering;
    this.password = '';
    this.error = '';
    this.showDemo = false;
  }

  async submit(): Promise<void> {
    if (this.pending) { return; }
    const account = this.account.trim();
    const valid = this.method === 'phone' ? /^\d{11}$/.test(account) : /^\d{6,20}$/.test(account);
    if (!valid) {
      this.error = this.method === 'phone' ? '请输入 11 位手机号' : '请输入 6 至 20 位数字学号';
      return;
    }
    if (!this.password.length) { this.error = '请输入密码'; return; }
    this.pending = true;
    this.error = '';
    try { this.onLogin(await Api.login(this.method, account, this.password)); }
    catch (error) { this.error = (error as Error).message; }
    finally { this.pending = false; }
  }

  async register(): Promise<void> {
    if (this.pending) { return; }
    const phone = this.phone.trim();
    const student = this.student.trim();
    if (!phone && !student) { this.error = '手机号或学号至少填写一项'; return; }
    if (phone && !/^\d{11}$/.test(phone)) { this.error = '请输入 11 位手机号'; return; }
    if (student && !/^\d{6,20}$/.test(student)) { this.error = '请输入 6 至 20 位数字学号'; return; }
    if (!this.password.trim() || this.password.length < 8) { this.error = '密码至少 8 位'; return; }
    this.pending = true;
    this.error = '';
    try { this.onLogin(await Api.register(phone, student, this.displayName.trim(), this.password)); }
    catch (error) { this.error = (error as Error).message; }
    finally { this.pending = false; }
  }

  @Builder
  form() {
    Column({ space: 12 }) {
      Row({ space: 4 }) {
        SegmentTab({ label: '手机号登录', selected: this.method === 'phone', onSelect: () => this.selectMethod('phone') }).layoutWeight(1)
        SegmentTab({ label: '学号登录', selected: this.method === 'student', onSelect: () => this.selectMethod('student') }).layoutWeight(1)
      }.width('100%').padding(3).borderRadius(Radius.md).backgroundColor(Colors.soft)
      TextInput({ placeholder: this.method === 'phone' ? '请输入手机号' : '请输入学号', text: this.account })
        .type(InputType.Number).maxLength(this.method === 'phone' ? 11 : 20).height(48)
        .backgroundColor(Colors.paper).borderRadius(Radius.sm).accessibilityText(this.method === 'phone' ? '手机号' : '学号')
        .onChange((value: string) => { this.account = value; this.error = ''; })
      TextInput({ placeholder: '请输入密码', text: this.password }).type(InputType.Password).maxLength(64)
        .height(48).backgroundColor(Colors.paper).borderRadius(Radius.sm).enterKeyType(EnterKeyType.Go)
        .accessibilityText('密码').onChange((value: string) => { this.password = value; this.error = ''; })
        .onSubmit(() => { this.submit(); })
      if (this.error.length || this.note.length) {
        Text(this.error || this.note).fontSize(FontSize.caption).fontColor(Colors.red).width('100%')
      }
      Button(this.pending ? '正在登录…' : '登录').width('100%').constraintSize({ minHeight: 46 })
        .fontWeight(FontWeight.Bold).fontColor('#FFFFFF').backgroundColor(Colors.greenDeep).borderRadius(Radius.sm)
        .onClick(() => { this.submit(); })
    }.width('100%').padding(16).borderRadius(Radius.lg).backgroundColor(Colors.surface)
      .border({ width: 1, color: Colors.stroke }).enabled(!this.pending)
  }

  @Builder
  registrationForm() {
    Column({ space: 12 }) {
      Text('手机号和学号至少填写一项。填写两项后，均可用于登录。')
        .fontSize(FontSize.caption).fontColor(Colors.muted).lineHeight(19).width('100%')
      TextInput({ placeholder: '手机号（11 位）', text: this.phone }).type(InputType.Number).maxLength(11)
        .height(48).backgroundColor(Colors.paper).borderRadius(Radius.sm).accessibilityText('注册手机号')
        .onChange((value: string) => { this.phone = value; this.error = ''; })
      TextInput({ placeholder: '学号（6 至 20 位数字）', text: this.student }).type(InputType.Number).maxLength(20)
        .height(48).backgroundColor(Colors.paper).borderRadius(Radius.sm).accessibilityText('注册学号')
        .onChange((value: string) => { this.student = value; this.error = ''; })
      TextInput({ placeholder: '昵称（选填）', text: this.displayName }).maxLength(24)
        .height(48).backgroundColor(Colors.paper).borderRadius(Radius.sm).accessibilityText('昵称')
        .onChange((value: string) => { this.displayName = value; this.error = ''; })
      TextInput({ placeholder: '设置密码（8 至 64 位）', text: this.password }).type(InputType.Password).maxLength(64)
        .height(48).backgroundColor(Colors.paper).borderRadius(Radius.sm).enterKeyType(EnterKeyType.Go)
        .accessibilityText('注册密码').onChange((value: string) => { this.password = value; this.error = ''; })
        .onSubmit(() => { this.register(); })
      if (this.error.length) {
        Text(this.error).fontSize(FontSize.caption).fontColor(Colors.red).width('100%')
      }
      Button(this.pending ? '正在注册…' : '注册并登录').width('100%').constraintSize({ minHeight: 46 })
        .fontWeight(FontWeight.Bold).fontColor('#FFFFFF').backgroundColor(Colors.greenDeep).borderRadius(Radius.sm)
        .onClick(() => { this.register(); })
    }.width('100%').padding(16).borderRadius(Radius.lg).backgroundColor(Colors.surface)
      .border({ width: 1, color: Colors.stroke }).enabled(!this.pending)
  }

  build() {
    Stack() {
      AmbientBackground({ login: true })
      Scroll() {
        Column({ space: 16 }) {
          Row({ space: 14 }) {
            Image($r('app.media.app_icon')).width(62).height(62).accessibilityLevel('no')
            Column({ space: 4 }) {
              Text(this.registering ? '注册拾光校园' : '登录拾光校园')
                .fontSize(26).fontWeight(FontWeight.Bold).fontColor(Colors.ink)
              Text('校园失物招领').fontSize(FontSize.caption).fontColor(Colors.muted)
            }.alignItems(HorizontalAlign.Start)
          }.width('100%')
          if (this.registering) {
            this.registrationForm()
            Button('返回登录').width('100%').constraintSize({ minHeight: 42 }).fontColor(Colors.greenDeep)
              .backgroundColor(Colors.soft).enabled(!this.pending).onClick(() => this.setRegistration(false))
          } else {
            this.form()
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Button('注册账号').layoutWeight(1).constraintSize({ minHeight: 42 }).fontColor(Colors.greenDeep)
                  .backgroundColor(Colors.surface).border({ width: 1, color: Colors.stroke }).onClick(() => this.setRegistration(true))
                Button(this.showDemo ? '收起演示账号' : '查看演示账号').layoutWeight(1).constraintSize({ minHeight: 42 })
                  .fontColor(Colors.greenDeep).backgroundColor(Colors.soft).onClick(() => { this.showDemo = !this.showDemo; })
              }.width('100%')
              if (this.showDemo) {
                ForEach(this.demoAccounts, (entry: DemoAccount) => {
                  Button(entry.label + ' · ' + (this.method === 'phone' ? entry.phone : entry.student))
                    .constraintSize({ minHeight: 40 }).width('100%').fontSize(FontSize.body).fontColor(Colors.ink)
                    .backgroundColor(Colors.surface).onClick(() => {
                      this.account = this.method === 'phone' ? entry.phone : entry.student;
                      this.password = 'campus123';
                      this.error = '';
                      this.showDemo = false;
                    })
                }, (entry: DemoAccount) => entry.phone)
              }
            }.width('100%').enabled(!this.pending)
          }
        }.width('100%').constraintSize({ maxWidth: 480 }).padding({ left: 20, right: 20, top: 44, bottom: 24 })
      }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto)
    }.width('100%').height('100%')
  }
}
