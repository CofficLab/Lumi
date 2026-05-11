# LumiPreviewKit 任务列表

> 独立 Swift Package，为 Lumi Editor 提供 `#Preview` 实时预览能力。
> **零第三方依赖**。运行时需要系统工具链（`swift` / `xcodebuild`）。

---

## 阶段一：源码扫描（PreviewScanner）

> 文件：`Sources/LumiPreviewKit/Scanner/PreviewScanner.swift`
> 测试：`Tests/LumiPreviewKitTests/PreviewScannerTests.swift`

- [x] 迁移 LumiApp 插件中 `SwiftUIPreviewSourceScanner` 的核心逻辑到 `PreviewScanner.scan(fileURL:sourceText:)`，保留 code mask、注释/字符串跳过、花括号平衡能力
- [x] 测试：单个 `#Preview` 能被检测到，返回 `PreviewDiscovery`（title、lineNumber、endLineNumber）
- [x] 测试：多个 `#Preview` 全部被检测到
- [x] 测试：`#Preview("Title")` 的 title 被正确提取
- [x] 测试：注释中的 `#Preview` 不被误检
- [x] 测试：字符串中的 `#Preview` 不被误检
- [x] 测试：多行字符串中的 `#Preview` 不被误检
- [x] 测试：嵌套花括号正确匹配，`endLineNumber` 准确
- [x] 测试：`primaryTypeName` 被正确提取（如 `MyView`）
- [x] 测试：`bodySource` 闭包体被正确提取

---

## 阶段二：项目类型检测（BuildPlanner）— SPM 部分

> 文件：`Sources/LumiPreviewKit/Compiler/BuildPlanner.swift`
> 测试：`Tests/LumiPreviewKitTests/BuildPlannerTests.swift`
> 范围：**只实现 SPM 检测**，Xcode 部分留到阶段七

- [x] 实现向上遍历文件系统查找 `Package.swift`
- [x] 找到 `Package.swift` 后，解析出文件所属的 target name（匹配 target 的 `path` / `sources` 配置）
- [x] 返回 `BuildStrategy.spm(packageDirectory:targetName:)`
- [x] 未找到任何项目文件时返回 `nil`
- [x] 测试：SPM Package 中的文件 → 返回 `.spm` 策略
- [x] 测试：无项目上下文的文件 → 返回 `nil`
- [x] 测试：Lumi 自身的 `LumiUI` Package 文件能被正确识别

---

## 阶段三：SPM 编译（SPMCompiler）

> 文件：`Sources/LumiPreviewKit/Compiler/SPMCompiler.swift`
> 测试：`Tests/LumiPreviewKitTests/SPMCompilerTests.swift`（新建）

- [x] 实现 `build(packageDirectory:targetName:)`：用 `Process` 执行 `swift build --target <name>`，捕获 stdout / stderr
- [x] 编译成功时，在 `.build/debug/` 下定位编译产物，返回产物路径
- [x] 编译失败时，解析 stderr 提取错误信息（文件名、行号、描述），抛出 `PreviewError.compilationFailed`
- [x] 利用 SPM 内置增量编译，不自行实现增量逻辑
- [x] 测试：编译存在的 SPM target → 成功返回产物路径
- [x] 测试：编译不存在的 target → 抛出 `compilationFailed`
- [x] 测试：编译有语法错误的代码 → 错误信息包含文件名和行号

---

## 阶段四：宿主进程通信（stdin/stdout JSON）

> 文件：`Sources/LumiPreviewHostApp/main.swift`、`Sources/LumiPreviewKit/Host/PreviewHostProcess.swift`
> 测试：`Tests/LumiPreviewKitTests/HostProcessTests.swift`（新建）
> 决策：**使用 stdin/stdout JSON**，不用 XPC。简单可控，后续有需要再升级

- [x] 定义消息类型：`RenderRequest`（含 PreviewDiscovery 信息）、`RenderResponse`（成功/失败）、`ErrorResponse`
- [x] 实现 `PreviewHostProcess.launch(executableURL:)`：用 `Process()` 启动 `LumiPreviewHostApp`，建立 stdin/stdout 管道
- [x] 实现 `HostConnection.requestRender(discovery:)`：序列化 `RenderRequest` 为 JSON 写入 stdin
- [x] 实现 `HostConnection.requestRefresh()`：发送刷新指令
- [x] 实现 `HostConnection.terminate()`：终止宿主进程
- [x] 实现宿主进程侧：从 stdin 读取 JSON，解析 `RenderRequest`，输出 `RenderResponse` 到 stdout
- [x] 实现宿主进程侧：收到渲染请求后，在 `NSHostingView` 中创建 SwiftUI 视图
- [x] 测试：启动宿主进程 → 发送 `RenderRequest` → 收到 `RenderResponse`
- [x] 测试：宿主进程异常退出 → `PreviewHostProcess` 检测到并抛出 `hostLaunchFailed`

