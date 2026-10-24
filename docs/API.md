# HTTP 接口和状态机

默认 `http://127.0.0.1:4524`；独立Node服务，ArkUI通过NetworkKit请求。统一 `{code:0,message:"ok",data:...}`，失败HTTP400/403/404/409/413/500/503，message可读；客户端检查状态、解析、嵌套对象与统计恒等式，finally销毁HTTP对象。

请求头 `X-Demo-User` 取demo-user/peer-01/peer-02，默认demo-user。固定虚构角色不构成身份认证，仅本机单进程课程演示。联系和证明均使用虚构内容。

| 方法 | 路径 | 功能 |
| --- | --- | --- |
| GET | /health | 服务版本与记录数量 |
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
| GET | /api/statistics?days=7或14或30&category=all或类别 | 动态聚合 |

列表参数kind=all/lost/found，category=all或四类别，keyword匹配标题/地点/描述（最多80字），owner可为空、all或三种合法体验身份，status=all/open/resolved/withdrawn，sort=latest/oldest，saved=true/false，page正整数，pageSize=1..100。客户端每页2条，接口默认100；返回items,total,page,pageSize,hasMore。撤回启事仅本人管理列表可见，他人访问详情404。

发布/编辑字段：title2–36字、location2–30字、description8–300字、contact2–60字、kind、category、occurredAt（可选，默认今日，合法YYYY-MM-DD且不得晚于上海当日）、requestId（可选，提供时必须为1–80字非空字符串）。服务端生成UUID与createdAt。编辑保留id/owner/createdAt；已有待核对申请时禁止改变类型/分类，防止证据指向变化。其余线索可补充，核对时以当前启事为准。

Item还有ownerName,status,updatedAt,resolvedAt,history[{label,at}],saved,myPending,claimCount,contactVisible。联系指引仅所属身份或已接受申请者可见；其他响应不返回原联系内容。

申请字段proof8–240字、contact2–60字。Claim含id,itemId,itemTitle,kind,category,sender,owner,senderName,ownerName,proof,contact,status,createdAt,updatedAt；只在当前身份参与的申请列表中返回。不能申请本人或结束的启事，同身份同物品只允许一份pending；拒绝/取消后可重提。

启事：open→resolved；open→withdrawn→open。已寻回不再编辑/撤回/恢复。申请：pending→accepted/rejected/cancelled。接受仅由启事所属身份执行，并在同一快照中将物品设resolved、当前申请accepted、其他pending设rejected；直接寻回或撤回将pending设cancelled。相同目标的重复处理返回原结果，冲突目标409。必须实际核实并交接后才在界面确认。

统计按createdAt上海日期筛选含今日7/14/30日，按category组合过滤，withdrawn不计入有效总量；恢复后重新计入原发布日。total=open+resolved=lost+found=sum(categories)=sum(trend)。recoveryRate=round(resolved/total*100)，无数据为0；pendingClaims只计所选有效启事的pending，withdrawn独立返回。趋势表示当前有效启事在各发布日的数量，不是不可变的历史快照。

存储 `mock/runtime/items.json`：`{version:2,items,claims,favorites,drafts}`。兼容旧数组，保留记录并映射旧的其他虚构身份至peer-01。每次完整快照写同目录临时文件→重命名→替换内存；任何写入失败500且内存不变。非对象JSON、异常ID编码、超大请求均拒绝。单进程中读改写同步，不支持多进程同时写文件。

仅本机 `/__test/mode` POST `{mode:"normal"}` 支持normal/error(GET503)/empty/slow(2.5秒)/malformed(GET错误JSON)/shape(GET合法JSON但嵌套结构错误)；界面不暴露，不删除已有数据。演示后恢复normal。接口测试使用隔离临时目录，不改变实际演示数据。


## 第三版 增量接口与规则

| 方法 | 路径 | 返回或业务约束 |
| --- | --- | --- |
| GET | /api/me | posted/open/resolved/saved、incomingPending/outgoingPending、draftTitle/draftUpdatedAt；当前身份独立摘要 |
| GET | /api/draft | {exists,input,updatedAt}；无草稿时input为null |
| POST | /api/draft | PublishInput同名字段，允许内容未填完整；每个身份一份草稿，保存完整替换 |
| GET | /api/items/:id/matches | {matches:[{item,reasons}]}，最多5条；Item沿用当前身份的联系可见性 |

草稿字符串字段必须存在并遵守标题36、地点30、描述300、联系60、日期10字上限；kind/category合法，requestId为1–80字非空标识。草稿允许日期尚未填写或未完成，正式提交仍执行完整日期和内容校验。成功发布的快照同时移除当前身份且requestId一致的草稿；发布失败不清理。旧发布请求的幂等重试也不会清理之后保存的另一份草稿。旧数组和不含drafts的第二版对象兼容读取，不重置原记录。

相似线索仅从open启事匹配：同类别、相反kind、与原启事不同owner，排除自身、结束和撤回记录。相同地点优先，其次包含关系或共享连续两字，再看发生日期相差不超过3日；并列按创建时间倒序、ID稳定排序。返回可解释理由，不返回概率、不声称AI识别，也不证明物品归属。已结束启事返回空候选，他人的撤回启事404。

分页请求在数据变化后超出末页时自动返回最后有效页；空集合返回第1页。客户端使用返回page更新页码，避免最后一页操作后困在无效页。异常恢复或重置筛选时，列表与首页实时摘要同时重新请求。

## 系统检查后的边界修复

请求体按Buffer收集、限制总字节数后一次严格解码UTF-8，拒绝非法编码，避免中文跨网络数据块时损坏。无效URL、非法筛选枚举返回400，服务保持可用。

发布重试按身份和requestId查找原记录，并以初次规范化字段的SHA256核对内容；同标识不同内容返回409，用户应在我的记录中编辑已发布启事。匹配的重试返回原记录并原子清理同一草稿，不删除另一requestId的新草稿。保存初次指纹使发布后编辑不破坏原始请求重试；升级前旧记录没有初次指纹，只能按当前内容核对。省略日期的重试沿用原发生日期。requestId与内部指纹不返回客户端。

统计用同一个上海日期锚点生成窗口及每日标签，同时排除窗口之前和今日之后的创建日期，防止午夜和未来记录造成总量与趋势不一致。ResponseGuard对所有读写响应中UI使用的字段、分页、待办及统计关系进行校验；合法JSON的错误结构同样进入可读错误与重试流程。shape模式仅用于本机故障验证，结束恢复normal。
