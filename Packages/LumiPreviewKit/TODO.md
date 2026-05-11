# LumiPreviewKit TODO

> 目标：为 Lumi Editor 提供接近 Xcode 的 `#Preview` 体验。
>
> 当前已经具备 `#Preview` 扫描、Xcode/SPM 构建、动态 dylib 入口、独立宿主进程、错误诊断和截图预览能力。下一阶段重点从"截图预览"演进到"真实可交互 Live Canvas"。

---

## 原则

- [x] 只支持 SwiftUI `#Preview { ... }` / `#Preview("Title") { ... }`，不恢复旧的注册式 Contributor 预览。
- [x] 保留当前图片模式，作为稳定 fallback、缩略预览、错误恢复和低风险默认路径。
- [x] 新增 Live 模式，用户看到和操作的是宿主进程中的真实 `NSHostingView/NSView`。
- [x] Live 模式继续使用独立 `LumiPreviewHostApp`，避免预览代码崩溃拖垮 Lumi 主进程。
- [x] 不把外部项目的预览 dylib 直接加载进 Lumi 主进程，除非后续明确做实验开关。
- [x] 不依赖第三方运行时作为核心路径；InjectionIII / Inject / HotSwiftUI 只作为 hot reload 机制参考。

---

## 当前基线

- [x] `PreviewScanner` 能识别真实 `#Preview`，跳过注释/字符串，提取 title、line range、body source。
- [x] `BuildPlanner` 能识别 SPM Package、Xcode project/workspace。
- [x] `SPMCompiler` / `XcodeCompiler` 能提供构建上下文和编译参数。
- [x] `PreviewEntryBuilder` 能生成真实 `NSView` entry dylib，失败时回退为结构化诊断。
- [x] `LumiPreviewHostApp` 能独立加载 dylib，并把真实 view 离屏渲染成 PNG。
- [x] `EditorPreviewPlugin` 能在预览 panel 中显示预览列表、运行状态、图片结果和错误日志。
- [x] 预览错误视图支持展示并复制构建失败日志。

---

## 阶段一：显示模式模型

> 目标：把"图片预览"和"Live 预览"明确建模，UI 和 engine 不再假设只有 PNG。

- [x] 新增预览显示模式：`image` / `live`。
- [x] session 状态中记录当前显示模式、是否支持 live、当前 live host/window 状态。
- [x] 图片模式继续使用现有 `previewImagePNGBase64`。
- [x] Live 模式失败时自动降级到图片模式或错误视图，并给出明确原因。
- [x] 模式切换不触发不必要的全量重建；能复用当前已构建 dylib 时优先复用。
- [x] 测试：从 image 切到 live，session 状态正确变化。
- [x] 测试：live 启动失败后回退 image，错误原因可见。

---

## 阶段二：右下角模式切换 UI

> 目标：在预览界面右下角提供一个轻量 tab/segmented control，用来切换"图片模式"和"Live 模式"。

- [x] 在预览画布右下角增加模式 tab：`Image` / `Live`。
- [x] 当前模式高亮，另一个模式可点击切换。
- [x] Live 不可用时，`Live` tab 显示 disabled 状态，并通过 tooltip 或错误区域说明原因。
- [x] 切换到 `Image` 时隐藏 live host window，显示当前 PNG。
- [x] 切换到 `Live` 时隐藏 PNG surface，显示 live canvas 占位层，并请求 host 贴合该区域。
- [x] tab 不能遮挡错误日志的复制按钮、预览内容主体和底部状态文本。
- [x] 测试：预览 panel 底部 tab 点击切换模式。
- [x] 测试：窗口 resize 后 tab 仍固定在预览区域右下角。

---

## 阶段三：Live Host Window 协议

> 目标：宿主进程不再只返回 PNG，还能创建和管理一个真实可交互的预览窗口。

- [x] 扩展 host JSON 协议，新增 live 命令：
  - `startLivePreview`
  - `updateLiveFrame`
  - `showLivePreview`
  - `hideLivePreview`
  - `reloadLivePreview`
  - `stopLivePreview`
- [x] `startLivePreview` 加载当前 preview dylib，创建真实 `NSHostingView/NSView`。
- [x] host 创建 borderless preview window，窗口内容为真实 preview view。
- [x] `updateLiveFrame` 接收 Lumi panel 中 live canvas 的屏幕坐标和尺寸，host window 跟随移动和 resize。
- [x] `showLivePreview` / `hideLivePreview` 根据 tab、panel 可见性、Lumi 窗口激活状态控制 host window。
- [x] `stopLivePreview` 关闭 live window，释放当前 view。
- [x] host window 仍能按需截图，供 fallback、缩略图或状态同步使用。
- [x] 测试：host 收到 live frame 后创建对应尺寸 window。
- [x] 测试：hide/stop 后 window 被移除且不会残留。

---

## 阶段四：Live Canvas 嵌入体验

> 目标：视觉上接近嵌入式 canvas。实现方式不是跨进程嵌入 `NSView`，而是让独立 host window 精确覆盖 Lumi panel 中的 canvas 区域。