---

## 阶段五：引擎集成（PreviewEngine）

> 文件：`Sources/LumiPreviewKit/PreviewEngine.swift`
> 测试：`Tests/LumiPreviewKitTests/PreviewEngineTests.swift`（新建）

- [x] 实现 `PreviewEngine` 协议的具体类（`LivePreviewEngine`），串联以下流程：
  - `discoverPreviews(in:)` → 调用 `PreviewScanner.scan`
  - `startPreview(_:)` → `BuildPlanner.plan` → 编译 → `PreviewHostProcess.launch` → `requestRender` → 返回 `PreviewSession`
  - `refreshPreview(_:)` → 增量编译 → `requestRefresh`
  - `stopPreview(_:)` → `terminate`
- [x] 实现 `PreviewSession` 的具体类，维护 `PreviewSessionState` 状态机（planning → compiling → launching → running / failed / stopped）
- [x] 测试：完整的 scan → build → launch → render 管线（用简单的 SPM Package 端到端验证）
- [x] 测试：编译失败 → session 状态变为 `failed`
- [x] 测试：`stopPreview` → session 状态变为 `stopped`，宿主进程已终止

---

## 阶段六：Lumi 插件集成

> 这个阶段的工作在 Lumi 主项目中进行，不在本 Package 内。
> 仅当阶段 1-5 全部完成后才可开始。

- [x] 在 Lumi 主项目的 `Package.swift` 或 Xcode 项目中添加 `LumiPreviewKit` 依赖
- [x] 新建 `EditorPreviewPlugin`：检测当前编辑器文件中的 `#Preview`，调用 `LumiPreviewKit` 的 `LivePreviewEngine`
- [x] Preview 面板 UI：展示状态（planning / compiling / running / failed）、编译错误信息、刷新按钮
- [ ] 测试：打开 Lumi 自身 SPM Package 文件 → 动态预览工作
- [ ] 测试：打开 LumiApp 内部文件 → `#Preview` 动态预览工作

---

## 阶段七：Xcode 项目支持

> 文件：`Sources/LumiPreviewKit/Compiler/BuildPlanner.swift`（扩展）、`XcodeCompiler.swift`
> 前置：阶段六完成

- [x] `BuildPlanner` 扩展：向上查找 `.xcodeproj` / `.xcworkspace`，返回 `BuildStrategy.xcode`
- [x] `XcodeCompiler.build(projectURL:scheme:configuration:)`：调用 `xcodebuild build`，捕获输出
- [x] 从 DerivedData 定位编译产物路径
- [x] 测试：编译 `.xcodeproj` → 成功返回产物路径
- [x] 测试：编译失败 → 返回编译错误信息
- [x] 端到端验证：用外部 Xcode 项目测试

---

## 阶段八：增量编译

> 文件：`Sources/LumiPreviewKit/Compiler/IncrementalCompiler.swift`、`XcodeCompiler.swift`
> 前置：阶段七完成
> 参考：[Inject](https://github.com/krzysztofzablocki/Inject)、[InjectionIII](https://github.com/johnno1962/InjectionIII) 的 `dlopen` + `swift-frontend` 实现

- [x] `XcodeCompiler.extractCompileCommand(for:buildLog:)`：从 build log 提取 `swift-frontend` 编译命令
- [x] `IncrementalCompiler.compile(fileURL:compileCommand:)`：执行单文件编译，输出 `.o`
- [x] 链接 `.o` 为 `.dylib`
- [x] codesign 签名 `.dylib`
- [x] 宿主进程通过 `dlopen` 加载 `.dylib`
- [x] 宿主进程解析 dylib 预览入口并替换视图
- [x] 测试：单文件修改 → 增量编译 → 宿主进程刷新，耗时 < 3 秒
- [x] 测试：单文件编译失败 → 返回错误
- [x] 测试：编译失败 → 宿主进程不受影响

---

## 阶段九：优化

> 前置：阶段八完成

- [x] 编译缓存：未变化的 target 不重新编译
- [x] 并发预览：支持同时预览多个视图
- [x] 环境注入：支持用户为预览注入 `@EnvironmentObject` 等 mock
- [x] 错误恢复：宿主进程崩溃后自动重启
- [x] 性能监控：记录编译耗时、刷新耗时
- [x] 公开 API 文档注释
