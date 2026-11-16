# Capture：Lumi 内截图与标注工具实施计划

> 状态：方案定稿，待实施
> 日期：2026-11-16
> 适用仓库：Lumi（插件孵化阶段）、独立 Capture 仓库（抽取阶段）
> 本文件只定义方案、任务与验收，不包含代码改动

## 0. 摘要

Capture 是一个本地优先的 macOS 截图与标注工具：一次快捷键完成区域、窗口、整屏捕获，在轻量编辑器里标注、打码、加文字，然后复制、保存、钉在桌面或进入本地历史库；历史库支持 OCR 全文搜索；同一套引擎提供屏幕与窗口录制。

交付分两段：

1. **插件阶段**：在 Lumi 内新增 `PluginCapture`，先把能力跑通、把交互和性能打磨到可发布水平。截图、OCR、录屏的底层能力从现有插件中抽到宿主无关的 `KitCapture`，避免复制三份采集/编码代码。
2. **独立阶段**：用 `FactoryCapture` + 独立 App shell 把同一套插件目录装配成独立 macOS App，接入付费解锁、沙盒与 App Store 发布流程。该模式与 Lode 的抽取方式一致（`Lode/README.md:5`、`Lode/Packages/FactoryDatabaseManager/Sources/FactoryDatabaseManager/FactoryDatabaseManager.swift:13-42`）。

核心不变量：

- `KitCapture` 不依赖 `KernelCore`、`Provider*`、`LumiUI`，可被 Lumi 插件和独立 App 同时使用。
- 插件之间不互相 import；共享能力下沉到 `KitCapture` / `KitCaptureUI`。
- 原始截图永不修改；标注以矢量文档保存，导出时再合成。
- 屏幕录制、OCR 默认全本地；只有用户显式开启翻译时才发送文字，不发送图片。
- 所有截图/录制都由用户显式触发；没有后台静默采集。

## 1. 目标与非目标

### 1.1 产品目标

| 编号 | 目标 | 可验证结果 |
| --- | --- | --- |
| G1 | 捕获足够快 | 按下热键到可开始框选的中位耗时不超过 250ms，95 分位不超过 400ms（单台 5K 显示器，暖启动） |
| G2 | 标注不破坏原图 | 关闭再打开同一历史条目，原始像素不变，标注仍可继续编辑 |
| G3 | 复制即用 | 在编辑器按 ⌘C 后，可直接粘贴到 Notes、TextEdit、飞书、Slack，标注与透明背景正确 |
| G4 | 历史可找回 | 截图后 1 秒内进入历史库；OCR 完成后可按图中文字搜索到该条目 |
| G5 | 本地优先 | 未开启翻译时，整个截图/标注/OCR/历史链路零网络请求 |
| G6 | 可平滑抽离 | 独立 App 只替换装配入口与付费/权限外壳，不改 `KitCapture` 的业务代码 |

### 1.2 工程目标

- 把现有分散在 `PluginChatScreenshot`、`PluginScreenRecorder`、`PluginOcr` 的采集、权限、OCR、录制能力收敛到 `KitCapture`，同一能力只有一份实现。
- 所有新增包提供 `Tests/TestPlan.md`，通过仓库现有的测试与平台一致性检查。
- Swift 6 并发模型下无数据竞争告警；UI 状态只在主线程写回，写回前校验会话身份。
- 新增代码不复制 GPL 插件的源码到独立仓库；抽取阶段的授权边界单独把关（见第 10 节）。

### 1.3 非目标

- 不做云同步、团队共享、在线图床、账号体系。
- 不做视频剪辑、字幕、转码、直播推流；录制只负责“录下来并入库”。
- 不做 Windows / iOS 版本；代码按 macOS 14+ 设计，包声明保留 iOS 平台仅为与仓库现有包结构一致，macOS 专属源码用 `#if os(macOS)` 隔离。
- 不做通用图片管理/相册；历史库只管理 Capture 自己产生的资产。
- 不做系统级截图快捷键的接管；不覆盖 ⌘⇧3/4/5。
- 不在首版做区域录制、滚动录屏、摄像头画中画。
- 不做自动上传、自动 OCR 云端识别、自动翻译。

## 2. 用户与核心任务

### 2.1 用户画像

| 画像 | 典型诉求 | 对产品的关键要求 |
| --- | --- | --- |
| 开发者 | 截报错、截 UI、圈重点、贴到 issue/IM | 快捷键顺手、复制快、标注不挡代码、历史能搜 |
| 产品/设计 | 截多屏、标注流程、发给同事 | 多屏坐标正确、箭头/文字清晰、导出尺寸可控 |
| 运营/客服 | 截对话、打码手机号、做说明图 | 马赛克/模糊可靠、步骤编号、保存文件名可读 |
| 教师/培训 | 截课件、做长图、录操作 | 滚动截图、录制稳定、文件可找回 |
| 普通用户 | 偶尔截图、钉在桌面参照 | 零学习成本、权限引导清楚、不偷偷上传 |

### 2.2 核心任务

1. 按热键 → 框选 → 标注 → ⌘C → 粘贴到目标应用。
2. 按热键 → 悬停窗口高亮 → 点击 → 标注 → 保存。
3. 截取整屏 → 自动 OCR → 在历史库按文字搜索。
4. 截图后钉在桌面，边看边操作；可缩放、可关闭。
5. 录制一个窗口或显示器 → 停止 → 在历史库预览/定位文件。
6. 打开历史库 → 搜索/筛选 → 重新编辑 → 另存或复制。
7. 在 Lumi 对话中把当前截图作为图片附件发送（M2）。

### 2.3 体验预算

| 指标 | 目标 | 测量方式 |
| --- | --- | --- |
| 热键到遮罩可见 | 中位 ≤ 250ms，p95 ≤ 400ms | 打点日志 + Instruments |
| 框选确认到编辑器可交互 | ≤ 500ms（6MP 图像） | 打点日志 |
| 标注一次拖动到画面更新 | ≤ 16ms（主线程单帧） | 编辑器帧耗时探针 |
| ⌘C 到剪贴板可用 | ≤ 150ms（含渲染） | 单元/集成计时 |
| 历史库首屏 | ≤ 300ms（1 万条元数据） | 启动计时 |
| 历史搜索 | ≤ 100ms（1 万条，FTS5） | 查询计时 |
| 缩略图生成 | ≤ 200ms/张（后台，限并发 2） | 后台任务计时 |
| 空闲内存 | ≤ 150MB（不含 Lumi 主进程其他插件） | Instruments |
| 录制 CPU | 1080p30 时 ≤ 25%（Apple Silicon 基准机） | Activity Monitor / Instruments |
| 冷启动影响 | 插件 boot 额外 ≤ 80ms | 启动打点 |

预算不是发布门槛的全部，但超过 2 倍必须在本计划中记录原因与后续任务。

## 3. 源码事实基线

以下结论均来自当前仓库源码，行号为 2026-11-16 核对结果。

### 3.1 已有能力

| 能力 | 现状与位置 | 可复用部分 | 必须改造 |
| --- | --- | --- | --- |
| 全屏抓取 | `Packages/PluginChatScreenshot/Sources/PluginChatScreenshot/Capture/ScreenCaptureService.swift:26-55`：`captureAllScreens()` 先 union 所有 `NSScreen.frame`，macOS 15.2+ 走 `SCScreenshotManager.captureImage`，14–15.1 走 `CGWindowListCreateImage` | 采集路径、OS 版本分支、错误类型 | 需要注入 `DisplayProviding` 才能单测；需要支持按显示器抓取与混合缩放 |
| 选区遮罩 | `Packages/PluginChatScreenshot/Sources/PluginChatScreenshot/Overlay/ChatScreenshotOverlayWindow.swift:12-30`：无边框 `NSPanel`，`.screenSaver` 层级，跨 Space/全屏 | 窗口层级、collectionBehavior、透明背景 | 需要跨屏选区、窗口高亮、尺寸徽标、键盘操作 |
| 裁剪坐标 | `Packages/PluginChatScreenshot/Sources/PluginChatScreenshot/Models/ChatScreenshotState.swift:95-117`：`crop(image:captureFrame:selection:)`，含 Y 轴翻转与缩放 | 坐标换算思路、边界钳制 | 需要独立成 `CaptureGeometry`，覆盖负坐标、混合 DPI、旋转屏 |
| 截图流程 | `Packages/PluginChatScreenshot/Sources/PluginChatScreenshot/Support/ScreenshotFlowRunner.swift:17-48`：权限 → 抓取 → 遮罩 → 裁剪 → 编码 | 流程顺序、权限失败引导 | 需要状态机、单飞、取消、会话身份校验 |
| 会话身份校验 | `ScreenshotFlowRunner.swift:26-70`：await 后比对 `conversationID` | 异步写回身份校验范式（与 `AGENTS.md` 约定一致） | 新流程需把 `conversationID` 泛化为 `captureSessionID` |
| 屏幕权限 | `Packages/PluginChatScreenshot/Sources/PluginChatScreenshot/Capture/ScreenCapturePermissionPrompter.swift`；`Packages/PluginScreenRecorder/Sources/ScreenRecorderPlugin/Services/RecordingPermissionService.swift:11-53` | `CGPreflight/RequestScreenCaptureAccess`、系统设置深链、麦克风权限 | 合并成 `CapturePermissionService`，闭包注入便于测试 |
| OCR | `Packages/PluginOcr/Sources/PluginOcr/Services/OcrEngine.swift:10-56`：Vision `VNRecognizeTextRequest`，`.accurate`，默认 `["zh-Hans","en-US"]`，`Task.detached` | 识别参数、语言映射、离线策略 | 需要支持 `CGImage` 输入、结构化行与包围盒、条形码（M2） |
| OCR 工具 | `Packages/PluginOcr/Sources/PluginOcr/Tools/OcrImageTool.swift:12-13`；`PluginOcr.swift:14-15,38-43` | `ocr_image` 工具契约、路径校验 | 保持工具名与返回格式，底层换 `KitCapture` |
| 录制引擎 | `Packages/PluginScreenRecorder/Sources/ScreenRecorderPlugin/Services/ScreenCaptureRecorder.swift:11-30,73-74,158-187`：`SCStream` → `AVAssetWriter`，串行 writer queue，满载丢帧 | 采集/编码实现可整体上移 | 需要把 `RecordingEngine` 协议与实现移到 `KitCapture`，去掉插件内部可见性 |
| 录制会话 | `Packages/PluginScreenRecorder/Sources/ScreenRecorderPlugin/Services/RecordingSessionManager.swift:12-48,66-86,147-166`：权限、目标解析、计时、自动停、互斥、终态落盘 | 单例会话管理、`isStarting` 互斥、观察者 | 需要与 Capture 共用同一会话；插件禁用时要可靠停止 |
| 录制落盘 | `Packages/PluginScreenRecorder/Sources/ScreenRecorderPlugin/Services/RecordingFileWriter.swift:7-60`：临时目录、同卷移动/跨卷拷贝、24 小时残留清理 | 原子落盘与崩溃恢复 | 目标目录改为历史库 `recordings/`，仍支持用户另存 |
| 录制指示器 | `Packages/PluginScreenRecorder/Sources/ScreenRecorderPlugin/Views/RecordingIndicatorController.swift:60-75`：`.statusBar` 层级无焦点药丸 | 悬浮指示器窗口形态 | 需要支持倒计时、麦克风状态、停止中状态 |
| 录制配置 | `Packages/PluginScreenRecorder/Sources/ScreenRecorderPlugin/Models/RecordingModels.swift:18-68`：目标、帧率、分辨率、系统音频、麦克风、光标、时长上限 | 配置模型与范围钳制 | 需要扩展“区域录制”之前先不纳入首版 |
| ActivityBar 入口 | `Packages/PluginImageToPDF/Sources/PluginImageToPDF/ImageToPDFPlugin.swift:46-64`：激活时切 ContentView、隐藏 chat/rail、恢复 | 入口/失活恢复范式 | Capture 需要保留历史库入口，且与其他入口互不覆盖 |
| 菜单栏 | `LumiApp/LumiMenuBarController.swift:10-30`：真实 `NSStatusItem` + `MenuBarHostKit`，不用 `MenuBarExtra`（自定义视图会被压成单行） | 菜单栏宿主与 popup 机制 | Capture 通过 `MenuBarProviding.addPopup` 贡献子菜单 |
| 全局热键 | `Packages/PluginQuickLauncher/Sources/PluginQuickLauncher/Services/GlobalHotkeyManager.swift:8-101,145-190`：Carbon `RegisterEventHotKey`，组合持久化，热切换 | Carbon 注册/注销、组合显示、事件签名 | 目前只有 QuickLauncher 私有实现；Capture 不能 import 它，需要共享热键包 |
| 插件数据目录 | `Packages/PluginClipboardManager/Sources/PluginClipboardManager/ClipboardManagerPlugin.swift:51-52`：`StorageProviding.pluginDataDirectory(for:)` | 插件私有数据根 | Capture 只在该目录内建库，测试注入临时目录 |
| 插件装配 | `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift:264,291,328,331,349` | 在 OCR / ChatScreenshot / ScreenRecorder 附近插入 Capture | 需要一个独立的 `CapturePlugin()` 条目与顺序 |
| 独立装配先例 | `Lode/Packages/FactoryDatabaseManager/Sources/FactoryDatabaseManager/FactoryDatabaseManager.swift:13-42`：`DedicatedPluginFactory` 只装配编辑器宿主与数据库插件，并用 `DedicatedAlwaysOnPlugin` 强制 `.alwaysOn` | 抽取 App 的装配范式 | Capture 需要自己的 `FactoryCapture` 与 App shell |
| 商店契约 | LumiProviders 1.25.0（`Packages/FactoryLumi/Package.resolved:339-343`）已提供 `ProviderStore`：`StoreTier`、`StoreEntitlementProviding`、`StoreProductCatalog` | 档位/权益快照契约，可在独立 App 复用 | Lumi 内不实现付费；独立 App 需实现 StoreKit 2 权益服务 |
| 测试基础设施 | `Scripts/run-all-package-tests.sh`、`Scripts/check-test-targets.py`、`Scripts/generate-testplan.py`、`Packages/KitTestSupport` 的临时目录/隔离工具 | 测试运行、TestPlan 生成、临时目录 | 新包必须补 `Tests/TestPlan.md` 才能通过体检 |

