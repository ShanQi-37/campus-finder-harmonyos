# HTTP 接口

默认地址 `http://127.0.0.1:4524`。服务独立于 ArkUI 页面运行，通过 `@kit.NetworkKit.http` 请求，响应为 JSON。所有示例数据均为虚构内容。

统一响应：`{ "code": 0, "message": "ok", "data": ... }`。HTTP 非 2xx 表示失败，code 对应 HTTP 状态码。客户端会处理连接失败、超时、非 2xx、JSON 解析失败及列表/统计结构缺失，并在 finally 中销毁请求对象。

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| GET | `/health` | 检查服务状态 |
| GET | `/api/items` | 列表与组合筛选 |
| GET | `/api/items/:id` | 详情；不存在返回 404 |
| POST | `/api/items` | 发布；成功返回 201 |
| POST | `/api/items/:id/resolve` | 确认本人记录已寻回；重复操作幂等 |
| GET | `/api/statistics` | 全部记录的动态聚合统计 |

列表 query：kind 为 all/lost/found；category 为 all 或“证件卡片／电子数码／生活用品／学习文具”；keyword 匹配标题、描述、地点；owner 为空时不限，demo-user 表示演示身份。筛选由服务端完成。响应 data 为 `{items: Item[], total: number}`。

Item 字段：id、title、category、kind、location、description、owner、status、contact、occurredAt、createdAt。status 为 open/resolved；createdAt 为 ISO 时间，occurredAt 为上海时区 YYYY-MM-DD 日期。

发布请求包含 title（2—36字）、category、kind、location（2—30字）、description（8—300字）、contact（2—60字）。前后端均校验；服务端固定使用演示身份 demo-user，创建 UUID 和时间，写入本地 JSON。此身份用于课堂演示，不代表登录认证或生产环境权限保障。

统计 data 字段：total、open、resolved、recoveryRate、categories、trend、updatedAt。categories 为 `{label,count}[]`；trend 为含今日在内近七日（上海时区）的发布数量，日期 label 为 MM-DD。每条物品对应一条启事，寻回率为 `round(resolved / total * 100)`；total=0 时返回0。类别计数、趋势与寻回数均从同一份当前记录计算。

发布或确认寻回后，页面返回时重新请求；进入统计页或点击刷新也会重新聚合。前端不自行伪造成功状态或随机图表数值。

## 容错测试

仅监听本机回环地址的 `/__test/mode` 接口用于可重复测试，不在产品界面暴露。POST JSON `{"mode":"normal"}` 可切换 normal/error/empty/slow/malformed；分别为正常、GET返回503、GET返回空数据、2.5秒延迟、GET返回无效JSON。恢复时务必切回 normal。测试模式不删除已保存记录。

服务运行数据保存在 mock/runtime/items.json，已排除 Git 与课程源码包。无该文件时自动生成12条演示记录；测试程序使用独立临时文件验证重启持久化，不改动演示服务数据。

服务未实现真实账户、图片上传、审核或多进程数据库锁，限本机课程演示使用。