- [x] EditorPreviewPlugin 计算 live canvas 的全局屏幕 rect。
- [x] Lumi 窗口移动、resize、进入/退出全屏、panel 切换 tab 时，持续同步 rect 给 host。
- [x] Live window 与 Lumi 主窗口保持层级一致：Lumi 激活时显示，失焦或 panel 隐藏时隐藏。
- [x] 处理多显示器和 Retina scale，确保位置和尺寸不漂移。
- [x] 处理 panel 被遮挡、滚动、折叠、关闭时的 live window 隐藏。
- [x] Live window 背景、圆角、裁剪与当前预览 canvas 视觉一致。
- [x] 测试：移动 Lumi 窗口后 live window 跟随。
- [x] 测试：resize panel 后 live 内容尺寸更新。
- [x] 测试：切换到其他 bottom tab 后 live window 消失。

---

## 阶段五：交互行为

> 目标：用户操作进入真实 preview view，而不是操作截图。

- [x] 鼠标点击、hover、滚轮、拖拽直接由 host window 接收。
- [x] 支持键盘焦点：点击 Live 画布后，键盘事件进入 preview view。
- [x] 从 Live 画布外点击 Lumi UI 时，正确把焦点还给 Lumi。
- [x] 支持 SwiftUI 动画、`onAppear`、`task`、异步状态更新。
- [x] 支持输入控件、列表滚动、按钮点击等基本交互。
- [x] 对预览代码弹出的 sheet/popover/menu 做最小可用处理。
- [x] 测试：按钮点击后 preview 状态变化。
- [x] 测试：ScrollView/List 可滚动。
- [x] 测试：TextField 可输入并能退出焦点。

---

## 阶段六：Live Reload

> 目标：保存 Swift 文件后，Live 模式能更新真实 view。

- [x] 复用现有 `PreviewEntryBuilder` 增量构建 preview dylib。
- [x] 构建成功后，host `reloadLivePreview` 加载新 dylib，替换 root view。
- [x] 替换 view 时保持 live window 的位置、尺寸、显示状态。
- [x] 构建失败时保留旧 live view，同时在 Lumi 错误区域展示新错误。
- [x] 用户手动刷新时，优先刷新 live view；图片模式仍刷新 PNG。
- [x] 记录 build/reload 耗时，显示在预览状态区。
- [x] 研究 InjectionIII / Inject / HotSwiftUI 的热重载机制，评估后续是否做函数级或文件级更细粒度 reload。
- [x] 测试：修改 preview body 后 live view 更新。
- [x] 测试：reload 编译失败时旧 live view 不被销毁。

---

## 阶段七：错误与降级

> 目标：Live 模式失败时用户能理解原因，并能继续使用图片模式。

- [x] host 启动失败：显示错误视图，保留复制日志按钮。
- [x] dylib 加载失败：显示构建/链接/运行时诊断。
- [x] live window 创建失败：自动切回图片模式。
- [x] live host 崩溃：自动重启 host，当前模式标记为 failed，并允许用户重试。
- [x] Lumi 失去 live window 控制时，强制隐藏/关闭 host window，避免悬浮残留。
- [x] `Image` tab 始终可用，作为用户手动降级入口。
- [x] 测试：host 崩溃后 panel 不残留 live window。
- [x] 测试：复制错误日志包含 live 启动失败原因。

---

## 阶段八：体验打磨

- [x] Live/Image tab 样式与现有 preview panel 一致，避免像浮层广告。
- [x] 图片模式和 Live 模式共用预览列表、标题、构建状态、错误视图。
- [x] Live 模式启动中显示明确 loading 状态，不展示旧截图冒充 live。
- [x] Live 模式首帧完成后再隐藏 loading 状态。
- [x] 多个 `#Preview` 切换时，旧 live view 立即隐藏，新 view 就绪后显示。
- [x] 支持保存用户偏好的默认模式：默认 Image 或默认 Live。
- [x] 对 Live 模式增加显式"停止"行为，便于释放资源。

---

## 参考方案

- [InjectionIII](https://github.com/johnno1962/InjectionIII)：参考动态编译、`dlopen`、hot reload 思路。
- [Inject](https://github.com/krzysztofzablocki/Inject)：参考 SwiftUI/AppKit 注入体验和状态刷新方式。
- [HotSwiftUI](https://github.com/johnno1962/HotSwiftUI)：参考 SwiftUI 热刷新机制。
- [XcodePreviews](https://github.com/Iron-Ham/XcodePreviews)：参考独立 preview host target、最小化构建和 preview 启动流程。
- [SnapshotPreviews](https://github.com/EmergeTools/SnapshotPreviews) / [Prefire](https://prefire.ru/)：参考 `#Preview` 收集、组织和 snapshot fallback。

---

## 已知限制

- 公开 API 下无法把另一个进程里的任意 `NSView` 直接嵌入 Lumi 的 view hierarchy。
- Live Canvas 采用"独立 host window 覆盖在 Lumi panel 对应区域"的方式实现，视觉上接近嵌入，但工程上仍是跨进程窗口协作。
- 该方案需要重点处理窗口层级、焦点、全屏 Space、多显示器、Retina scale 和隐藏时机。
- 当前图片模式会长期保留，不应被 Live 模式替代掉。