### 3.2 缺口

1. **没有标注文档模型**：现有截图只产出 JPEG/图片附件，没有“原图 + 矢量标注”的可编辑文档。
2. **没有编辑器**：没有箭头、矩形、文字、马赛克、步骤编号、撤销/重做、图层命中测试。
3. **没有历史库**：没有 SQLite 元数据、缩略图、OCR 索引、回收站、保留策略。
4. **没有窗口截取 UI**：有 `RecordableWindowProvider` 的窗口枚举，但没有悬停高亮与点击选窗。
5. **没有滚动截图**：没有滚动事件监听、重叠检测、拼接。
6. **没有钉图窗口**：没有置顶图片面板、缩放、透明度、复制/关闭。
7. **没有共享热键包**：Carbon 实现被锁在 QuickLauncher 插件内，跨插件不可复用。
8. **OCR 只有“文件路径 → 文本”**：不能直接吃 `CGImage`，不返回行坐标，不能做“点某行复制”。
9. **没有独立 App 外壳**：没有菜单栏常驻、登录项、单实例、付费墙、沙盒、隐私清单、App Store 元数据。
10. **截图相关测试只覆盖裁剪**：缺少几何、渲染、导出、库、热键、状态机、UI 流程测试。

### 3.3 硬约束

| 约束 | 依据 | 影响 |
| --- | --- | --- |
| 最低 macOS 14.0 | `LumiApp/Config/App-Shared.xcconfig:10`；插件包均声明 `macOS("14.0")` | 不能用只在 15+ 存在的 API；截图 API 需 15.2 分支 + 14/15.1 兜底 |
| 麦克风录制需 macOS 15+ | `RecordingSessionManager.swift:66-86` 的能力校验；`RecordingModels.swift` 的麦克风开关 | macOS 14 上麦克风开关禁用并给出说明，不能静默录出无声视频 |
| 屏幕录制需 TCC 授权 | `ScreenCapturePermissionPrompter`、`RecordingPermissionService` | 首次使用必须由用户显式触发授权；拒绝后要能恢复，不崩溃 |
| Swift 6 严格并发 | 仓库包 `swift-tools-version: 6.0` | `CGImage`/`SCContentFilter` 等非 Sendable 类型要明确隔离；UI 只在 `@MainActor` |
| 插件不能互相 import | `docs/plans/2026-09-17-plugin-first-architecture-sharing.md:19` 与仓库约定 | Capture 不能依赖 `PluginQuickLauncher`、`PluginChatScreenshot`、`PluginOcr`、`PluginScreenRecorder` |
| 插件数据只能写自己的目录 | `StorageProviding.pluginDataDirectory(for:)` | 历史库根目录由宿主注入；独立 App 由自身决定 |
| Lumi 为 GPLv3 | 仓库 `LICENSE` 与 `README.md:9` | 独立 App 上架前必须处理 GPL 与 App Store 的授权边界 |
| 工具失败必须抛出 | `AGENTS.md` 工具失败约定 | `capture_screen` 等 agent 工具不能返回 "Error: ..." 字符串 |
| 异步写回必须校验身份 | `AGENTS.md` 异步写回约定；`ScreenshotFlowRunner.swift:26-70` | OCR 完成、缩略图完成、搜索完成写回前都要比对 asset/session/generation |
| 不硬编码本机路径 | 共享仓库约定 | 文档与代码只用仓库相对路径或 `StorageProviding` 返回路径 |
| Lumi 未启用 App Sandbox | `LumiApp/App.entitlements:5-12` 只有 app group、network client、screen-capture | 插件阶段不需要沙盒适配；独立 App 必须重新验证沙盒下的文件与权限 |

## 4. 产品规格

### 4.1 捕获模式

| 模式 | 触发 | 行为 | 首版 |
| --- | --- | --- | --- |
| 区域 | 默认热键 `⌥⇧A` | 遮罩全屏，拖拽选区；可跨显示器；回车确认、Esc 取消；支持方向键微调 | M1 |
| 窗口 | 默认热键 `⌥⇧W` | 悬停高亮窗口，点击捕获；不激活目标 App；可选包含阴影 | M1 |
| 整屏 | 默认热键 `⌥⇧F` | 捕获鼠标所在显示器；设置项可改为“所有显示器分别入库” | M1 |
| 上次区域 | 编辑器/菜单命令 | 复用上一次区域，直接捕获并进编辑器 | M2 |
| 滚动区域 | 选区后点“滚动截图” | 用户手动滚动，按帧捕获并拼接；Esc/回车结束 | M2（实验） |
| 定时 | 菜单命令 | 3/5/10 秒后执行指定模式 | M2 |
| OCR 区域 | 默认热键 `⌥⇧O` | 框选后直接 OCR，打开文字面板，不先进标注编辑器 | M1 |
| 录制显示器/窗口 | 默认热键 `⌥⇧R` | 目标选择 HUD → 倒计时 → 录制 → 指示器停止 | M2 |

窗口捕获不激活目标 App：现有 `PluginComputerUse` 已证明 `SCScreenshotManager` 可以在不激活目标窗口的情况下抓取窗口（`Packages/PluginComputerUse/Sources/ComputerUsePlugin/Services/ComputerUseService.swift:204-230`），Capture 沿用同一路径。

### 4.2 选区遮罩

- 遮罩覆盖所有显示器，每个显示器一个无边框 `NSPanel`；层级 `.screenSaver`，`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`（与 `ChatScreenshotOverlayWindow.swift:12-30` 一致）。
- 未选区时整屏压暗 35%–45%，选区恢复原亮度；选区边框 1px 高对比描边；四角显示尺寸徽标（像素宽 × 高）。
- 选区内部显示半透明尺寸胶囊；拖动时实时更新；松开后进入编辑器。
- 选区最小 1×1 像素；小于 8×8 时按 8×8 处理并提示，避免误触产生空图。
- 跨屏选区：允许从一个显示器拖到另一个；编辑器画布按“最大缩放比”合成，1x 屏内容在 2x 画布上按高质量插值放大，保留 2x 屏原像素。
- 键盘：Esc 取消；回车确认当前选区；方向键移动 1px，Shift+方向键调整 10px；空格切换“窗口模式”与“区域模式”（M2）。
- 窗口模式：悬停时高亮窗口轮廓，显示“App 名 — 窗口标题”；点击捕获；按住 Option 点击捕获子窗口（M2）。
- 遮罩窗口不进入截图：区域/整屏捕获在遮罩出现前完成抓取；窗口捕获使用窗口 ID，不包含遮罩。

### 4.3 标注编辑器

编辑器是一个轻量浮动面板（`NSPanel`，`.floating`，`.fullScreenAuxiliary`），不抢占 Lumi 主窗口；独立 App 同样使用该面板。

#### 4.3.1 工具

| 工具 | 首版 | 说明 |
| --- | --- | --- |
| 选择/移动 | M1 | 选中标注后可拖动、删除、调整层级 |
| 矩形 | M1 | 描边/填充可选；圆角可调（M2） |
| 椭圆 | M1 | 同上 |
| 直线 | M1 | 端点吸附（Shift 约束角度，M2） |
| 箭头 | M1 | 箭头大小随线宽；端点可拖动 |
| 自由画笔 | M1 | 平滑折线；可调线宽/颜色 |
| 荧光笔 | M1 | 半透明、正片叠底风格；不遮挡文字 |
| 文字 | M1 | 支持中文输入法；双击编辑；字体/字号/颜色/对齐 |
| 步骤编号 | M2 | 点击放置递增序号，可拖动、重排 |
| 马赛克 | M2 | 区域块状像素化，块大小可调 |
| 模糊 | M2 | 高斯模糊区域，强度可调 |
| 裁剪 | M2 | 非破坏性裁剪，可恢复 |
| 取色器 | M2 | 显示十六进制值，可复制 |

#### 4.3.2 画布与交互

- 画布按“适合窗口”初始缩放，最大 400%，最小 10%；⌘+ / ⌘- / ⌘0。
- 拖拽工具时实时预览；松开后提交为一个可撤销命令。
- 选中标注显示八向手柄；Shift 等比缩放；Delete 删除；⌘D 复制（M2）。
- 撤销/重做：⌘Z / ⇧⌘Z；至少 100 步；关闭编辑器后历史不持久化。
- 文字编辑使用 AppKit `NSTextView` 包装，确保中文输入法组合文本、候选窗、Esc 取消行为正确；SwiftUI `TextField` 在画布缩放环境下容易出现光标错位。
- 画布背景为 checkerboard，透明区域可见；导出 PNG 保留透明，JPEG 以白色填充。
- 关闭编辑器不询问“是否保存”：捕获时已写入历史库文档；关闭即安全。

#### 4.3.3 导出与复制

| 动作 | 快捷键 | 行为 |
| --- | --- | --- |
| 复制标注图 | ⌘C | 渲染当前文档 → 写剪贴板（PNG + TIFF），保留透明 |
| 复制原图 | ⌥⌘C | 复制未标注原图 |
| 保存 | ⌘S | 有默认目录则直接保存并提示；否则打开保存面板 |
| 另存为 | ⇧⌘S | 始终打开保存面板 |
| 钉在桌面 | ⌘P | 打开置顶图片窗口，显示当前标注结果 |
| 打开历史库 | ⌘L | 切到历史库并定位当前资产 |
| 关闭 | Esc | 关闭编辑器，资产保留在历史库 |

- 默认格式 PNG；设置可改 JPEG（质量 0.6–1.0）、HEIC（M2）。
- 文件名模板：`Capture-yyyyMMdd-HHmmss`，冲突时追加 `-2`、`-3`；支持用户自定义模板（M2）。
- 剪贴板同时写入 `public.png` 与 `public.tiff`，兼容只认 TIFF 的老应用；不写文件 URL，避免部分 App 粘贴成路径。
- 导出在后台渲染，完成后回主线程写剪贴板；导出失败保留编辑器并提示。

### 4.4 历史库

#### 4.4.1 视图

