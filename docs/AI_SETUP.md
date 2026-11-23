# AI 接口配置与联调

拾光校园的 HarmonyOS 客户端请求本机 Mock。Mock 通过同一套视觉模型配置处理图片、短视频抽帧及自然语言描述。广场文字搜索、发布、认领和统计仍使用项目内置 HTTP 接口。

## 准备资料

| 项目 | 从哪里获取 |
| --- | --- |
| API 平台 | 可使用 OpenAI 或 Chat Completions 兼容服务。接口需要同时支持文字输入、图片输入及 JSON 对象输出。 |
| 模型名称 | 从所选平台的模型列表复制可用模型 ID。使用 OpenAI 时可将 `gpt-5.4-mini` 作为示例，具体权限以账号为准。 |
| API Base URL | OpenAI 使用 `https://api.openai.com/v1`。兼容服务使用平台给出的 Base URL，后端会添加 `/chat/completions`。 |
| API 密钥 | 由你在平台控制台创建，在本机 PowerShell 隐藏输入。启动脚本将其传给后端进程，关闭后恢复终端原环境。 |
| 测试样图 | 准备一张可用于演示的 JPEG 或 PNG，单件物品、光线清楚，避开人脸、证件号码和联系方式。照片、视频处理需本机 FFmpeg。 |

使用 OpenAI 可从 [API Keys 页面](https://platform.openai.com/api-keys)创建密钥，模型能力见 [GPT-5.4 mini](https://developers.openai.com/api/docs/models/gpt-5.4-mini) 和 [Chat Completions 视觉输入说明](https://developers.openai.com/api/docs/guides/images-vision?api-mode=chat)。请按所选平台的实际计费和额度使用联调请求。

## 启动本机后端

先停止原来占用 4524 端口的项目 Mock，在仓库根目录打开 PowerShell。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-mock.ps1 -ConfigureVision
```

依次输入模型 ID、Base URL 和密钥。用默认 OpenAI 地址时，Base URL 提示处直接回车。保持终端窗口运行。也可直接为启动脚本传入非敏感的 `-VisionModel` 和 `-VisionBaseUrl`。已有 `CAMPUS_VISION_API_KEY`、`CAMPUS_VISION_MODEL` 和可选的 `CAMPUS_VISION_BASE_URL` 时，可沿用常规启动命令。

## 分步检查

另开 PowerShell，在同一仓库根目录运行以下命令。

```powershell
# 仅检查本地服务和配置状态，无外部模型请求
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-ai.ps1

# 发送一次虚构描述，验证 AI 文本提取
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-ai.ps1 -CheckText

# 发送一次样图，验证照片识别和候选查询
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-ai.ps1 -PhotoPath 'C:\样图\水杯.jpg'
```

状态检查中的 `imageConfigured` 和 `textConfigured` 显示本机已装载对应配置。请求验证通过后可在应用中测试「描述找物」「拍照找物」和「招领启事」的分类与文案建议。图像联调会产生一条拍照查找统计，因此课堂演示请使用隔离的虚构数据。

| 表现 | 排查顺序 |
| --- | --- |
| 本地无法连接 | 确认服务进程与 4524 端口。若用模拟器，再检查 `hdc rport tcp:4524 tcp:4524`。 |
| 状态显示未配置或返回 503 | 用配置命令重启，核对模型 ID 和密钥均已输入。媒体请求的 FFmpeg 提示需检查 PATH 或 `CAMPUS_FFMPEG`。 |
| 文本或图片请求返回 502 | 检查 API 平台连通性、权限和余额，核对模型 ID、Base URL 及图片／JSON 支持情况。 |
| 图片提示无法识别或格式错误 | 确认是有效 JPEG/PNG，换用清晰的单物品照片。候选为 0 表示当前启事未匹配到合适结果。 |

项目的请求、响应字段见 [接口文档](API.md)。
