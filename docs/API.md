# HTTP 接口和状态机

默认 `http://127.0.0.1:4524`；独立Node服务，ArkUI通过NetworkKit请求。统一 `{code:0,message:"ok",data:...}`，失败HTTP400/403/404/409/413/500/503，message可读；客户端检查状态、解析、嵌套对象与统计恒等式，finally销毁HTTP对象。

App 通过 `POST /api/auth/register` 读取 `{phone,student,displayName,password}` 创建本机账号。手机号与学号至少提供一项，二者绑定到同一身份，已占用的标识返回 409。昵称选填，密码使用随机盐和 scrypt 派生值保存。注册成功和 `POST /api/auth/login` 成功均返回 `{token,actor,displayName}`。登录提交 `{method,account,password}`，`method` 为 `phone` 或 `student`。业务请求携带 `Authorization: Bearer <token>`，退出时调用 `POST /api/auth/logout` 撤销会话。已发布附件和 `/health` 可直接读取。本机账号通过密码登录。

| 方法 | 路径 | 功能 |
| --- | --- | --- |
| GET | /health | 服务版本、记录数量和 AI 配置状态 |
| GET | /api/items | 列表、搜索、组合筛选、分页 |
| GET | /api/items/:id | 详情、联系可见性、收藏、动态记录 |
| POST | /api/items | 新建，201；requestId支持同身份重试幂等 |
| POST | /api/items/:id/update | 编辑本人open启事 |
| POST | /api/items/:id/resolve | 本人确认寻回，幂等 |
| POST | /api/items/:id/withdraw | 本人撤回，取消待核对申请 |
| POST | /api/items/:id/restore | 本人恢复已撤回启事 |
| POST | /api/items/:id/favorite | {saved:boolean}，显式幂等收藏 |
| POST | /api/items/:id/claims | 他人提交认领或线索，201 |
| GET | /api/claims?direction=received或sent | 当前身份收到/发出的申请 |
| POST | /api/claims/:id/accept或reject或cancel | 发布者接受/拒绝，申请者取消 |
| GET | /api/statistics?days=7或14或30&category=all或类别&anchor=today或latest | 动态聚合 |

`/health` 的 `data.ai` 含 `imageConfigured` 和 `textConfigured` 两个布尔值。它们反映本机服务是否已装载模型配置。接口不发出模型请求。联调方法见 [AI 接口配置](AI_SETUP.md)。

列表参数kind=all/lost/found，category=all或四类别，keyword匹配标题、地点或描述（最多80字），owner可为空、all或三种合法体验身份，status=all/open/resolved/withdrawn，sort=latest/oldest，saved=true/false，page正整数，pageSize=1..100。客户端每页 6 条，接口默认 100。返回items,total,page,pageSize,hasMore。撤回启事仅本人管理列表可见，他人访问详情404。

搜索词按空白分隔，每个词至少出现在一个可搜索字段，词序不影响结果。关键词与字段均统一全角、半角和字母大小写。创建时间相同的启事按 ID 排序，分页顺序固定。

发布日明细同时传递 `publishedFrom` 与 `publishedTo`。两个参数使用 `YYYY-MM-DD`，按 `createdAt` 的上海日期匹配并包含首尾。无效日期、反向区间和未来结束日期返回 400。日期条件可与类别和状态组合，分页在筛选后执行。统计明细使用公开列表的可见范围，已撤回启事不计入有效结果。

确认寻回明细同时传递 `resolvedFrom`、`resolvedTo` 和 `status=resolved`。日期格式和区间校验与发布日明细一致；缺少任一日期、未指定已寻回状态均返回 400。结果只含具有可靠确认时间的记录，并按该时间执行 `sort=latest/oldest` 排序和分页，而不是按发布时间排序。

发布/编辑字段：title2–36字、location2–30字、description8–300字、contact2–60字、kind、category、occurredAt（可选，默认今日，合法YYYY-MM-DD且不得晚于上海当日）、requestId（可选，提供时必须为1–80字非空字符串）。服务端生成UUID与createdAt。编辑保留id/owner/createdAt；已有待核对申请时禁止改变类型/分类，防止证据指向变化。其余线索可补充，核对时以当前启事为准。