- 网格视图：缩略图、类型角标（截图/录制）、收藏星标、创建时间；默认按创建时间倒序。
- 列表视图：缩略图、文件名、来源 App、窗口标题、尺寸、大小、OCR 摘要。
- 详情面板：大图预览、元数据、OCR 文本、操作（复制、编辑、钉住、在 Finder 显示、删除）。
- 搜索：OCR 全文 + 文件名 + 来源 App + 窗口标题；支持按类型、日期、收藏过滤。
- 分页：每页 100 条；滚动加载；搜索防抖 200ms，旧查询用 generation 丢弃。

#### 4.4.2 操作

| 操作 | 行为 |
| --- | --- |
| 双击 | 打开编辑器（截图）或播放器（录制） |
| 右键 | 复制、编辑、钉住、收藏、在 Finder 显示、移到废纸篓 |
| 拖出 | 拖到 Finder/IM 得到当前标注图或原图（设置决定） |
| 删除 | 软删除到回收站；7 天内可恢复；之后清理 |
| 清空回收站 | 二次确认；删除文件与 OCR 索引 |
| 重新 OCR | 对旧资产重跑识别，更新索引（M2） |
| 批量导出 | 选中多条导出到目录（M2） |

#### 4.4.3 保留策略

- 默认保留 90 天；收藏（星标）与钉住的资产不自动清理。
- 用户可选 30/90/180/365 天/永久；默认上限 10GB，超过时提示并可一键清理最旧未收藏项。
- 自动清理只进入回收站，7 天后彻底删除；不直接删原图。
- 应用崩溃后启动时清理 `tmp/` 中超过 24 小时的临时文件；历史库执行一次完整性检查。

### 4.5 OCR

- 捕获完成即后台 OCR；结果写入数据库与文档侧车；编辑器“文字”按钮显示结果。
- 文字面板按行展示，点击某行复制该行；支持“复制全部”“搜索选中文字”（M2）。
- 默认语言：`zh-Hans` + `en-US`；设置可选 `zh-Hant`、`ja`、`ko`、`fr`、`de` 等 Vision 支持的语言。
- 识别失败/无文字：显示“未识别到文字”，不弹错误框；历史条目标记 `ocr_status = empty`。
- OCR 默认不联网；翻译功能（M2）只发送识别出的文字，发送前展示将要发送的内容与目标服务，必须由用户点击确认。
- 条形码/二维码识别（M2）：在文字面板额外显示码内容，可复制。

### 4.6 钉图

- 钉图窗口为无边框 `NSPanel`，`.floating` 层级，`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`，不抢焦点。
- 显示当前标注结果；支持拖动、滚轮缩放（10%–400%）、透明度 30%–100%、复制、关闭。
- 多钉图：每个资产最多一个钉图窗口；再次钉住同一资产时置前，不重复创建。
- 钉图窗口不进入区域/整屏截图：捕获时排除本 App 窗口（`SCContentFilter` 排除自身进程窗口）。
- 钉图是临时视图，不跨启动恢复；历史库中的“收藏”是另一概念，不要混用文案。

### 4.7 录制

首版只做显示器与单窗口录制，不做区域录制。

- 目标选择 HUD：显示器列表（含缩略图/分辨率）与当前可见窗口列表；支持搜索窗口。
- 选项：帧率 15/30/60；分辨率高度（原始/1080/720）；系统音频；麦克风；显示光标；最长时长（默认 30 分钟，上限 60 分钟）。
- macOS 14 上麦克风选项禁用，并提示“麦克风录制需要 macOS 15 或更高版本”；不能静默产出无声视频。
- 3 秒倒计时后开始；指示器显示目标、计时、麦克风状态、停止按钮；支持菜单栏/热键停止。
- 停止后写入历史库 `recordings/`，生成首帧缩略图；详情页可播放、在 Finder 显示、复制文件、删除。
- 录制失败（权限收回、显示器变化、磁盘满）必须停止并保留可恢复的临时文件；错误信息可读。
- 与现有 `PluginScreenRecorder` 共用同一个 `KitCapture` 录制会话单例，避免同时开两个录制。

### 4.8 快捷入口

| 入口 | 插件阶段 | 独立 App |
| --- | --- | --- |
| 全局热键 | Carbon，默认组合见附录 C | 同左 |
| Lumi 菜单栏 | `MenuBarProviding.addPopup` 贡献“Capture”子菜单 | 自有 `NSStatusItem` 菜单 |
| Lumi 命令面板 | `CommandProviding` 注册捕获/历史/设置命令 | App 菜单命令 |
| ActivityBar | “Capture”入口打开历史库 | 主窗口即历史库 |
| 聊天输入区 | M2：把截图作为图片附件加入当前会话 | 不适用 |
| Agent 工具 | `capture_screen`、`capture_window`、`list_capture_history`；`ocr_image` 保持原工具名 | 不适用 |

### 4.9 设置

| 分组 | 设置项 | 默认 |
| --- | --- | --- |
| 通用 | 保存目录 | 未设置时 ⌘S 弹保存面板 |
| 通用 | 默认格式/质量 | PNG / 无损 |
| 通用 | 捕获后行为 | 打开编辑器 |
| 通用 | 是否保存到历史库 | 开 |
| 通用 | 窗口截图是否包含阴影 | 开 |
| 通用 | 整屏截图范围 | 鼠标所在显示器 |
| 热键 | 六个全局热键 | 附录 C |
| 历史 | 保留天数 / 容量上限 / 收藏豁免 | 90 天 / 10GB / 开 |
| OCR | 语言、捕获后自动 OCR、复制行为 | 简中+英 / 开 / 复制全文 |
| 录制 | 默认帧率/分辨率/音频/光标/时长 | 30fps / 原始 / 无音频 / 显示 / 30 分钟 |
| 权限 | 屏幕录制、麦克风状态与跳转 | 只读展示 |
| 隐私 | 翻译开关、发送前确认 | 关 / 开 |

### 4.10 首次使用与权限

1. 插件启用后**不主动弹 TCC**；设置页与首次捕获动作展示“需要屏幕录制权限”。
2. 用户点击“授权屏幕录制”才调用 `CGRequestScreenCaptureAccess()`；若系统要求重启 App，明确告知并给出“退出并重新打开”按钮。
3. 已拒绝时展示系统设置深链（`x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`），不反复弹窗。
4. 麦克风只在用户开启麦克风录制时请求；拒绝后录制仍可继续但无麦克风轨，并明确提示。
5. 首次捕获完成展示 3 步提示：拖拽选区、标注工具、⌘C 复制；可关闭且不再显示。

### 4.11 本地化与无障碍

- 首发语言：English、简体中文；M3 补齐繁体中文（zh-Hant/zh-HK/zh-TW）。
- 所有用户可见字符串走包内 `Localizable.xcstrings`，通过 `pluginLocalization` 或 `String(localized:bundle:.module)` 读取；不硬编码中文/英文。
- 编辑器工具栏、历史库、设置页提供 accessibility label/identifier；支持键盘 Tab 导航。
- 遮罩以鼠标为主，但提供键盘移动/缩放选区；VoiceOver 用户可通过菜单命令执行捕获，并在编辑器中用工具按钮完成标注。
- 深色/浅色模式下使用语义色与材质；导出图像不受主题影响。

### 4.12 性能预算

- 捕获、裁剪、渲染、编码、OCR、缩略图全部离开主线程；主线程只做 UI 状态与轻量坐标转换。
- 编辑器缓存原图 `CGImage` 与已渲染标注层；拖动时只重绘脏矩形。
- 历史库分页 + 缩略图懒加载；不把全尺寸图读进网格。
- OCR 与缩略图任务串行/限并发，避免同时解码多张 8K 图。
- 录制沿用现有“writer 不 ready 就丢帧”的策略，绝不阻塞采集回调（`ScreenCaptureRecorder.swift:30-45`）。
- 达到预算的测量脚本与手动步骤见 7.5。

## 5. 架构

### 5.1 包与目录

```
Packages/
  KitCapture/
    Sources/KitCapture/
      Capture/
        DisplayDescriptor.swift
        DisplayCaptureService.swift
        WindowCatalog.swift
        CaptureCoordinator.swift
        CaptureRequest.swift
      Geometry/
        CaptureGeometry.swift
        SelectionMapper.swift
      Document/
        CaptureDocument.swift
        CaptureAnnotation.swift
        AnnotationRenderer.swift
        CropTransform.swift
        DocumentStore.swift
      Export/
        CaptureExporter.swift
        PasteboardWriter.swift
        FileNamer.swift
      OCR/
        CaptureOCRService.swift
        OCRResult.swift
      Recording/
        CaptureRecordingEngine.swift
        ScreenCaptureRecordingEngine.swift
        CaptureRecordingSession.swift
        RecordingFileStore.swift
      Library/
        CaptureAsset.swift
        CaptureLibraryStore.swift
        CaptureDatabase.swift
        ThumbnailStore.swift
        RetentionPolicy.swift
        TrashStore.swift
      Hotkey/
        HotkeyCombo.swift
        CaptureHotkeyCenter.swift
      Permission/
        CapturePermissionService.swift
      Support/
        ImageBuffer.swift
        SendableCaptureFrame.swift
    Tests/KitCaptureTests/
      TestPlan.md
  KitCaptureUI/
    Sources/KitCaptureUI/
      Overlay/
        CaptureOverlayView.swift
        CaptureOverlayWindow.swift
        WindowHighlightOverlay.swift
      Editor/
        CaptureEditorView.swift
        CaptureCanvasView.swift
        CaptureToolbarView.swift
        CaptureInspectorView.swift
        AnnotationTextView.swift
      Library/
        CaptureLibraryView.swift
        CaptureGridItemView.swift
        CaptureDetailView.swift
        CaptureSearchField.swift
      Pin/
        PinnedImagePanel.swift
        PinnedImageController.swift
      Settings/
        CaptureSettingsView.swift
        HotkeyRecorderView.swift
      Support/
        CaptureDesignTokens.swift
    Tests/KitCaptureUITests/
      TestPlan.md
  PluginCapture/
    Sources/PluginCapture/
      CapturePlugin.swift
      Adapters/
        CaptureHostAdapter.swift
        CaptureActivityBarAdapter.swift
        CaptureMenuBarAdapter.swift
        CaptureCommandAdapter.swift
        CaptureChatAdapter.swift
        CaptureLLMAdapter.swift
      Views/
        CaptureWorkspaceView.swift
        CaptureAboutView.swift
        CaptureManualView.swift
      Tools/
        CaptureScreenTool.swift
        CaptureWindowTool.swift
        CaptureHistoryTool.swift
      PluginLocalization.swift
    Resources/Localizable.xcstrings
    Tests/PluginCaptureTests/
      TestPlan.md
  FactoryCapture/            # M4，独立仓库或 Lumi 内先行
    Sources/FactoryCapture/
      FactoryCapture.swift
      KernelFactory.swift
      ProviderFactory.swift
      ViewFactory.swift
      AppCommands.swift
```

`KitCaptureUI` 不依赖 `LumiUI`，只依赖 SwiftUI/AppKit 与 `KitCapture`；Lumi 内如果需要品牌色/字体，由 `PluginCapture` 在宿主环境注入，不下沉到 UI 包。

### 5.2 依赖规则

```
PluginCapture ──> KitCaptureUI ──> KitCapture
      │
      ├──> KernelCore / Provider* / LumiUI / LumiSettings / LumiLogging / LumiLocalization
      └──> （M2）ProviderMessageSender / ProviderLLMManager

FactoryCapture ──> PluginCapture + KernelCore + 最小 Provider 集合
CaptureApp ──> FactoryCapture
```

规则：

1. `KitCapture` 不 import `KernelCore`、任何 `Provider*`、`LumiUI`、`LumiSettings`。
2. `KitCaptureUI` 不 import `KernelCore`、`Provider*`；需要宿主能力时通过初始化参数注入。
3. `PluginCapture` 是唯一允许接触 `KernelCore` 的包；不得 import 其他 `Plugin*`。
4. `FactoryCapture` 只做装配，不写业务逻辑。
5. 包平台声明与仓库一致：`[.macOS("14.0"), .iOS(.v17)]`；所有 Capture 专属实现放在 `#if os(macOS)` 内，保证 `Scripts/check_platform_consistency.py` 通过。
6. 新包必须有 `Tests/` 与 `TestPlan.md`，否则 `Scripts/check-test-targets.py` 会报缺失。

### 5.3 关键类型

