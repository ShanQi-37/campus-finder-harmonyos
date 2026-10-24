# 拾光校园

基于 HarmonyOS 的校园失物招领与寻回数据可视化课程项目。面向学生提供失物广场、物品详情、信息发布、我的记录和互助统计五个业务页面。

选题状态：已确定开发方向，尚待本人在班级登记并确认不重复。

## 开发范围

- 原生 ArkTS 与 ArkUI，状态管理使用 V2 装饰器。
- Navigation 管理页面栈，详情页接收物品 ID，发布成功后返回并刷新数据。
- 独立 Node.js Mock HTTP 服务，支持列表、筛选、详情、发布、确认寻回和统计。
- 网络加载、错误、空数据、重试以及请求过期保护。
- 可复用卡片、状态面板和图表组件；图表绑定服务端实时聚合数据。
- 在 DevEco Studio Previewer 验证完整操作过程。

## 过程与署名

工程由 Codex 根据课程项目需求协助实现。保留经隐私处理的真实阶段 Git 记录；报告仅记录已实现功能和实际验证结果。提交者应阅读代码并能够解释设计、状态更新与接口处理。

## 评分对应

| 评分项 | 实现目标 |
| --- | --- |
| 选题与需求 10 | 明确校园场景、角色和业务流程，班级登记由本人确认 |
| UI 与容器 20 | Row、Column、List、Grid、Scroll 响应式布局 |
| 自定义组件与状态 20 | ComponentV2、Local、Param、Event、ObservedV2、Trace |
| Navigation 15 | 五页面导航、物品 ID 传递、返回栈与发布结果处理 |
| 网络交互 15 | 真实 HTTP 请求与加载、失败、空数据处理 |
| Git 10 | 从初始化开始分阶段提交，附真实提交截图 |
| 代码与文档 10 | 分层、接口说明、运行指南、学校格式报告 |
| 数据可视化 +10 | 类别柱状图、七日趋势图、寻回率环图，操作后重新请求统计 |

源码和报告为课程演示用途，Mock 物品与联系人均为虚构数据。

## 运行

环境：DevEco Studio 26.0，已安装 HarmonyOS API 26 SDK 与 Previewer。工程未依赖第三方 ArkUI 或 Node 软件包。Node.js 18+ 可启动 Mock；本机 DevEco 自带 Node 24.14.1。

```powershell
# 在工程目录运行，窗口保持开启
powershell -ExecutionPolicy Bypass -File .\scripts\start-mock.ps1
# 另一个窗口编译；脚本会兼容中文父目录
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
# HTTP 测试（默认使用本机 DevEco Node）
& 'E:\DevEco Studio\tools\node\node.exe' --test .\mock\server.test.cjs
```

DevEco 路径不同时，在脚本参数中指定 `-DevEcoPath`。使用 UTF-8 编码的源码。Hvigor 不支持中文工程路径，编译脚本将工程复制到临时英文目录，完成后把 HAP 保存到 outputs；原始源码不变。要进行 Previewer 调试，请在 IDE 打开脚本输出的英文目录，选择 Index.ets，并点击右侧眼睛图标。先启动 Mock，再打开 Previewer，失败时可以点击页面上的“重新加载”。预览器不需要真机、模拟器或应用签名。

默认 HTTP 地址为 service/Api.ets 的 BASE_URL。本机 Previewer 直接连接127.0.0.1:4524。若另外使用完整模拟器，需用 hdc rport 映射相同端口；课程演示以 Previewer 为主。HAP 为未签名调试产物，不代表发布包。

## 源码位置

- `pages`：广场、详情、两步发布、我的记录和统计页面；Navigation 集中映射。
- `components`：物品卡片、页面标题、状态面板、筛选按钮与三种图表。
- `model`：接口模型、ObservedV2/Trace 列表状态与请求序号。
- `service`：NetworkKit 请求、超时、状态码和解析异常处理。
- `mock`：本机 HTTP 服务、JSON 持久化、动态统计和集成测试。

接口与边界详见 [API.md](docs/API.md)，复现操作详见 [DEMO.md](docs/DEMO.md)，逐项要求与验证状态见 [ASSESSMENT.md](docs/ASSESSMENT.md)。框架与 API 说明以华为官方文档和本机 SDK 为依据；UI 仅参考 FreeUID 的应用分类与卡片信息组织思路，页面、矢量图标与业务代码为本项目新写内容。

2026年10月24日复核优化：空结果可一键清空筛选；详情确认期间阻止提前返回；Mock拒绝非对象JSON和畸形ID，先持久化完整快照再更新内存。最新构建通过，HTTP测试8项通过、0项失败；空结果恢复已在Previewer实际复验。

学校提交源码包排除 .hvigor、.git、.idea、oh_modules 与构建缓存；原始本地仓库独立保留。公开仓库不包含个人报告、Git bundle或本机日志。