Item还有ownerName,status,updatedAt,resolvedAt,history[{label,at}],saved,myPending,claimCount,contactVisible。联系指引仅所属身份或已接受申请者可见；其他响应不返回原联系内容。

申请字段proof8–240字、contact2–60字。Claim含id,itemId,itemTitle,kind,category,sender,owner,senderName,ownerName,proof,contact,status,createdAt,updatedAt；只在当前身份参与的申请列表中返回。不能申请本人或结束的启事，同身份同物品只允许一份pending；拒绝/取消后可重提。

启事：open→resolved；open→withdrawn→open。已寻回不再编辑/撤回/恢复。申请：pending→accepted/rejected/cancelled。接受仅由启事所属身份执行，并在同一快照中将物品设resolved、当前申请accepted、其他pending设rejected；直接寻回或撤回将pending设cancelled。相同目标的重复处理返回原结果，冲突目标409。必须实际核实并交接后才在界面确认。

发布统计按 `createdAt` 的上海日期筛选 7/14/30 日，返回包含首尾的 `windowStart` 和 `windowEnd`。默认 `anchor=today` 截至今天；`anchor=latest` 截至所选类别最近一条有效启事的发布日期，找不到有效记录时仍以今天为终点。两个模式都排除未来记录，`updatedAt` 始终是本次统计时间。

已撤回启事独立计入 `withdrawn`，恢复后重新计入原发布日。`total = open + resolved = lost + found = sum(categories.count) = sum(trend.count)`；`sum(trend.resolved) = resolved`。`trend` 的每点含 `label`（月-日）、`count`（有效启事数）和 `resolved`（其中当前已寻回数）。确认寻回后会更新该启事**发布日**的寻回数量。`recoveryRate` 为四舍五入后的百分比，无数据为 0；`pendingClaims` 只计范围内有效启事的待核对申请。

`recoveryTrend` 是独立的确认寻回曲线，每点含 `label` 和 `count`，窗口由 `recoveryWindowStart` 与 `recoveryWindowEnd` 包含首尾。`anchor=today` 与发布窗口一样截至今天；`anchor=latest` 单独寻找最近可靠确认日，因此较早发布、窗内才确认的记录仍可进入寻回曲线。可靠确认时间优先取最后一条有效的「发布者确认寻回」或「核对申请通过，确认完成交接」动态；没有此类动态时，只接受有效且不同于 `createdAt` 的显式 `resolvedAt`。两条确认路径写入相同的实际变更时间。

旧版曾把缺失的 `resolvedAt` 补成 `createdAt`，所以这种相同值不被视为真实交接时间。缺少可靠时间的已寻回记录仍保留在既有总览中，但不进入 `recoveryTrend` 或确认日期明细；`undatedResolved` 返回当前类别下全部此类已寻回记录数，不限于当前发布窗口。

存储 `mock/runtime/items.json`：`{version:2,items,claims,favorites,drafts}`。兼容旧数组，保留记录并映射旧的其他虚构身份至peer-01。每次完整快照写同目录临时文件→重命名→替换内存；任何写入失败500且内存不变。非对象JSON、异常ID编码、超大请求均拒绝。单进程中读改写同步，不支持多进程同时写文件。

仅本机 `/__test/mode` POST `{mode:"normal"}` 支持normal/error(GET503)/empty/slow(2.5秒)/malformed(GET错误JSON)/shape(GET合法JSON但嵌套结构错误)；界面不暴露，不删除已有数据。演示后恢复normal。接口测试使用隔离临时目录，不改变实际演示数据。


## 第三版 增量接口与规则