```swift
#if os(macOS)
import CoreGraphics
import Foundation

public enum CaptureMode: Sendable, Equatable {
    case region
    case window
    case display(displayID: CGDirectDisplayID)
    case allDisplays
    case previousArea(CGRect)
}

public struct CaptureRequest: Sendable, Equatable {
    public var mode: CaptureMode
    public var includeCursor: Bool
    public var excludeOwnWindows: Bool
    public var includeWindowShadow: Bool
}

public struct CaptureFrame: @unchecked Sendable {
    // CGImage 不可变；此处以 @unchecked 标注，所有使用方只读。
    public let image: CGImage
    public let pixelSize: CGSize
    public let scale: CGFloat
    public let displayID: CGDirectDisplayID?
    public let capturedAt: Date
}

public protocol DisplayCapturing: Sendable {
    func capture(_ request: CaptureRequest) async throws -> [CaptureFrame]
}

public protocol WindowCatalogProviding: Sendable {
    func windows() async throws -> [WindowDescriptor]
    func capture(window: WindowDescriptor, includeShadow: Bool) async throws -> CaptureFrame
}

public struct CaptureDocument: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var canvas: CanvasSize          // 像素坐标，原点左上
    public var original: OriginalImageRef
    public var crop: PixelRect?
    public var annotations: [CaptureAnnotation]
    public var createdAt: Date
    public var updatedAt: Date
}

public enum CaptureAnnotation: Codable, Sendable, Equatable {
    case rectangle(id: UUID, frame: PixelRect, style: StrokeStyle)
    case ellipse(id: UUID, frame: PixelRect, style: StrokeStyle)
    case line(id: UUID, from: PixelPoint, to: PixelPoint, style: StrokeStyle)
    case arrow(id: UUID, from: PixelPoint, to: PixelPoint, style: StrokeStyle)
    case freehand(id: UUID, points: [PixelPoint], style: StrokeStyle)
    case highlighter(id: UUID, points: [PixelPoint], style: StrokeStyle)
    case text(id: UUID, frame: PixelRect, string: String, style: TextStyle)
    case step(id: UUID, center: PixelPoint, number: Int, style: StrokeStyle)
    case blur(id: UUID, frame: PixelRect, radius: Double)
    case pixelate(id: UUID, frame: PixelRect, blockSize: Int)
}

public protocol CaptureLibraryStoring: Sendable {
    func insert(_ asset: CaptureAsset, document: CaptureDocument?) async throws
    func update(_ asset: CaptureAsset) async throws
    func asset(id: UUID) async throws -> CaptureAsset?
    func search(_ query: CaptureSearchQuery) async throws -> CapturePage
    func softDelete(id: UUID) async throws
    func restore(id: UUID) async throws
    func purge(ids: Set<UUID>) async throws
}

public protocol CaptureFeatureGate: Sendable {
    func isEnabled(_ feature: CaptureFeature) -> Bool
}

public enum CaptureFeature: String, Sendable, CaseIterable {
    case scrollCapture
    case recording
    case multiplePins
    case translation
    case unlimitedHistory
    case customExportPresets
}
#endif
```

设计说明：

- `CaptureFrame` 的 `@unchecked Sendable` 只包住不可变 `CGImage`；任何需要修改像素的操作都创建新图，不原地改共享图。
- `CaptureDocument` 用 `Codable` 存为 `.capture.json` 侧车文件；数据库只存索引与路径，避免大 JSON 拖慢列表查询。
- `CaptureFeatureGate` 在插件阶段注入 `AllowAllFeatureGate`，独立 App 注入 StoreKit 实现；核心逻辑不感知商店。
- `DisplayCapturing` / `WindowCatalogProviding` / `CaptureLibraryStoring` 都是协议，测试注入假实现，避免测试触碰真实屏幕与 TCC。

### 5.4 状态机

#### 5.4.1 截图

```
idle
  → preparing（权限/显示器/热键校验）
  → capturing（抓取像素）
  → selecting（遮罩等待用户）
  → editing（编辑器）
  → exporting（复制/保存/钉住）
  → idle

任意阶段 → failed（错误展示）→ idle
selecting → idle（Esc）
editing → idle（关闭，资产保留）
```

不变量：

- 同一时刻只有一个 `CaptureSession`；`CaptureCoordinator` 用 `isStarting` + `activeSessionID` 双保险。
- 每个 `await` 之后检查 `Task.isCancelled` 与 `sessionID` 是否仍是当前会话；不是则丢弃结果。
- 遮罩关闭、编辑器关闭、导出完成都必须释放窗口与临时图。
- 抓取失败不得留下遮罩；权限失败直接进入引导，不进入 selecting。
- 窗口模式捕获的目标在抓取前确定；窗口消失时返回可读错误，不抓空图。

#### 5.4.2 录制

```
idle
  → preparing（权限/目标/容量校验）
  → recording（SCStream 采集）
  → stopping（用户停止）
  → finalizing（writer 收尾/落盘/缩略图）
  → idle

任意阶段 → failed（保留临时文件）→ idle
```

不变量：

- `isStarting` 在第一个 `await` 前占用，避免并发 start 覆盖（沿用 `RecordingSessionManager.swift:80-86` 的修复思路）。
- 插件禁用/退出时，`onDisable` 必须等待停止与落盘；`onShutdown` 同步接口只能触发异步收尾并保留单例存活到完成。
- 录制失败时临时 `.mp4` 保留 24 小时，供恢复；启动时清理过期临时文件。

### 5.5 Lumi 集成

| 生命周期 | 动作 | 清理 |
| --- | --- | --- |
| `onRegister` | 注册 About/Manual 文档条目 | `onUnregister` 无需额外清理（文档由宿主管理） |
| `onBoot` | 注入数据目录；创建库/设置/热键管理器；注册 ActivityBar、设置项、命令、菜单栏；注册 agent 工具；注册观察者 | `onShutdown` 逐项撤销 |
| `onReady` | 启动全局热键；恢复上次未完成的临时任务清理 | 在 `onReady` 启动可避免拖慢启动装配 |
| `onEnable` | 热键、观察者、菜单栏、ActivityBar 重新挂载；幂等 | `onDisable` 全部撤销；若在录制则先停止并落盘 |
| `onShutdown` | 关闭遮罩/编辑器/钉图；停止录制（异步收尾）；注销热键；移除菜单项/ActivityBar/命令/工具 | 不留下全局 Carbon 热键 |

具体贡献：

- **ActivityBar**：`ActivityBarItem(id: "com.coffic.lumi.plugin.capture.entry", ownerPluginID: id)`。激活时 `content.setContentView(CaptureWorkspaceView)`，隐藏 chat/rail/header；失活时恢复，模式与 `ImageToPDFPlugin.swift:46-64` 一致。
- **设置**：`SettingViewProviding.addEntries`，至少一个入口；内部用 Tab 分为通用/热键/历史/OCR/录制/权限/隐私。
- **命令**：`CommandProviding.registerCommandGroup`，包含“区域截图、窗口截图、整屏截图、OCR 区域、开始/停止录制、打开历史库”。命令快捷键是 App 内快捷键，不替代全局热键。
- **菜单栏**：`MenuBarProviding.addPopup(MenuBarContribution)`，贡献一组 Capture 操作与最近 5 条历史；不新增独立 `NSStatusItem`（插件阶段）。
- **Agent 工具**：
  - `capture_screen`：参数 `mode`（region/window/display）、`display_id`（可选）、`include_cursor`；返回资产 ID、路径、尺寸。
  - `capture_window`：参数 `app`、`window_title`（可选）；返回资产 ID/路径。
  - `list_capture_history`：参数 `query`、`limit`；返回元数据，不返回图片内容。
  - `ocr_image` 保持 `PluginOcr` 的工具名与行为，底层使用 `KitCapture` 的 OCR；不要在 Capture 插件里再注册同名工具。
- **聊天附件（M2）**：通过 `MessageSendingProviding.addImageAttachment` 把当前标注图加入待发送池；写回前比对 `conversationID`，沿用 `ScreenshotFlowRunner.swift:26-70` 的身份校验。
- **翻译（M2）**：通过 `ProviderLLMManager` 的 `LLMManaging` 发送 OCR 文本；发送前展示文本与目标模型，用户确认后才发送。

### 5.6 坐标系

统一定义三种坐标：

| 坐标 | 原点 | 单位 | 用途 |
| --- | --- | --- | --- |
| 全局屏幕坐标 | 主屏左下 | point | `NSScreen.frame`、鼠标位置、窗口 frame |
| 画布像素坐标 | 画布左上 | pixel | 文档、标注、导出 |
| 显示器本地像素 | 显示器左上 | pixel | `SCScreenshotManager` 返回图、窗口图 |

`DisplayDescriptor`：

```swift
public struct DisplayDescriptor: Sendable, Equatable {
    public let id: CGDirectDisplayID
    public let pointFrame: CGRect        // 全局屏幕坐标
    public let pixelSize: CGSize
    public let scale: CGFloat
    public let rotation: Int             // 0/90/180/270
    public let isMain: Bool
}
```

规则：

- 选区用全局屏幕坐标表达；`SelectionMapper` 把选区拆成若干 `DisplaySlice`，每个 slice 记录源显示器、源像素矩形、目标画布像素矩形。
- 画布缩放取所有相交显示器中最大的 `scale`；1x 显示器内容按高质量插值放大到 2x 画布，2x 内容保持原像素。
- Y 轴翻转只在“全局屏幕 ↔ 画布”边界发生一次；文档内部统一左上原点，避免每层各翻一次。
- 旋转 0°/180° 在 M1 完成并测试；90°/270° 在 M2 完成，未完成前该显示器上的区域截图回退为整屏捕获并提示，绝不输出错误裁剪。
- 负坐标显示器（主屏左侧/上方）必须有测试；不能假设所有 `origin` 都是 0。

### 5.7 标注与渲染

- 标注以矢量保存在 `CaptureDocument`；渲染器是纯函数：`render(document:options:) -> CGImage`。
- 渲染顺序即数组顺序；选择/移动只改数组元素，不改索引之外的顺序；置顶/置底通过数组移动实现。
- 文字使用 CoreText 绘制，字体/字号以画布像素为单位；导出与屏幕预览使用同一渲染器，避免预览与最终图不一致。
- 马赛克/模糊在渲染时应用到原图区域，不修改原图文件；渲染顺序按图层顺序，允许在已打码区域上继续打码。
- 裁剪作为文档级 `crop`，不修改原始图像；导出时先裁后绘。
- 渲染缓存：编辑器持有“原图 + 已提交标注层”的合成缓存；拖动中的临时标注单独绘制；提交后失效缓存并按脏矩形重绘。
- 导出在后台 `Task.detached` 执行，输入是不可变的 `CaptureDocument` + 原图 `CGImage`；完成后回主线程写剪贴板/文件。

### 5.8 热键

- 新增共享包 `Packages/KitGlobalHotkey`（或先放 `KitCapture/Hotkey`，M0 决定；推荐独立包，因为 QuickLauncher 是第二个使用方）。
- 基于 Carbon `RegisterEventHotKey`，与 `GlobalHotkeyManager.swift:145-190` 相同的注册/注销模型；Capture 使用独立事件签名（例如 `'Cap0'`），不与 `'Lum0'` 冲突。
- 支持多热键注册：`register(_ combo: HotkeyCombo, id: HotkeyAction) -> HotkeyRegistration`；`unregisterAll()`。
- 冲突检测：`RegisterEventHotKey` 失败时返回具体错误；UI 标注“该组合已被系统或其他应用占用”，允许用户改键或禁用。
- 组合必须包含 ⌘/⌥/⌃ 至少一个；单独 Shift/字母不允许注册。
- 持久化到插件专属 `UserDefaults`（独立 App 用自己的 defaults）；修改后热切换，不需要重启。
- QuickLauncher 的迁移不在 M1 门槛内；M3 做一次行为不变迁移，避免 M1 同时改两个稳定插件。

默认组合见附录 C。所有默认组合都不占用系统截图快捷键。

### 5.9 数据模型