| 方法 | 路径 | 返回或业务约束 |
| --- | --- | --- |
| GET | /api/me | posted/open/resolved/saved、incomingPending/outgoingPending、draftTitle/draftUpdatedAt、unreadMatches；当前身份独立摘要 |
| GET | /api/match-alerts | 返回当前用户的 `{alerts,unread}`；可选 `itemId` 按本人启事筛选 |
| GET | /api/match-alerts/:id | 查看当前用户可访问的匹配提醒 |
| POST | /api/match-alerts/:id/read | 标记当前用户对该提醒已读，返回该提醒，允许重复调用 |
| GET | /api/draft | {exists,input,updatedAt}；无草稿时input为null |
| POST | /api/draft | PublishInput同名字段，允许内容未填完整；每个身份一份草稿，保存完整替换 |
| GET | /api/items/:id/matches | {matches:[{item,reasons}]}，最多5条；Item沿用当前身份的联系可见性 |

草稿字符串字段必须存在并遵守标题36、地点30、描述300、联系60、日期10字上限；kind/category合法，requestId为1–80字非空标识。草稿允许日期尚未填写或未完成，正式提交仍执行完整日期和内容校验。成功发布的快照同时移除当前身份且requestId一致的草稿；发布失败不清理。旧发布请求的幂等重试也不会清理之后保存的另一份草稿。旧数组和不含drafts的第二版对象兼容读取，不重置原记录。

相似线索仅从open启事匹配：同类别、相反kind、与原启事不同owner，排除自身、结束和撤回记录。相同地点优先，其次包含关系或共享连续两字，再看发生日期相差不超过3日；并列按创建时间倒序、ID稳定排序。返回可解释理由，不返回概率、不声称AI识别，也不证明物品归属。已结束启事返回空候选，他人的撤回启事404。

智能匹配提醒包含 `id,source,candidate,reasons,createdAt,unread`，其中 `source` 是当前用户的启事。两条启事需来自不同账号、类型相反、分类相同、状态为待寻回，且发生日期相差最多七天。匹配会比较标题及已有的视觉识别物品名，并要求地点相近或至少两项共同的识别外观特征。双方共享稳定的匹配 ID，各自保存已读状态。启事失效后会从列表移除。详情和已读接口仅对启事双方可用，联系方式遵循启事详情权限。

分页请求在数据变化后超出末页时自动返回最后有效页；空集合返回第1页。客户端使用返回page更新页码，避免最后一页操作后困在无效页。异常恢复或重置筛选时，列表与首页实时摘要同时重新请求。

## 系统检查后的边界修复

请求体按Buffer收集、限制总字节数后一次严格解码UTF-8，拒绝非法编码，避免中文跨网络数据块时损坏。无效URL、非法筛选枚举返回400，服务保持可用。

发布重试按身份和requestId查找原记录，并以初次规范化字段的SHA256核对内容；同标识不同内容返回409，用户应在我的记录中编辑已发布启事。匹配的重试返回原记录并原子清理同一草稿，不删除另一requestId的新草稿。保存初次指纹使发布后编辑不破坏原始请求重试；升级前旧记录没有初次指纹，只能按当前内容核对。省略日期的重试沿用原发生日期。requestId与内部指纹不返回客户端。

统计用同一个上海日期锚点生成窗口及每日标签，同时排除窗口之前和今日之后的创建日期，防止午夜和未来记录造成总量与趋势不一致。ResponseGuard对所有读写响应中UI使用的字段、分页、待办及统计关系进行校验；合法JSON的错误结构同样进入可读错误与重试流程。shape模式仅用于本机故障验证，结束恢复normal。

## 第四版管理接口

`POST /api/draft/discard` 接收已读取或保存草稿的`{requestId,updatedAt}`。服务端仅操作当前身份；版本一致才原子舍弃，返回`{exists:false,input:null,updatedAt:''}`。不存在时幂等成功，不影响已发布启事；版本冲突409，参数无效400，磁盘失败500并回滚。每次草稿保存的updatedAt严格递增，即使同一毫秒连续保存也能区分版本。