#### 5.9.1 `CaptureAsset`（数据库行）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | TEXT PK | UUID 字符串 |
| `kind` | TEXT | `screenshot` / `recording` |
| `created_at` | REAL | Unix 时间 |
| `updated_at` | REAL | Unix 时间 |
| `source_app_bundle_id` | TEXT? | 来源 App |
| `source_app_name` | TEXT? | 来源 App 名 |
| `window_title` | TEXT? | 窗口标题 |
| `pixel_width` / `pixel_height` | INTEGER | 原图像素尺寸 |
| `original_path` | TEXT | 相对库根路径 |
| `document_path` | TEXT? | `.capture.json` 相对路径 |
| `thumbnail_path` | TEXT? | 缩略图相对路径 |
| `duration_ms` | INTEGER? | 录制时长 |
| `file_size` | INTEGER | 字节 |
| `ocr_text` | TEXT? | 识别文本 |
| `ocr_languages` | TEXT? | 逗号分隔 |
| `ocr_status` | TEXT | `pending` / `done` / `empty` / `failed` |
| `is_favorite` | INTEGER | 收藏，不自动清理 |
| `deleted_at` | REAL? | 软删除时间 |

#### 5.9.2 `CaptureDocument`（侧车 JSON）

```json
{
  "schemaVersion": 1,
  "canvas": { "width": 2880, "height": 1800, "scale": 2.0 },
  "original": {
    "relativePath": "originals/20261116-101500-ab12cd.png",
    "pixelWidth": 2880,
    "pixelHeight": 1800
  },
  "crop": null,
  "annotations": [
    {
      "type": "rectangle",
      "id": "3F2A...",
      "frame": { "x": 120, "y": 80, "width": 420, "height": 180 },
      "style": {
        "strokeColor": "#FF3B30",
        "fillColor": null,
        "lineWidth": 6,
        "opacity": 1.0
      }
    }
  ],
  "createdAt": "2026-11-16T10:15:00Z",
  "updatedAt": "2026-11-16T10:15:00Z"
}
```

- `schemaVersion` 从 1 开始；读旧版本时执行纯函数迁移，迁移失败不覆盖原文件，标记资产为 `needsMigration` 并在 UI 提示。
- 文档写盘使用“临时文件 + 原子替换”；每次修改防抖 500ms，关闭编辑器、切换资产、应用失活时立即 flush。
- 原图格式：PNG，sRGB；保留原始像素；不做有损压缩。
- 录制：MP4（H.264/AAC），沿用现有编码配置；首帧缩略图 JPEG。

#### 5.9.3 数据库 DDL

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA user_version = 1;

CREATE TABLE IF NOT EXISTS capture_asset (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL,
  source_app_bundle_id TEXT,
  source_app_name TEXT,
  window_title TEXT,
  pixel_width INTEGER NOT NULL,
  pixel_height INTEGER NOT NULL,
  original_path TEXT NOT NULL,
  document_path TEXT,
  thumbnail_path TEXT,
  duration_ms INTEGER,
  file_size INTEGER NOT NULL,
  ocr_text TEXT,
  ocr_languages TEXT,
  ocr_status TEXT NOT NULL DEFAULT 'pending',
  is_favorite INTEGER NOT NULL DEFAULT 0,
  deleted_at REAL
);

CREATE INDEX IF NOT EXISTS idx_capture_asset_created
  ON capture_asset(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_capture_asset_deleted
  ON capture_asset(deleted_at);
CREATE INDEX IF NOT EXISTS idx_capture_asset_kind
  ON capture_asset(kind);

CREATE VIRTUAL TABLE IF NOT EXISTS capture_asset_fts USING fts5(
  asset_id UNINDEXED,
  ocr_text,
  source_app_name,
  window_title,
  tokenize = 'unicode61'
);
```

- FTS5 不可用时（旧系统/系统 SQLite 裁剪）回退到 `LIKE` 查询；启动时探测一次并记录能力，不在每次查询重复探测。
- 搜索输入必须转义：把用户输入拆成 token，用双引号包裹并转义内部双引号，再追加 `*` 做前缀匹配；禁止把原始字符串直接拼进 `MATCH`。
- 数据库操作封装在 `actor CaptureLibraryStore` 内，SQLite 连接不跨 actor；UI 只通过 async 方法访问。
- 所有写操作使用事务；插入资产与 FTS 索引在同一事务内；失败回滚并删除已落盘文件（或标记孤儿文件由清理任务处理）。

### 5.10 存储布局

```
<pluginDataDirectory>/
  library.sqlite
  library.sqlite-wal
  library.sqlite-shm
  originals/
    20261116-101500-ab12cd.png
  documents/
    20261116-101500-ab12cd.capture.json
  thumbnails/
    20261116-101500-ab12cd.jpg
  recordings/
    20261116-110000-ef34gh.mp4
  trash/
    <asset-id>/
  tmp/
```

- 插件阶段根目录由 `StorageProviding.pluginDataDirectory(for: "com.coffic.lumi.plugin.capture")` 提供；独立 App 使用自身 `Application Support/com.coffic.capture/`。
- 路径全部相对于库根存储，数据库不存绝对路径；迁移/换机/沙盒容器变化时仍可解析。
- 用户另存到外部目录时，通过 `NSSavePanel`（沙盒下获取 security-scoped URL）写文件，不把外部路径写进数据库。
- 磁盘缓存（`DiskCacheProviding`）只用于可丢弃的预览加速，不用于原图/文档/录制；历史资产必须持久。
- 清理任务：启动时清理 `tmp/` 超 24 小时文件；每天清理回收站超 7 天资产；容量超限时提示，不静默删除收藏。

### 5.11 权限与隐私

| 权限 | 触发时机 | 失败处理 |
| --- | --- | --- |
| 屏幕录制 | 用户点击授权/首次捕获 | 引导到系统设置；不崩溃；可重试 |
| 麦克风 | 用户开启麦克风录制 | 录制继续但无麦克风轨，明确提示 |
| 辅助功能 | 仅滚动截图“自动滚动”模式（M2+） | 不可用时退回“手动滚动”模式，不阻塞基础功能 |
| 文件访问 | 用户选择保存目录/导出 | 保存面板取消视为取消，不报错 |

隐私规则：

1. 截图、标注、OCR、历史库全部本地完成；默认零网络。
2. 日志只记录资产 ID、耗时、错误码；不记录图片数据、OCR 全文、用户文件路径。
3. 翻译是唯一可能联网的功能：只发送 OCR 文字，不发送图片；发送前展示文本、目标服务与取消按钮；结果可关闭。
4. 崩溃报告与统计默认关闭；若要加入，必须单独征得同意，且不包含图像/文字内容。
5. 独立 App 提供 `PrivacyInfo.xcprivacy`：声明无追踪、无广告标识；按 Apple 当前要求列出 UserDefaults、文件时间戳等 required-reason API（提交前逐项核对代码）。
6. 录制时始终显示指示器；不允许隐藏录制状态；不录制麦克风时明确显示。

### 5.12 录制统一

- 把 `RecordingEngine`、`ScreenCaptureRecorder`、`RecordingSessionManager`、`RecordingFileWriter`、`RecordingPermissionService` 从 `PluginScreenRecorder` 上移到 `KitCapture/Recording`。
- `PluginScreenRecorder` 保留 agent 工具与设置页，但底层调用 `KitCapture` 的单例；Capture 插件也调用同一个单例。
- 迁移顺序：先复制到 `KitCapture` 并让新测试通过，再让 `PluginScreenRecorder` 改 import，最后删除旧实现与重复测试（M2）。
- 迁移期间保持 `start_recording` / `stop_recording` / `list_recordable_apps` 的工具名、参数、返回格式不变；这是现有 agent 工作流的外部契约。
- 录制输出目录：Capture UI 录制默认写入历史库 `recordings/`；`PluginScreenRecorder` 的 agent 工具仍支持用户指定输出目录。
- 录制会话单例要在插件禁用时可靠停止；按 `ScreenRecorderPlugin.swift` 中 #223 的注释处理结束路径，但把“异步 fire-and-forget”改为 `onDisable` 内 await 完成。

## 6. 里程碑

### M0：能力上移与风险验证（4–6 人日）

目标：在不改变现有插件行为的前提下，建立 `KitCapture` 基础，验证 Carbon 热键、跨屏坐标、OCR 结构化输出、窗口枚举四件事。

| 任务 | 内容 | 产出 | 测试 |
| --- | --- | --- | --- |
| C0.1 | 新建 `Packages/KitCapture`、`Packages/KitCaptureUI`、`Packages/PluginCapture` 骨架；平台声明、产品、测试 target、`TestPlan.md` | 三个包可 `swift build` | `swift build`；`check_platform_consistency.py` |
| C0.2 | 把 `ScreenCaptureService` 的采集逻辑上移为 `DisplayCaptureService`，注入 `DisplayProviding` | 现有 ChatScreenshot 行为不变 | 现有裁剪测试 + 新几何测试 |
| C0.3 | 合并权限服务为 `CapturePermissionService`，闭包注入 preflight/request | ChatScreenshot 与 ScreenRecorder 共用 | 权限分支测试（不触碰真实 TCC） |
| C0.4 | 把 `OcrEngine` 上移为 `CaptureOCRService`，新增 `CGImage` 输入与行包围盒 | `PluginOcr` 改用新服务，`ocr_image` 行为不变 | 现有 OCR 工具测试 + 图像输入测试 |
| C0.5 | 从 `RecordableWindowProvider` / `ComputerUseWindowProvider` 收敛 `WindowCatalog` | 窗口列表可注入原始窗口字典 | 过滤/排序/标题缺失测试 |
| C0.6 | 新建共享热键包（`KitGlobalHotkey` 或 `KitCapture/Hotkey`），实现 Carbon 注册/注销/冲突错误 | Capture 可注册独立热键 | 组合编码、注册失败、注销测试 |
| C0.7 | Xcode 工程与 CI 接线：本地包引用、测试脚本、TestPlan 体检 | 新包进入全量测试 | `Scripts/run-all-package-tests.sh` 子集 |

M0 验收：

- `PluginChatScreenshot`、`PluginOcr`、`PluginScreenRecorder` 的现有测试全绿。
- 现有截图、OCR、录制在真实 App 中行为不变。
- `KitCapture` 的几何测试覆盖：单屏、双屏同缩放、双屏混合缩放、负坐标、Y 翻转。
- 热键注册失败时不崩溃，能返回可展示的错误。
- 不新增用户可见 UI。

### M1：MVP 截图 + 编辑器 + 历史库（10–14 人日）

目标：完成“热键 → 捕获 → 标注 → 复制/保存 → 历史库/OCR”的闭环。

| 任务 | 内容 | 主要文件 | 测试 |
| --- | --- | --- | --- |
| C1.1 | 文档与标注模型、Codable、版本迁移 | `KitCapture/Document/*` | 编解码 roundtrip、旧版本迁移、未知字段容错 |
| C1.2 | 矩形/椭圆/直线/箭头/自由画笔/荧光笔/文字的模型与命中测试 | `CaptureAnnotation.swift` | 命中/选中/移动/删除 |
| C1.3 | 撤销/重做命令栈 | `DocumentStore.swift` 或编辑器状态 | 100 步、分支后清空重做、组合命令 |
| C1.4 | 渲染器（含文字、透明、裁剪） | `AnnotationRenderer.swift` | 像素采样、透明通道、文字区域非空、裁剪偏移 |
| C1.5 | 跨屏几何与裁剪 | `CaptureGeometry.swift`、`SelectionMapper.swift` | 混合 scale、负 origin、Y 翻转、边界钳制 |
| C1.6 | 捕获协调器状态机、单飞、取消 | `CaptureCoordinator.swift` | 并发触发、取消、失败不留窗口 |
| C1.7 | 区域遮罩 + 跨屏选区 + 键盘微调 | `KitCaptureUI/Overlay/*` | 几何单测 + UI 测试 |
| C1.8 | 窗口枚举、悬停高亮、点击捕获 | `WindowCatalog.swift`、`WindowHighlightOverlay.swift` | 窗口过滤、点击命中、目标消失 |
| C1.9 | 整屏捕获（鼠标所在屏/所有屏） | `DisplayCaptureService.swift` | 每屏一张、尺寸/缩放正确 |
| C1.10 | 编辑器面板、工具栏、缩放/适配、文字输入 | `CaptureEditorView.swift` 等 | 工具切换、快捷键、IME 手工验证 |
| C1.11 | 导出 PNG/JPEG、剪贴板、保存面板、文件名冲突 | `CaptureExporter.swift`、`PasteboardWriter.swift` | 尺寸/格式/透明、冲突后缀、剪贴板类型 |
| C1.12 | SQLite 库、迁移、FTS5/回退 | `CaptureDatabase.swift`、`CaptureLibraryStore.swift` | 插入/查询/搜索转义/事务回滚/并发 |
| C1.13 | 历史库 UI（网格/列表/搜索/详情/删除/恢复） | `CaptureLibraryView.swift` 等 | 分页、旧查询丢弃、删除恢复 |
| C1.14 | 缩略图、回收站、保留任务 | `ThumbnailStore.swift`、`RetentionPolicy.swift` | 缩略图尺寸、7 天清理、收藏豁免 |
| C1.15 | OCR 面板、后台识别、入库 | `CaptureOCRService.swift`、文字面板 | 识别/空结果/失败/搜索命中 |
| C1.16 | 插件生命周期、ActivityBar、设置、文档、命令、菜单栏 | `CapturePlugin.swift` + Adapters | 贡献注册/撤销、禁用恢复、幂等 |
| C1.17 | 全局热键、冲突提示、设置页改键 | `CaptureHotkeyCenter.swift`、`HotkeyRecorderView.swift` | 默认组合、失败提示、热切换 |
| C1.18 | 权限引导、拒绝分支、重启提示 | 设置页/遮罩 | 权限注入测试 + 手工 TCC |
| C1.19 | 真实 App 验收与性能打点 | 全部 | M1 验收清单 |

M1 验收（必须在真实 Lumi App 中完成，不以测试全绿替代）：

1. `⌥⇧A` 框选 → 标注箭头/矩形/文字 → `⌘C` → 粘贴到 TextEdit 与飞书，内容与预览一致。
2. `⌥⇧W` 悬停窗口高亮 → 点击 → 捕获；目标 App 不被激活。
3. `⌥⇧F` 捕获鼠标所在屏；设置“所有屏”后生成多条资产。
4. 历史库能看到刚才三条；按图中文字搜索能命中；删除后可在回收站恢复。
5. 关闭 Lumi 再打开，历史仍在；重新打开资产，原始像素未变，标注可继续编辑。
6. 禁用 Capture 插件后热键不再响应、菜单项/入口消失；重新启用后恢复；不残留全局热键。
7. 拒绝屏幕录制权限时不崩溃，引导到系统设置；授权后无需重启即可截图（若系统要求重启则给出明确提示）。
8. 录制功能入口在 M1 不展示或明确标注“即将推出”，避免半成品暴露。

### M2：高级能力与录制统一（10–15 人日）

| 任务 | 内容 | 验收 |
| --- | --- | --- |
| C2.1 | 钉图窗口（多钉、缩放、透明度、复制、关闭） | 钉图置顶且跨 Space；再次钉同一资产不重复 |
| C2.2 | 步骤编号、马赛克、模糊、裁剪工具、取色器 | 像素测试 + 视觉验收 |
| C2.3 | 翻译（OCR 文本 → LLM），发送前确认 | 取消不发送；发送内容仅文字；无网络时错误可读 |
| C2.4 | 滚动截图（实验） | 固定 fixture 拼接正确；失败有退出路径；不影响普通截图 |
| C2.5 | 录制 UI + `KitCapture` 录制会话 + `PluginScreenRecorder` 迁移 | 同一时刻只允许一个录制；工具契约不变 |
| C2.6 | 聊天附件：当前标注图加入会话 | 切换会话后旧结果不落入新会话（身份校验） |
| C2.7 | 窗口截图增强：阴影、子窗口、受保护内容提示 | 窗口消失/DRM 黑屏有可读提示 |
| C2.8 | 历史增强：收藏、批量导出、拖出、最近列表 | 拖到 Finder/IM 得到正确文件 |
| C2.9 | 性能优化与 Instruments 记录 | 达到 2.3 预算或记录偏差 |

M2 验收：

- 录制显示器/窗口各一次，含/不含麦克风（macOS 15+），停止后历史库可播放。
- 钉图窗口不出现在整屏截图中（排除自身窗口）。
- 翻译默认关闭；开启后发送前必须确认；日志无 OCR 全文。
- 滚动截图在固定网页/文档上完成 3 次，拼接无明显错位；失败时能退出并保留已捕获部分。

### M3：硬化与发布准备（5–8 人日）

| 任务 | 内容 |
| --- | --- |
| C3.1 | 补齐 zh-Hant/zh-HK/zh-TW；检查文案截断与复数 |
| C3.2 | 无障碍：标签、焦点顺序、键盘操作、VoiceOver 快速验证 |
| C3.3 | 崩溃恢复、孤儿文件清理、数据库完整性检查、磁盘占用 UI |
| C3.4 | 覆盖率与测试计划收尾：所有公开 API 在 TestPlan 中有用例；关键状态机分支覆盖 |
| C3.5 | 手工矩阵：macOS 14/15/26、Intel/Apple Silicon、双屏混合缩放、Spaces/全屏、Stage Manager、暗/亮、中文/英文、输入法 |
| C3.6 | 文档：About/Manual、设置项说明、常见问题、权限说明 |
| C3.7 | 性能复测与预算偏差记录 |
| C3.8 | 把插件 stage 从 `.preview` 提升为 `.stable`，policy 从 `.disabledByDefault` 改为 `.enabledByDefault`（只在校验通过后） |

M3 验收：M1/M2 全部场景回归；手工矩阵无阻塞问题；无 P0/P1 缺陷；性能预算达标或有批准的偏差。

### M4：独立 App 抽取与商店发布（12–20 人日）

| 任务 | 内容 | 门槛 |
| --- | --- | --- |
| C4.1 | 授权审计：确认代码版权归属、外部贡献、第三方依赖；决定双授权/重写/只做直接分发 | 法务确认后才能进入 C4.2 |
| C4.2 | 新仓库骨架：`CaptureApp/`、`Packages/FactoryCapture/`、`project.yml`、README 中英、CI | 可构建空壳 App |
| C4.3 | App shell：菜单栏常驻、主窗口历史库、单实例、登录项、首次启动引导 | 菜单栏/主窗口/登录项可用 |
| C4.4 | `FactoryCapture`：装配 `CapturePlugin` + 最小 Provider + `PluginActivityBar`（或独立根视图回退） | 独立 App 与插件行为一致 |
| C4.5 | 付费：StoreKit 2 权益服务、商品目录、免费/Pro 门控、恢复购买 | 沙盒账号购买/恢复通过 |
| C4.6 | 沙盒与权限：entitlements、security-scoped 保存、隐私清单 | 签名构建实测 |
| C4.7 | 发布：App Store 元数据、截图、隐私政策、审核备注；或直接分发 + 公证 + Sparkle | 通过 TestFlight/公证 |
| C4.8 | 数据迁移：从 Lumi 插件目录导入历史（可选） | 导入不破坏源数据 |
| C4.9 | 内测与指标：崩溃率、捕获成功率、OCR 成功率、付费转化 | 达到发布门槛 |

M4 验收：

- 独立 App 的捕获/标注/历史/OCR 行为与插件阶段一致；截图基线对比无回退。
- 沙盒下保存面板、外部目录、屏幕录制、麦克风、登录项全部实测通过。
- 付费墙：免费用户可用基础捕获/标注/复制/保存/OCR；Pro 解锁项按门控生效；恢复购买可用。
- App Store 审核材料齐备；无后台采集、无静默上传、录制指示器始终可见。

## 7. 测试策略

### 7.1 测试分层

| 层 | 范围 | 工具 | 是否进 CI |
| --- | --- | --- | --- |
| 单元 | 几何、文档、渲染、导出、搜索、热键、权限、状态机 | Swift Testing | 是 |
| 集成 | SQLite + 文件系统 + 缩略图 + 保留任务 | Swift Testing + 临时目录 | 是 |
| 插件生命周期 | KernelCore 装配、贡献注册/撤销、禁用/启用 | Swift Testing + 假 Provider | 是 |
| UI | 编辑器、历史库、设置、快捷键 | XCUITest + 测试模式 | 是（单独 job） |
| 手工 | TCC、真实屏幕、录制、多屏、输入法、App Store 沙盒 | 人工清单 | 发布前 |

### 7.2 单元测试清单

**几何**

- 单屏 1x/2x：选区 → 像素矩形，宽高与起点正确。
- 双屏同缩放：跨屏选区被正确拆分与拼接。
- 双屏混合缩放：1x 内容在 2x 画布上按目标矩形放大，2x 内容不缩放。
- 负坐标：主屏左侧/上方的显示器，选区不偏移。
- Y 翻转：屏幕顶部选区映射到图像顶部，不是底部。
- 边界：选区超出屏幕、小于 1px、恰好贴边。
- 旋转：0/180 必测；90/270 在 M2 前只验证“回退整屏”分支。

**文档与标注**

- Codable roundtrip，所有标注类型。
- 未知字段/缺失字段容错；schemaVersion 迁移。
- 命中测试：点在矩形内/边上/外；箭头端点；文字框。
- 移动/缩放/删除/层级调整。
- 撤销/重做 100 步；新操作清空重做栈。

**渲染**

- 100×100 白底画红矩形，采样角点/边/中心像素。
- 透明画布导出 PNG 保留 alpha；JPEG 填充白色。
- 箭头方向与箭头大小。
- 文字在指定区域产生非背景像素；中文/英文各一。
- 模糊/马赛克：区域内像素方差显著降低（M2）。
- 裁剪后坐标偏移正确。

**导出**

- PNG/JPEG 尺寸、格式、颜色空间。
- 文件名冲突追加序号；非法字符替换。
- 剪贴板写入 `public.png` 与 `public.tiff`；自定义 `NSPasteboard` 注入测试。
- 导出失败时编辑器状态不变。

**历史库**

- 插入/读取/更新/软删除/恢复/彻底删除。
- FTS5 搜索命中；FTS5 不可用时 LIKE 回退。
- 搜索输入含引号、`*`、`AND`、中文、空字符串；不得抛 SQL 错误。
- 分页稳定；同一时间戳的排序有确定性次级键。
- 并发插入/删除；事务回滚后无半条记录。
- 保留策略：收藏豁免、回收站 7 天、临时文件 24 小时。
- 数据库迁移：v1 → v2 幂等；损坏数据库启动时给出可恢复状态。

**OCR**

- 英文 fixture 含 "Capture"，断言包含该词（不做逐字精确断言，避免系统版本差异）。
- 中文 fixture 含清晰大字，断言包含指定汉字。
- 空白图返回空结果，不抛错。
- 指定语言列表传递给 Vision；非法语言回退默认。
- 识别结果的行包围盒在 0...1 范围内。

**热键**

- `HotkeyCombo` 编码/解码、显示字符串、修饰键校验。
- 注册成功/失败（注入 registrar 返回错误）。
- 重复注册同一组合、注销不存在的 ID。
- 修改组合后旧注册被注销。

**权限**

- preflight true 直接通过；false + request true；false + request false。
- 麦克风拒绝后录制不中断但无麦克风轨。
- 打开系统设置深链的 URL 正确（不实际打开）。

**录制**

- 假引擎：start/stop/cancel 状态迁移。
- 并发 start 只有一个成功。
- 未录制时 stop 抛 `notRecording`。
- macOS 14 + 麦克风 → 能力错误，不创建临时文件。
- 停止后临时文件移动到目标；跨卷失败回退拷贝（注入 FileManager 或临时目录模拟）。
- 插件禁用时停止并落盘。

**插件生命周期**

- `onBoot` 注册 ActivityBar/设置/命令/菜单项/工具。
- `onShutdown` 全部撤销；重复调用安全。
- `onDisable` 停热键、关面板、停录制；`onEnable` 恢复。
- 元数据 id/order/policy 稳定，不被无意修改。

### 7.3 UI 测试

- 启动参数 `-CaptureUITestMode`：
  - 捕获服务返回固定 fixture 图，不触碰 TCC。
  - 权限服务返回已授权。
  - 数据目录指向临时目录。
  - 禁用真实全局热键注册。
- 用例：
  1. 打开历史库空态 → 导入 fixture → 网格出现一条。
  2. 打开 fixture 编辑器 → 画矩形 → ⌘C → 读取测试剪贴板（通过测试宿主暴露的辅助接口）。
  3. 搜索 OCR 文本 → 结果只剩匹配项。
  4. 删除 → 回收站 → 恢复。
  5. 设置页修改热键 → 显示新组合；冲突时显示警告。
- 可访问性标识：`capture.library.grid`、`capture.library.search`、`capture.editor.canvas`、`capture.editor.tool.rectangle`、`capture.editor.copy`、`capture.editor.save`、`capture.settings.hotkey.region`。
- UI 测试不允许真实截图/真实录制；真实 TCC 只在手工清单验证。

### 7.4 手工验收矩阵

| 维度 | 取值 |
| --- | --- |
| macOS | 14.x、15.x、当前最新（26.x） |
| 芯片 | Apple Silicon、Intel（至少各一台） |
| 显示器 | 单屏、双屏同缩放、双屏混合缩放、负坐标、旋转屏（M2） |
| 空间 | 普通桌面、全屏 App、多 Space、Stage Manager |
| 语言 | 简体中文、English、繁体中文（M3） |
| 外观 | 深色、浅色 |
| 输入法 | 中文拼音、日文假名（文字工具） |
| 权限 | 首次未决定、已允许、已拒绝、系统设置中改回 |
| 录制 | 显示器、窗口、含/不含麦克风、无系统音频、最长时长边界 |
| 存储 | 磁盘接近满、只读目录、外部卷保存 |

每个发布候选至少跑一遍；结果记录在发布检查单中。

### 7.5 性能测量

- 使用 `os_signpost` 打点：`capture.begin`、`capture.captured`、`overlay.shown`、`editor.ready`、`render.export`、`ocr.done`、`library.query`。
- Instruments：Time Profiler、Allocations、Leaks、File Activity。
- 性能用例默认不跑硬阈值（避免 CI 抖动）；用 `CAPTURE_PERF=1` 开启，输出数值；超过预算 3 倍才失败。
- 每次修改捕获/渲染/库查询路径，至少记录一组前后数据到 PR 描述。

### 7.6 必跑命令

```bash
# 新增包
cd Packages/KitCapture && swift test
cd Packages/KitCaptureUI && swift test
cd Packages/PluginCapture && swift test

# 体检与一致性
python3 Scripts/check-test-targets.py KitCapture KitCaptureUI PluginCapture
python3 Scripts/check_platform_consistency.py
python3 Scripts/check-localization.py

# 受影响旧包
cd Packages/PluginChatScreenshot && swift test
cd Packages/PluginOcr && swift test
cd Packages/PluginScreenRecorder && swift test

# 全量（合并前）
bash Scripts/run-all-package-tests.sh
```

现有 CI `.github/workflows/agent-reliability-tests.yml` 会按测试组跑包测试；新包只要有 `Tests/` 就会进入全量脚本。UI 测试单独在 Xcode 测试计划中跑，不混入 `swift test`。

## 8. 验收标准

### 8.1 功能验收

| 编号 | 场景 | 通过标准 |
| --- | --- | --- |
| A1 | 区域截图 + 标注 + 复制 | 粘贴结果与编辑器预览像素级一致（允许系统色彩管理差异）；透明区域正确 |
| A2 | 窗口截图 | 目标窗口内容完整，目标 App 未激活；窗口消失时有可读错误 |
| A3 | 整屏截图 | 尺寸等于显示器原生像素；所有屏模式生成对应数量资产 |
| A4 | 历史库 | 截图 1 秒内出现；搜索、筛选、删除、恢复、重开编辑均可用 |
| A5 | OCR | 中英文 fixture 可识别；文本可复制；搜索结果命中 |
| A6 | 钉图 | 置顶、跨 Space、缩放、复制、关闭；不进入截图 |
| A7 | 录制 | 显示器/窗口可录；停止后文件可播放；历史库有首帧缩略图 |
| A8 | 热键 | 六个默认热键可用；冲突有提示；改键即时生效 |
| A9 | 权限 | 拒绝不崩溃；授权后可用；麦克风拒绝有提示 |
| A10 | 插件生命周期 | 禁用后无热键/入口/菜单残留；启用后恢复；录制被可靠停止 |
| A11 | 隐私 | 默认无网络；翻译需确认；日志无 OCR 全文与图片 |
| A12 | 本地化 | 中英文无缺失 key；无截断；日期/尺寸格式符合区域 |

### 8.2 非功能验收

- 2.3 的性能预算达标或有批准的偏差记录。
- 无主线程超过 100ms 的阻塞（Instruments 检查）。
- 无数据竞争/并发告警；Swift 6 编译无新增警告。
- 崩溃恢复：强杀 App 后重启，历史库可打开，未完成导出不产生半文件。
- 数据库损坏时给出“重建索引/导出可读资产”的恢复路径，不直接崩溃。
- 磁盘写入失败（只读/满）不丢内存中的编辑；用户可另存到其他位置。

### 8.3 完成证据

每个里程碑结束时提交：

1. 测试命令与结果（贴出通过数量，不写“全绿”而不给证据）。
2. 真实 App 操作截图/录屏（编辑器、历史库、设置、权限引导）。
3. 性能打点数据（捕获/渲染/查询/OCR）。
4. 已知问题清单与后续任务编号。
5. 若修改了现有插件，附旧行为回归证据（截图/OCR/录制的工具输出）。

## 9. 独立 App 抽取

### 9.1 抽取方式

采用与 Lode 相同的“专用装配根 + 独立 App shell”：

- `Packages/FactoryCapture`：`KernelFactory`、`ProviderFactory`、`ViewFactory`、`AppCommands`、`DedicatedPluginFactory`，只装配 `CapturePlugin` 与必要的基础插件（如 `PluginActivityBar`、日志/设置/存储 Provider）。
- `CaptureApp/`：`CaptureApp.swift`、`Capture-Info.plist`、`App.entitlements`、菜单栏控制器、登录项服务、首次启动引导。
- `project.yml`：XcodeGen 描述，bundle id `com.coffic.capture`，macOS 14.0，Swift 6，自动签名/团队与现有 App 保持一致。
- 独立仓库的 README 用英文为主、中文副页，写明构建入口与测试命令；不写本机路径与凭据。

`DedicatedAlwaysOnPlugin` 的用法与 Lode 一致：把 `CapturePlugin` 包成 `.alwaysOn`，避免独立 App 里被“插件管理”禁用。

### 9.2 独立 App shell

| 组件 | 行为 |
| --- | --- |
| 菜单栏 | 自有 `NSStatusItem`，左键打开菜单，右键快捷菜单；菜单含捕获、历史、设置、权限状态、退出 |
| 主窗口 | 历史库；关闭主窗口不退出 App（菜单栏常驻） |
| 登录项 | 设置页开关，使用 `SMAppService.mainApp`；默认关闭 |
| 单实例 | `LSMultipleInstancesProhibited` 或启动时检测已有实例并激活 |
| URL scheme | `coffic-capture://`，支持 `capture?mode=region`、`open?asset=<id>`；是否启用由产品决定 |
| 更新 | App Store 渠道由商店更新；直接分发渠道用 Sparkle，两者构建配置分开 |
| 引导 | 首次启动介绍热键、权限、历史库；不自动请求 TCC |
| 数据迁移 | 可选从 Lumi 插件数据目录导入；只读源、复制到自身容器，导入后可选择保留/删除源 |

### 9.3 付费模型

默认方案：**免费下载 + 一次性 Pro 解锁**（非消耗型 IAP），不在首版做订阅。

| 能力 | 免费 | Pro |
| --- | --- | --- |
| 区域/窗口/整屏截图 | 有 | 有 |
| 标注工具（基础） | 有 | 有 |
| 复制/保存/OCR | 有 | 有 |
| 历史保留 | 30 天 / 500 条 | 永久 / 无上限 |
| 钉图 | 1 个 | 多个 |
| 滚动截图 | 无 | 有 |
| 录制 | 无 | 有 |
| 翻译 | 无 | 有 |
| 导出预设/自定义文件名 | 基础 | 完整 |

实现：

- `CaptureFeatureGate` 由 `PluginCapture` 注入；Lumi 阶段用 `AllowAllFeatureGate`。
- 独立 App 用 `StoreKitEntitlementService` 实现 `StoreEntitlementProviding`（LumiProviders 已有契约），启动时加载权益、监听交易更新、支持恢复购买。
- 付费墙只出现在尝试使用 Pro 功能时；不阻断基础截图。
- 价格与免费额度在 TestFlight 阶段用三档价格/两组额度做小规模测试，再定最终值；不在本计划中写死。

### 9.4 沙盒与发布

- App Sandbox：`com.apple.security.app-sandbox`；用户选择文件读写；麦克风；网络仅在需要时（AI/更新）。
- 屏幕录制：TCC + 签名构建实测；首次使用由用户点击触发。
- 保存：`NSSavePanel` 获取 security-scoped URL；长期目录访问用 bookmark，不假设永久访问。
- 隐私清单：无追踪、无广告标识；按代码实际使用的 required-reason API 填写。
- App Store 审核备注：
  - 截图/录制均由用户显式触发；无后台采集。
  - 录制时始终显示指示器。
  - 默认不联网；翻译需用户确认。
  - 全局热键用于本地操作，不监听键盘内容。
- 若走直接分发：Developer ID 签名 + 公证 + Sparkle 签名更新；不使用 Mac App Store 的收据校验。

## 10. 授权与合规

这是 M4 的硬门槛，必须在写独立 App 代码前解决。

### 10.1 现状

- Lumi 仓库为 GPLv3（`LICENSE`、`README.md:9`）。
- `PluginChatScreenshot`、`PluginScreenRecorder`、`PluginOcr` 是 Lumi 仓库的一部分；把它们的代码移动到 `KitCapture` 不会改变其 GPL 授权属性。
- 独立 App 若链接 GPLv3 代码并通过 Mac App Store 分发，需要法务确认 GPLv3 与 Apple 分发条款/DRM 的兼容性；不能仅凭工程判断。

### 10.2 可选路径

| 路径 | 做法 | 代价 | 适用条件 |
| --- | --- | --- | --- |
| A. 双授权 | Coffic 作为唯一版权人，对 `KitCapture`/`KitCaptureUI` 同时提供 GPLv3 与商业授权；Lumi 用 GPLv3，独立 App 用商业授权 | 需要版权确认、贡献者 CLA、授权文本 | 所有贡献版权可归集到 Coffic |
| B. 独立重写 | Lumi 保留 GPL 实现；独立 App 使用 clean-room 重写的专有核心 | 开发成本高、两套实现有漂移风险 | 存在无法归集的第三方贡献 |
| C. 只做直接分发 | 独立 App 以 GPLv3 开源，官网/DMG 分发，不上 Mac App Store | 失去商店流量与支付 | 可接受开源与直接分发 |
| D. 放弃独立 App | 只保留 Lumi 插件 | 无独立收入 | 插件验证不达预期 |

推荐顺序：A → C → B；D 是止损选项。

### 10.3 执行要求

1. **版权审计**：用 `git log --format='%an <%ae>'` 统计每个待移动文件的作者；确认是否存在外部贡献；对外部贡献取得书面授权或重写。
2. **CLA**：从本计划实施起，新贡献要求签署 CLA（或 DCO + 版权归集声明），避免后续无法双授权。
3. **依赖审计**：列出所有第三方 Swift 包与系统框架；确认没有把 GPL/AGPL 代码带入独立 App；Apple 系统框架不受影响。
4. **文件头**：新文件写版权头与 SPDX 标识；移动文件保留原版权信息，不删除作者声明。
5. **法务确认**：M4 开始前由法务/负责人签字确认路径；未确认不得提交商店构建。
6. **文档边界**：本计划不构成法律意见；最终以法务结论为准。

## 11. 风险与开放问题

### 11.1 风险

| 风险 | 概率 | 影响 | 缓解 |
| --- | --- | --- | --- |
| GPL 与 App Store 不兼容 | 高 | 阻断 M4 | 先做授权审计；准备直接分发/重写备选 |
| 混合 DPI 坐标错误 | 中 | 截图错位，用户不信任 | 几何单测覆盖混合缩放/负坐标；真机多屏验收 |
| 90/270 旋转屏裁剪错误 | 中 | 特定用户不可用 | M1 回退整屏；M2 补旋转测试 |
| 全屏捕获延迟超预算 | 中 | 体验差 | 按屏捕获；测量后决定“先抓后遮罩”或“先遮罩后抓” |
| TCC 首次授权流程复杂 | 中 | 新用户流失 | 明确引导、系统设置深链、重启提示 |
| 热键冲突 | 中 | 功能不可用 | 注册失败提示、改键、禁用选项 |
| 滚动截图拼接错位 | 高 | 高级功能口碑 | 标记实验；固定 fixture 测试；失败可退出；不阻塞 MVP |
| 录制与截图同时进行导致资源竞争 | 中 | 卡顿/丢帧 | 共用会话单例；录制时降低截图并发；指示器排除 |
| 文本输入法在画布中错位 | 中 | 中文用户无法标注 | 使用 AppKit `NSTextView`；真机输入法验收 |
| 数据库/文件不一致 | 中 | 历史丢图 | 原子写、事务、启动完整性检查、孤儿清理 |
| 历史库磁盘膨胀 | 中 | 用户投诉 | 默认 90 天/10GB、回收站、收藏豁免、容量提示 |
| 插件禁用时录制未停 | 中 | 隐私事故 | `onDisable` await 停止；集成测试覆盖 |
| 独立 App 沙盒下保存失败 | 中 | 无法导出 | security-scoped bookmark；保存面板实测 |
| App Store 审核认为后台采集 | 低 | 拒审 | 只做用户触发；录制指示器；审核备注与演示 |
| 范围蔓延到视频编辑/云服务 | 高 | 延期 | 非目标写死；新需求进 backlog 不插队 |

### 11.2 开放问题与默认决策

| 问题 | 默认决策 | 何时拍板 |
| --- | --- | --- |
| 独立 App 付费模型 | 免费 + 一次性 Pro 解锁 | M4 前用 TestFlight 验证 |
| 是否同时做直接分发 | 先 App Store；直接分发作为备选 | C4.1 授权结论后 |
| 翻译是否进首版 | 不进；M2 实验，默认关闭 | M2 开始前 |
| 是否做区域录制 | 不做；只做显示器/窗口 | M3 复盘 |
| 历史默认保留 | 90 天，收藏豁免，可改永久 | M1 可用后看真实使用 |
| 共享包是否发布到远程 | API 稳定后发布；之前用本地 path 依赖 | M3 末 |
| 90/270 旋转屏 | M2 完成；之前回退整屏 | M1 验收时确认覆盖比例 |
| 是否保留 `PluginScreenRecorder` 独立 UI | 保留工具与设置，录制 UI 统一到 Capture | M2 迁移时 |
| 独立 App 是否菜单栏常驻 | 是，默认无 Dock 图标，可在设置中显示 Dock | M4 原型验证 |

## 12. 任务清单

以下清单按依赖顺序排列，可直接作为实施看板。估算为单人日，含测试，不含评审等待。

### M0

| ID | 任务 | 依赖 | 估算 |
| --- | --- | --- | --- |
| C0.1 | 新建三个包骨架与 TestPlan | 无 | 0.5 |
| C0.2 | 采集服务上移 + DisplayProviding | C0.1 | 1 |
| C0.3 | 权限服务合并 | C0.1 | 0.5 |
| C0.4 | OCR 服务上移 + 结构化结果 | C0.1 | 1 |
| C0.5 | WindowCatalog 收敛 | C0.1 | 0.5 |
| C0.6 | 共享热键包 | C0.1 | 1 |
| C0.7 | Xcode/CI 接线 + 旧插件回归 | C0.2–C0.6 | 0.5 |

### M1

| ID | 任务 | 依赖 | 估算 |
| --- | --- | --- | --- |
| C1.1 | 文档/标注模型与迁移 | C0.1 | 1 |
| C1.2 | 标注命中/移动/删除 | C1.1 | 1 |
| C1.3 | 撤销/重做 | C1.2 | 0.5 |
| C1.4 | 渲染器 | C1.1 | 1.5 |
| C1.5 | 跨屏几何/裁剪 | C0.2 | 1.5 |
| C1.6 | 捕获状态机/单飞/取消 | C1.5 | 1 |
| C1.7 | 区域遮罩 UI | C1.5, C1.6 | 1.5 |
| C1.8 | 窗口枚举/高亮/捕获 | C0.5, C1.6 | 1 |
| C1.9 | 整屏捕获 | C1.6 | 0.5 |
| C1.10 | 编辑器 UI/工具栏/缩放/IME | C1.4 | 2 |
| C1.11 | 导出/剪贴板/保存 | C1.4 | 1 |
| C1.12 | SQLite 库/FTS | C0.1 | 1.5 |
| C1.13 | 历史库 UI | C1.12 | 1.5 |
| C1.14 | 缩略图/回收站/保留 | C1.12 | 1 |
| C1.15 | OCR 面板/后台识别 | C0.4, C1.12 | 1 |
| C1.16 | 插件生命周期/贡献 | C1.7–C1.14 | 1.5 |
| C1.17 | 热键/设置页 | C0.6, C1.16 | 1 |
| C1.18 | 权限引导 | C0.3, C1.16 | 0.5 |
| C1.19 | 真机验收/性能 | 全部 | 1.5 |

### M2

| ID | 任务 | 依赖 | 估算 |
| --- | --- | --- | --- |
| C2.1 | 钉图窗口 | C1.10 | 1 |
| C2.2 | 步骤/马赛克/模糊/裁剪/取色 | C1.4 | 2 |
| C2.3 | 翻译 | C1.15, LLM Provider | 1 |
| C2.4 | 滚动截图（实验） | C1.6, C1.10 | 3 |
| C2.5 | 录制 UI + 录制统一 | C0.3, C1.16 | 3 |
| C2.6 | 聊天附件 | C1.10, ProviderMessageSender | 0.5 |
| C2.7 | 窗口增强/受保护内容 | C1.8 | 1 |
| C2.8 | 历史增强 | C1.13 | 1 |
| C2.9 | 性能优化 | M1/M2 | 2 |

### M3

| ID | 任务 | 依赖 | 估算 |
| --- | --- | --- | --- |
| C3.1 | 繁体本地化 | M2 | 1 |
| C3.2 | 无障碍 | M2 | 1 |
| C3.3 | 恢复/清理/磁盘 UI | M2 | 1.5 |
| C3.4 | 覆盖率/TestPlan 收尾 | M2 | 1 |
| C3.5 | 手工矩阵 | M2 | 1.5 |
| C3.6 | 文档/FAQ | M2 | 1 |
| C3.7 | 性能复测 | M2 | 0.5 |
| C3.8 | 提升 stage/policy | 全部 | 0.5 |

### M4

| ID | 任务 | 依赖 | 估算 |
| --- | --- | --- | --- |
| C4.1 | 授权审计与法务确认 | M3 | 2 |
| C4.2 | 新仓库骨架/CI | C4.1 | 1.5 |
| C4.3 | App shell（菜单栏/主窗/登录项/引导） | C4.2 | 2 |
| C4.4 | FactoryCapture 装配 | C4.2 | 1.5 |
| C4.5 | StoreKit 2 / 付费墙 | C4.3 | 2.5 |
| C4.6 | 沙盒/权限/隐私清单 | C4.3 | 1.5 |
| C4.7 | 商店/直接分发发布 | C4.5, C4.6 | 3 |
| C4.8 | 数据迁移 | C4.4 | 1 |
| C4.9 | 内测/指标/发布检查 | 全部 | 2 |

合计约 43–61 人日（不含评审、法务与商店审核等待）。

## 附录 A：核心 API 草案

```swift
#if os(macOS)
public struct WindowDescriptor: Sendable, Equatable, Identifiable {
    public let id: CGWindowID
    public let ownerPID: pid_t
    public let ownerName: String
    public let title: String?
    public let frame: CGRect          // 全局屏幕坐标
    public let layer: Int
    public let isOnScreen: Bool
}

public struct CaptureSessionID: Hashable, Sendable {
    public let rawValue: UUID
}

@MainActor
public final class CaptureCoordinator {
    public private(set) var phase: CapturePhase
    public func start(_ request: CaptureRequest) async throws -> CaptureDocument
    public func cancel()
}

public enum CapturePhase: Sendable, Equatable {
    case idle
    case preparing
    case capturing
    case selecting
    case editing
    case exporting
    case failed(String)
}

public struct AnnotationRenderOptions: Sendable {
    public var includeAnnotations: Bool
    public var background: BackgroundStyle   // .transparent / .white / .color
    public var scale: CGFloat
}

public enum BackgroundStyle: Sendable, Equatable {
    case transparent
    case solid(CGColor)
}

public struct CaptureSearchQuery: Sendable, Equatable {
    public var text: String
    public var kind: CaptureAssetKind?
    public var favoritesOnly: Bool
    public var from: Date?
    public var to: Date?
    public var limit: Int
    public var offset: Int
}
#endif
```

## 附录 B：快捷键与命令

### B.1 全局热键默认值

| 动作 | 默认组合 | 可改 |
| --- | --- | --- |
| 区域截图 | `⌥⇧A` | 是 |
| 窗口截图 | `⌥⇧W` | 是 |
| 整屏截图 | `⌥⇧F` | 是 |
| OCR 区域 | `⌥⇧O` | 是 |
| 开始/停止录制 | `⌥⇧R` | 是 |
| 打开历史库 | `⌥⇧H` | 是 |

规则：

- 不注册没有 ⌘/⌥/⌃ 的组合。
- 冲突时保留旧注册，提示用户改键；不静默覆盖。
- 录制进行中仍允许截图；录制窗口不进入截图（排除本 App 窗口）。
- 全局热键只在插件启用时注册；禁用/退出必须注销。

### B.2 编辑器快捷键

| 动作 | 快捷键 |
| --- | --- |
| 复制标注图 | ⌘C |
| 复制原图 | ⌥⌘C |
| 保存 | ⌘S |
| 另存为 | ⇧⌘S |
| 撤销/重做 | ⌘Z / ⇧⌘Z |
| 缩放 | ⌘+ / ⌘- / ⌘0 |
| 删除选中标注 | Delete |
| 钉在桌面 | ⌘P |
| 打开历史库 | ⌘L |
| 关闭编辑器 | Esc |

### B.3 Agent 工具契约

| 工具 | 参数 | 返回 | 失败 |
| --- | --- | --- | --- |
| `capture_screen` | `mode`: region/window/display；`display_id`?；`include_cursor`? | JSON：asset id、path、width、height | 抛 `ToolExecutionError` |
| `capture_window` | `app`；`window_title`? | 同上 | 找不到窗口/权限不足时抛错 |
| `list_capture_history` | `query`?；`limit`? | JSON 数组：id、kind、created_at、size、ocr_excerpt | 查询失败抛错 |

`ocr_image` 保持现有契约，不重命名。

## 附录 C：状态与日志字段

建议的 signpost 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `session_id` | String | 截图/录制会话 UUID |
| `mode` | String | region/window/display/scroll/recording |
| `display_count` | Int | 参与捕获的显示器数 |
| `pixel_width` / `pixel_height` | Int | 输出尺寸 |
| `capture_ms` | Double | 抓取耗时 |
| `render_ms` | Double | 渲染耗时 |
| `ocr_ms` | Double | OCR 耗时 |
| `db_ms` | Double | 数据库操作耗时 |
| `error_code` | String | 稳定错误码，不包含路径/文本 |

日志中禁止出现：图片数据、OCR 全文、用户文件路径、窗口标题全文（可记录哈希或长度）。

## 附录 D：发布检查单

### 插件阶段

- [ ] M0/M1/M2/M3 验收全部通过
- [ ] 现有 ChatScreenshot / OCR / ScreenRecorder 回归通过
- [ ] 全量包测试通过
- [ ] `check_platform_consistency.py` 通过
- [ ] `check-localization.py` 通过
- [ ] 真机多屏/权限/录制矩阵通过
- [ ] 性能预算达标或有批准偏差
- [ ] 插件 stage/policy 已按验收结果调整
- [ ] 文档/About/Manual 可从设置打开

### 独立 App

- [ ] 授权路径已由法务确认
- [ ] 沙盒下保存/权限/登录项实测通过
- [ ] StoreKit 购买/恢复/退款路径实测
- [ ] 隐私清单与隐私政策一致
- [ ] App Store 审核备注与演示账号/步骤齐备
- [ ] 崩溃率与核心成功率达标
- [ ] 数据导入不破坏 Lumi 源数据
- [ ] 直接分发（如启用）完成签名/公证/更新验证