`GET /api/claims` 新增status=all/pending/accepted/rejected/cancelled，默认all，继续结合direction=received/sent和当前身份过滤；pending是当前结果内待核对数。客户端任务入口默认pending，空状态可切回全部申请。个人启事复用列表的status筛选；withdrawn仅本人owner列表可见，恢复后退出撤回结果。

## 启事媒体和拍照找物

| 方法 | 路径 | 输入和结果 |
| --- | --- | --- |
| POST | `/api/media?type=photo或video&analyze=true或false` | 原始二进制。照片 JPEG/PNG 至多 8 MiB，视频 MP4 至多 24 MiB。返回 `{id,type,recognition,analysisStatus}`，可用状态为 recognized、uncertain、unavailable、failed、skipped。 |
| GET / HEAD | `/api/item-media/:itemId/:mediaId` | 仅提供可见且正在使用此附件的启事媒体。支持字节范围，撤回后返回 404。 |
| GET / HEAD | `/api/item-media/:itemId/:mediaId/cover` | 读取识别成功且已发布的视频 JPEG 封面。旧视频首次读取时从已保存的视频补取一帧。附件未发布、已撤回或没有封面时返回 404。 |
| POST | `/api/media/search` | JPEG/PNG 二进制。返回 `{recognition,matches}`，最多五条其他身份发布的待寻回招领启事。 |

分类结果含 `category`、`object`、`features`。后端限制分类值和特征长度。拍照找物比对识别的名称和特征与候选的标题、描述和已有的识别特征，没有可用候选时返回空列表。联系指引沿用启事的权限规则。

草稿、发布及编辑可用 `mediaId` 引用同一身份上传的附件。明确传空字符串可移除附件。草稿和启事读取时同时返回附件类型 `mediaType`。老记录允许两个字段均缺省。媒体二进制与元数据保存在同一运行目录下。每次上传时清理该身份未被启事或草稿引用的旧附件，保留最近八份。查找用照片只作当次处理。坏格式返回 415，超过大小返回 413，模糊照片或无法解码返回 422，视觉模型调用失败返回 502，缺少配置返回 503。

## 认领核对附件

| 方法 | 路径 | 输入和结果 |
| --- | --- | --- |
| POST | `/api/items/:id/claim-evidence?type=photo` 或 `type=video` | 待寻回招领启事的申请人上传 JPEG、PNG 或 MP4，返回附件 `id`、`type` 和 `analysisStatus: "skipped"`。 |
| GET / HEAD | `/api/claims/:id/evidence` | 已登录的申请人或启事发布者可以读取该申请的附件，支持字节范围。缺少附件或无权访问时返回 404。 |

提交认领时可省略 `evidenceId`，也可引用同一演示身份为该启事上传的单个附件。含附件的申请返回 `evidenceType`。核对附件存于本机数据目录的 `claim-evidence` 下，仅做媒体格式处理，不发送给视觉模型。

## 描述找物和拍照统计

`POST /api/search/interpret` 接收 `{query}`，1 至 160 字。以请求当日的上海日期供模型换算相对日期，返回 `keyword`、`location`、`category`、`occurredFrom` 与 `occurredTo`。未知类别为 `all`，未知日期两端为空。模型条件经过长度、枚举、日期及范围校验。条件可编辑；确认后查询 `GET /api/items?kind=found&status=open`。列表新增可选的 `location` 子串条件及 `occurredFrom`、`occurredTo` 首尾包含范围，依据启事发生日期。自然语言输入只作当次解析。

`POST /api/media/search` 在完成识别后额外返回 `searchId`，保存查找身份、上海日期和候选 ID 供统计，照片处理后丢弃。从候选进入详情并提交申请时，客户端随申请发送该 ID。后端只接受当前身份本次返回的候选。未传参数的普通申请继续按原流程处理。

`GET /api/statistics/photo-search?days=7` 支持 7／14／30 天，按截至今日的查找日期聚合，返回 `{days,start,end,recognized,matched,applied,recovered}`。每个阶段按查找 ID 去重，只有关联申请已获发布者通过才计为确认寻回。统计响应仅含汇总数量。
