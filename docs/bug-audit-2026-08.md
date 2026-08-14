# Lumi 代码库 Bug 审计报告（2026-08）

> 审计范围：`LumiApp/`、`Packages/`、`Plugins/`、`Config/`、`ci_scripts/` 及各子 App（AppIconDesigner / BookletMaker / CADDesigner / DatabaseManager / NettoExtension）。
> 审计方式：静态代码审查（多路并行深读源码），按"可复现性 + 影响"筛选真实缺陷，已剔除风格问题与经核实的误报。
> 严重度定义：**高** = 可能崩溃 / 数据丢失 / 功能失效；**中** = 特定条件下出错或泄漏；**低** = 健壮性 / 性能隐患。

---

## 目录

- [一、高严重度（建议立即修复）](#一高严重度建议立即修复)
- [二、中严重度](#二中严重度)
- [三、低严重度](#三低严重度)
- [四、经核实的非缺陷](#四经核实的非缺陷)
- [五、修复优先级建议](#五修复优先级建议)

---

## 一、高严重度（建议立即修复）

### H1. ShellKit：readabilityHandler 未清除时调用 `readDataToEndOfFile` → ObjC 异常崩溃

**位置**：`Packages/ShellKit/Sources/ShellExecutor.swift:430-447`

```swift
process.terminationHandler = { [stdoutPipe, stderrPipe] _ in
    let finalStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()  // handler 仍非 nil
    ...
    stdoutPipe.fileHandleForReading.readabilityHandler = nil   // 先读后清，顺序颠倒
```

**问题**：FileHandle 在 `readabilityHandler` 非 nil 时调用 `readDataToEndOfFile` 会抛出 ObjC 异常（Swift 无法 catch），直接崩溃。且终止回调与 readabilityHandler 并发消费同一管道，输出可能错乱。

**修复**：先把两个 `readabilityHandler` 置 nil 再读残余数据；更好的做法是在 handler 收到 EOF（`availableData.isEmpty`）时统一收尾，彻底去掉 `readDataToEndOfFile`。

---

### H2. EditorSource：NSEvent monitor 闭包强捕获 self → deinit 永不执行，监听器泄漏

**位置**：`Packages/EditorSource/Sources/EditorSource/Find/PanelView/FindPanelHostingView.swift:56-62`

```swift
eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event -> NSEvent? in
    if event.keyCode == 53 {
        self.viewModel?.dismiss?()   // 强捕获 self
```

**问题**：系统持有 monitor 闭包，闭包强持有 self，形成保留环。`deinit { removeEventMonitor() }` 永远不会执行——Esc 键被已"关闭"的查找面板永久拦截，视图泄漏。

**修复**：闭包改用 `[weak self]`。

---

### H3. MCPKit：子进程启动失败后状态未清理，后续 terminate() 触发 ObjC 异常

**位置**：`Packages/MCPKit/Sources/SubprocessTransport.swift:75-92`

```swift
self.process = process          // run() 之前已赋值
do { try process.run() }
catch { throw error }           // 未清理 self.process / self.stdinPipe
```

**问题**：`run()` 抛错后 `self.process` 仍指向未启动的 Process；之后 `disconnect()` 里的 `process?.terminate()` 对未启动进程调用会抛 `NSInvalidArgumentException` 崩溃。`stdinPipe` 不置空，`send()` 会向死管道写入。

**修复**：catch 中将 `self.process = nil; self.stdinPipe = nil` 并 `messageContinuation.finish()`；`disconnect()` 里同样置空 `stdinPipe`。

---

### H4. WebServerKit：启动竞态导致 `start()` 永久挂起

**位置**：`Packages/WebServerKit/Sources/WebServerKit/LumiWebServer.swift:174-199`

```swift
onServerRunning: { channel in
    if let port = channel.localAddress?.port { gate.succeed(withPort: port) }  // 可能先发生
}
...
let actualPort = try await withCheckedThrowingContinuation { continuation in
    gate.arm(continuation)   // 后发生：succeed 已把端口丢掉
}
```

**问题**：`StartGate` 是一次性信号、不缓存结果。若 `onServerRunning` 早于 `gate.arm` 触发，端口被丢弃，`start()` 永久挂起，调用方卡死。若 `onServerRunning` 从未触发同样永久挂起并泄漏 continuation。

**修复**：StartGate 缓存"结果"而非仅 continuation——`succeed/fail` 先存结果，`arm` 时已有结果立即 resume；`runTask` 结束时若 gate 仍空则 `gate.fail(...)` 兜底。

---

### H5. Record Store 兜底 `try! ModelContainer()` 创建无 Schema 的默认容器（5 处复制）

**位置**：
- `Plugins/AgentTurnRunnerPlugin/Sources/AgentTurnRunnerPlugin/Stores/AgentTurnRecordStore.swift:89`
- `Plugins/LLMProviderMiniMaxPlugin/Sources/Services/MiniMaxMusicRecordStore.swift:98`
- `Plugins/LLMProviderMiniMaxPlugin/Sources/Services/MiniMaxImageRecordStore.swift:105`
- `Plugins/LLMProviderMiniMaxPlugin/Sources/Services/MiniMaxVideoRecordStore.swift:90`
- `Plugins/ToolManagerPlugin/Sources/ToolManagerPlugin/Models/ToolCallRecordStore.swift:93`

```swift
container = (try? ModelContainer(for: AgentTurnRecordModel.self)) ?? (try! ModelContainer())
```

**问题**：① `try!` 在磁盘损坏等场景直接崩溃；② 兜底 `ModelContainer()` 是空 Schema + 默认 URL 的容器——后续插入实体必然运行时报错（常被外层 `try?` 吞掉，静默丢数据），且默认 URL 会与其他插件的 `app.sqlite` 冲突。注释声称"回退内存容器"，实际不是（对比 `ActivityHeatmapCache.swift:62` 用 `isStoredInMemoryOnly: true` 才正确）。

**修复**：兜底改为 `try ModelContainer(for: Model.self, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])`，并去掉 `try!`。

---

### H6. DownloadKit：任务取消时底层 URLSession 下载任务并未取消

**位置**：`Packages/DownloadKit/Sources/HTTPClient.swift:113-122`

```swift
try await withTaskCancellationHandler {
    try await session.bytes(for: request)
} onCancel: {
    // 空实现，注释假设取消会自动传播 —— 不成立
}
```

**问题**：外层 Task 取消只会让迭代抛 `CancellationError`，底层 data task 不会被 `cancel()`，下载在后台继续跑完（浪费带宽/流量/电量）。

**修复**：使用返回 `(AsyncBytes, URLSessionTask)` 的 API，在 `onCancel: { task.cancel() }` 中真正取消。

---

### H7. ProjectRAGPlugin：`RAGSQLiteStore` 标注 `@unchecked Sendable` 但 SQLite 句柄跨线程无锁共享

**位置**：`Plugins/ProjectRAGPlugin/Sources/Services/RAGSQLiteStore.swift:8-17`

```swift
final class RAGSQLiteStore: @unchecked Sendable {
    private var db: OpaquePointer?
    package(set) public var runtimeInfo: RAGRuntimeInfo = ...
```

**问题**：`db`、`runtimeInfo` 均为无锁可变状态。后台索引（`RAGService.swift:347` 经 `Task.detached`）与 actor 上的检索并发使用同一连接；`open()` 未设置 `sqlite3_busy_timeout`/WAL，多线程共用同一连接会返回 `SQLITE_MISUSE`/`SQLITE_BUSY` 甚至崩溃。`RAGPluginService.configure` 整体替换 service 时新旧 store 生命期交叠也无隔离；`deinit` 的 `sqlite3_close` 可能与在途查询并发。

**修复**：为整个类加锁（`NSLock`）包住所有 db 访问，或将 store 改为 actor；打开后执行 `sqlite3_busy_timeout(db, 5000)` 与 `PRAGMA journal_mode=WAL`；`deinit` 用 `sqlite3_close_v2`。

---

### H8. ProjectRAGPlugin：`@objc` 通知回调可能在非主线程触发，破坏 MainActor 隔离

**位置**：`Plugins/AppUpdatePlugin/Sources/Services/UpdateService.swift:57-68, 172-183`

```swift
NotificationCenter.default.addObserver(self, selector: #selector(handleCheckForUpdatesRequest), ...)
@objc private func handleCheckForUpdatesRequest() { checkForUpdates() }
```

**问题**：selector 方式注册且未指定 queue，回调线程等于发通知线程。`UpdateService` 是 `@MainActor`，若任何插件在后台线程 post `.checkForUpdates`，Swift 6 运行时会触发 isolation 断言崩溃；即便不崩也会从后台线程操作 Sparkle 的更新窗口（AppKit UI）。

**修复**：改用 block-based observer 并传 `queue: .main`，或 `NotificationCenter.publisher(for:).receive(on: DispatchQueue.main).sink`。

---

### H9. FactoryCore：主线程同步执行外部进程并 `waitUntilExit()`，阻塞 UI

**位置**：`Packages/FactoryCore/Sources/FactoryCore/Bootstrap/MacAgent.swift:79-106`

```swift
try writeDefaults.run()
writeDefaults.waitUntilExit()   // 主线程同步等待
try restartFinder.run()         // killall Finder
```

**问题**：`setFinderShowsHiddenFiles` 由 `application(_:open:)`（主线程）调用。`waitUntilExit()` 同步阻塞主线程直到 `/usr/bin/defaults` 退出；进程卡住时整个应用冻结（沙滩球）。`killall Finder` 副作用也过于剧烈。

**修复**：把 Process 执行放进 `Task.detached` 或后台队列，主线程只更新状态；重启 Finder 可改为 `osascript` 通知刷新等温和方式。

---

### H10. ProjectRAGPlugin：协作线程池内用 RunLoop 忙等轮询进程，最长阻塞 10 秒

**位置**：`Plugins/ProjectRAGPlugin/Sources/Tools/RAGCodeSearchTool.swift:328-336`

```swift
while process.isRunning && Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
}
```

**问题**：在 `async` 调用链（协作线程）上同步自旋等待最多 10 秒。协作线程池线程有限，几个并发的 `search_code` 就会饿死其他任务；后台线程的 `RunLoop` 无 source，行为也不可靠。

**修复**：在 `Task.detached` 中 `await process.waitUntilExit()`，或使用 `readabilityHandler` + `DispatchSemaphore` 异步封装。

---

### H11. MiniMax Provider：`try!` 随用户配置崩溃（3 处）

**位置**：
- `Plugins/LLMProviderMiniMaxPlugin/Sources/Providers/MiniMaxOpenAIProvider.swift:43`
- `Plugins/LLMProviderMiniMaxPlugin/Sources/Providers/MiniMaxAnthropicProvider.swift:37`
- `Plugins/LLMProviderMiniMaxPlugin/Sources/Providers/MiniMaxResponsesProvider.swift:43`

```swift
service = try! MiniMaxOpenAIService(baseURL: baseURL, ...)
```

**问题**：`baseURL` 来自用户设置；一旦填入非法 URL（空串、含空格、非 http scheme），插件构造时直接崩掉整个 App。

**修复**：改为可失败初始化或 `Result`，非法 URL 走 provider 报错路径。

---

## 二、中严重度

### M1. `objectWillChange as! ObservableObjectPublisher` 强转崩溃（3 处）

**位置**：
- `Packages/KernelLumi/Sources/KernelLumi/KernelLumi.swift:92`
- `Plugins/MenuBarManagerPlugin/Sources/MenuBarManagerPlugin.swift:231`
- `Plugins/MenuBarManagerPlugin/Sources/Views/MenuBarLogoView.swift:20`

**问题**：`ObservableObject` 协议允许用 `Subject` 自定义 `objectWillChange`；遇到这种实现强转必崩（`as!` 不可 catch）。

**修复**：改用 `objectWillChange.sink { ... }`（订阅不需要具体 publisher 类型）。

---

### M2. ConversationManager：保存对话数据错误被 `try?` 静默吞掉（数据丢失）

**位置**：`Plugins/ConversationManagerPlugin/Sources/Managers/ConversationManager.swift:761`

```swift
try? data.write(to: fileURL, options: .atomic)
```

**问题**：`persistSelectedConversationID()` 中编码、建目录、写盘三步全部 `try?`。磁盘满/权限失败时用户全部对话静默丢失，无日志无提示。

**修复**：`do/catch` 并记录 `logger.error` + 用户可见提示。

---

### M3. RAGSQLiteStore：`sqlite3_bind_blob` 传入 `SQLITE_STATIC` 但指针仅在闭包内保证有效

**位置**：`Plugins/ProjectRAGPlugin/Sources/Services/RAGSQLiteStore.swift:109-111`（同模式 376-378、700-702）

```swift
_ = embeddingData.withUnsafeBytes { buffer in
    sqlite3_bind_blob(insertStmt, 7, buffer.baseAddress, Int32(embeddingData.count), nil)
}
// sqlite3_step 在闭包外执行
```

**问题**：nil destructor 即 `SQLITE_STATIC`，要求指针在 step 前保持有效；当前依赖实现细节（局部变量恰在作用域），重构即成悬垂指针。embedding 为空时 `baseAddress` 为 nil 会静默绑定 NULL。

**修复**：使用 `SQLITE_TRANSIENT`（`unsafeBitCast(-1, to: UnsafeMutableRawPointer?.self)`）让 SQLite 拷贝数据。

---

### M4. RAG 索引：全量重建先删光旧 chunk，中途取消/崩溃导致索引数据丢失

**位置**：`Plugins/ProjectRAGPlugin/Sources/Services/RAGIndexer.swift:39-44`

```swift
for state in indexedStates.values {
    try store.deleteChunks(projectPath: projectPath, filePath: state.filePath)
    try store.deleteFileState(...)
}
var stats = try indexFiles(...)   // 后台随时抛 CancellationError
```

**问题**：删除与重建不在同一事务中；取消时旧索引已删、新索引只写一半，检索结果残缺且无标记。

**修复**：逐文件"先写新后删旧"（以 file 为单位包事务），或把删除阶段延后到新数据全部写完；至少在取消时标记索引"损坏需重建"。

---

### M5. RAGPluginRuntime：静态强引用 kernel 导致内存泄漏 + 全局可变闭包数据竞争

**位置**：`Plugins/ProjectRAGPlugin/Sources/Core/RAGPluginRuntime.swift:5-11`；写入点 `Hooks/OnReady.swift:24, 37`

```swift
nonisolated(unsafe) public static var databaseDirectoryProvider: @Sendable () -> URL = ...
@MainActor public static var kernel: KernelLumi?
```

**问题**：① `kernel` 静态强引用，内核重建后旧 `KernelLumi` 及整棵服务树永远无法释放；② `databaseDirectoryProvider` 主线程写、任意线程读，`nonisolated(unsafe)` 只是压制告警，实际是数据竞争。

**修复**：`kernel` 改为 `weak`；`databaseDirectoryProvider` 用 `OSAllocatedUnfairLock` 或 configure 时一次性确定为 `let`。

---

### M6. EditorKernel：文件轮询 Timer 无 deinit 清理，闭包强持有回调与 URL

**位置**：`Packages/EditorKernel/Sources/EditorExternalFileController.swift:46-60`

**问题**：类无 `deinit`，Timer 挂在主 RunLoop 永不停止，强持有 `url` 与 `onPoll`（后者通常捕获编辑器状态，形成大对象泄漏）。59 行 `RunLoop.main.add` 对已调度的 Timer 属冗余。

**修复**：添加 `deinit { pollTimer?.invalidate() }`；调度用 `Timer(timeInterval:repeats:block:)` + 手动 add。

---

### M7. DownloadKit：续传以磁盘文件实际末尾拼接，忽略 existingBytes → 文件损坏

**位置**：`Packages/DownloadKit/Sources/HTTPClient.swift:119, 144-146, 199-210`

**问题**：磁盘上部分文件大小与调用方传入的 `existingBytes` 不一致时（写盘失败/外部截断/路径复用），Range 请求从 `existingBytes` 开始下载，数据却追加到磁盘真实末尾——多写或跳写字节，文件损坏且无报错。另外逐字节 `for try await byte` 迭代性能极差。

**修复**：append 前校验磁盘大小，不一致时以磁盘大小为准重发 Range 或改为全量下载；改为按块迭代底层 buffer。

---

### M8. MCPKit：`resolveExecutablePath` 在协作线程上同步阻塞（信号量 + 登录 shell）

**位置**：`Packages/MCPKit/Sources/SubprocessTransport.swift:146-170`

**问题**：在协作线程池线程上执行 `zsh -l -c 'which ...'`（登录 shell 启动可达数百毫秒）并 `semaphore.wait()` 阻塞；多个 MCP 服务器并发连接时耗尽线程池，全局 async 任务饿死。

**修复**：改用 `process.terminationAsync` 或 continuation 包装；或放入 `Task.detached`。

---

### M9. MCPKit：`which \(command)` 拼接进登录 shell → 命令注入

**位置**：`Packages/MCPKit/Sources/SubprocessTransport.swift:151`

```swift
process.arguments = ["-l", "-c", "which \(command)"]
```

**问题**：`command` 来自 MCP 配置（可能来自导入的 JSON/远端配置），含 `;`、`$(...)` 等元字符时会被 zsh 执行。

**修复**：安全转义后拼接，或直接用 `Process` + `environment["PATH"]` 手工逐路径查找（可扩展现有 commonPaths 回退）。

---

### M10. EditorKernel：rg 搜索管道 handler 清理与 EOF 读取竞态

**位置**：`Packages/EditorKernel/Sources/Foundation/EditorWorkspaceSearchController.swift:89-103`

**问题**：(a) `run()` 抛错（rg 未安装）时 readabilityHandler 永不置 nil；(b) `waitUntilExit` 后置 nil handler 时仍可能有在飞调用，与随后的 `readDataToEndOfFile` 并发消费管道，可能丢数据；(c) rg 未安装时报错信息是 env 的 127 而非"rg 不存在"。

**修复**：用 `do/catch + defer` 清理 handler；在 handler 内以 `availableData.isEmpty` 判定 EOF 并 resume continuation。

---

### M11. ComputerUse / TextActions / ScreenRecorder：对外部 API 返回值强制转换

**位置**：
- `Plugins/ComputerUsePlugin/Sources/ComputerUsePlugin/Services/ComputerUseWindowProvider.swift:21`
- `Plugins/ComputerUsePlugin/Sources/ComputerUsePlugin/Services/ComputerUseInputExecutor.swift:153`
- `Plugins/TextActionsPlugin/Sources/TextActionsSettings.swift:136`
- `Plugins/ScreenRecorderPlugin/Sources/ScreenRecorderPlugin/Services/RecordableWindowProvider.swift:57`

**问题**：`boundsValue as! CFDictionary`、`focusedValue as! AXUIElement`——返回类型由外部进程决定，异常窗口（游戏/自绘 app）返回非预期类型直接崩溃，且对每个窗口都执行。

**修复**：`as?` 条件绑定，失败 `return nil`（同函数其他字段已是这么做的）。

---

### M12. ci_pre_xcodebuild.sh：对所有 xcodebuild（含 Archive）全局禁用签名

**位置**：`ci_scripts/ci_pre_xcodebuild.sh:43-45`

**问题**：Xcode Cloud 每次 xcodebuild 前都跑此脚本（包括 Archive/Export），全局 `CODE_SIGNING_ALLOWED=NO` 会导致 TestFlight 归档产物未签名或导出失败（仓库存在 `ci_pre_testflight.sh`，说明确有此流程）。

**修复**：仅在 `CI_XCODEBUILD_ACTION` 为 build/test 时禁用签名，archive 前不注入这些变量。

---

### M13. AppUpdatePlugin：`kernel.network` 为 nil 时自动更新被静默禁用

**位置**：`Plugins/AppUpdatePlugin/Sources/Services/UpdateService.swift:107-109`（配合 `AppUpdatePlugin.swift:40-42`）

**问题**：network 缺失时不 configure → `feedURLDetector` 为 nil → `setupFeedURLIfNeeded` 静默 return，Sparkle 永不启动，自动更新无声失效，无任何日志。

**修复**：detector 为 nil 时回退默认实现（直接 `ensureUpdaterInitialized()`）并打日志。

---

### M14. MacAgent：多文件打开时只保留最后一个路径

**位置**：`Packages/FactoryCore/Sources/FactoryCore/Bootstrap/MacAgent.swift:34-63, 137-149`

**问题**：`pendingOpenPath` 是单槽 `String?`，`application(_:open:)` 传入多 URL（同时拖拽多个项目到 Dock 图标）时前 N-1 个路径被覆盖丢弃。

**修复**：改为 `[String]` 队列，消费端逐个 `requestOpen`。

---

### M15. AvailabilityDiskCache：缓存文件无淘汰，且代码复制了 18 份

**位置**：`Plugins/LLMProvider*Plugin/Sources/{Services,Utilities}/AvailabilityDiskCache.swift`（18 个 LLM Provider 插件各一份）

**问题**：`write` 只增改条目、从不清理过期/下线模型，`availability_cache.json` 无限增长；同一类被复制 18 次，修一处漏十七处。

**修复**：`write` 时剔除超期（如 7 天）条目；长期抽到共享 Package 消除拷贝。

---

### M16. GoalTaskPlugin：`nonisolated(unsafe) static var _sharedManager` 无同步读写

**位置**：`Plugins/GoalTaskPlugin/Sources/Plugin.swift:30, 42-44, 57`

**问题**：`onReady`（@MainActor）写、agent tools 在任意执行器读，无同步——数据竞争（TSan 可报）。

**修复**：用 `NSLock` 保护，或改为 actor 属性。

---

### M17. DownloadKit ResumeHandler：非原子"删旧再移动" + resume data key 不一致

**位置**：`Packages/DownloadKit/Sources/ResumeHandler.swift:82-100`（字典定义在 :6）

**问题**：先删最终文件再移动，移动失败（跨卷 EXDEV 等）时两头全丢；`removeResumeData(for: finalURL)` 与 `saveResumeData`（以下载 URL 为 key）key 不一致，resume data 永远清不掉，内存字典只增不减（resume data 可达数百 KB）。

**修复**：用 `replaceItemAt(_:withItemAt:)` 原子替换；统一以下载 URL 为 key 清理；字典加 LRU 上限。

---

### M18. KeychainKit：用 Thread.sleep 做重试退避，可能阻塞主线程

**位置**：`Packages/KeychainKit/Sources/KeychainStore.swift:22-24, 68-76`

**问题**：`string(forKey:)` 是同步 API 常在主线程调用（读 API key），keychaind 瞬时不可用时累计阻塞主线程 350ms+。`static let shared = KeychainStore(service: "")` 依赖文档约定，误用时静默写空 service。

**修复**：提供 async 版本；主线程路径只尝试一次、失败转后台重试；shared 断言 service 非空。

---

## 三、低严重度

### L1. TaskGroup 结果强制解包

`Plugins/ProjectRAGPlugin/Sources/Services/RAGIndexScheduler.swift:141` —— `try await group.next()!` 依赖隐式约定，应改 `guard let`。

### L2. 调度器吞掉"未初始化"错误伪装成索引失败

`RAGIndexScheduler.swift:115-116` —— `try? ... ?? true` 把 `RAGError.notInitialized` 变成 `needsIndex=true`，后续被记为项目索引失败并退避，误导排查。应区分错误类型并跳过本轮。

### L3. 重试循环 `try? await Task.sleep` 吞掉取消信号

`Plugins/ProjectRAGPlugin/Sources/Hooks/OnReady.swift:96-113` —— 任务取消后循环退化为快速空转。应每轮检查 `Task.isCancelled` 并单独捕获 `CancellationError`。

### L4. snippet() 上下文行 off-by-one

`RAGCodeSearchTool.swift:586-596` —— `end = min(line + contextLines - 1, ...)` 导致匹配行之后少展示一行，前后不对称。应改 `min(line + contextLines, lines.count) - 1`。

### L5. grep 超时 kill 后立即清理，且从不校验退出码

`RAGCodeSearchTool.swift:337-347, 266-273` —— `terminate()` 是异步信号，紧接 close 句柄并删临时目录，输出可能丢失；grep 出错（退出码 2）时部分输出被当完整结果返回。应 wait 后清理、非 0 退出码走 Swift 回退。

### L6. grep 成功路径仍触发整树 Swift 回退扫描

`RAGCodeSearchTool.swift:210-224` —— `--max-count` 是每文件匹配行数，与聚合后的文件数比较，grep 找到的文件数少于 limit 时（常见）会立刻做一次完整目录树扫描。应 grep 成功即视为完成。

### L7. `ensureIndexed` 早退路径仍清空全部检索缓存

`Plugins/ProjectRAGPlugin/Sources/Services/RAGService.swift:169-172, 230-244` —— 节流/未过期提前 return 时 defer 仍 `cache.clear()`，缓存命中率被持续击穿。应只在真实写入索引后清理。

### L8. HostConnection.terminate() 同步 `waitUntilExit()` 阻塞协作线程

`Packages/LumiPreviewKit/Sources/Host/HostConnection.swift:196-207` —— 且超时后无 SIGKILL 兜底。改用 `terminationAsync`，超时后 `kill(pid, SIGKILL)`。

### L9. ci_pre_testflight.sh 只校验 AppIconDesigner 的 Info.plist

`ci_scripts/ci_pre_testflight.sh:41` —— 5 个 App 共用 ci_scripts，但版本校验硬编码只检查一个；第 35 行 `find -newer BUILD_DIR` 以目录自身为基准基本恒为空。应按 `CI_TAG` 前缀分发。

### L10. MLXDownloadManager.fetchSubdirectory 串行深度递归

`Plugins/LLMProviderMLXPlugin/Sources/Services/MLXDownloadManager.swift:661-677` —— 大仓库串行慢且无并发限制、无最大深度保护。改任务组 + 信号量限并发（如 4）。

### L11. 多处写 PNG / 缓存非原子

`Plugins/BrowserPlugin/Sources/BrowserScreenshotTool.swift:233`、`Plugins/ClipboardManagerPlugin/Sources/Services/ClipboardMonitor.swift:171`、`Plugins/EditorPreviewPlugin/Sources/Preview/Views/EditorPreviewDetailView.swift:639`、`DiskManagerPlugin/.../DiskCacheService.swift:63` 等 —— `try pngData.write(to:)` 缺 `options: .atomic`，中途被杀留下半个文件。统一加 `.atomic`。

---

## 四、经核实的非缺陷（避免重复排查）

- `FactoryBookletMaker.swift:15` / `FactoryLumi.swift:19` 的 `try!`：注释明确为编译期固定配置、失败即开发期错误，可接受。
- `ModelUsageStats.swift:225` 的 `first!...last!`：上游有 guard，实际风险极低。
- 各 `rootPath + "/"` 路径前缀判断均处理了 `"/"` 特例，逻辑正确。
- `EditorSource` 各通知观察者（GutterView/MinimapView/TextView 等）均在 `deinit` 中 remove，无泄漏。
- `Config/*.xcconfig` 未发现硬编码密钥；`HttpKit/HTTPClient.swift` 的超时、SSE 解析、敏感头脱敏实现良好；`ConversationService` 落盘使用了 `.atomic`；SQL 访问普遍使用绑定参数，未发现注入。

---

## 五、修复优先级建议

| 优先级 | 编号 | 理由 |
|--------|------|------|
| P0（本周） | H1, H2, H3, H4, H11 | 必然崩溃路径 / 调用方挂死 / 用户输入即崩 |
| P1（近期） | H5, H6, H7, H8, H9, H10 | 数据丢失 / UI 冻结 / 线程池饿死 / 静默失效 |
| P2（规划） | M1–M18 | 特定条件出错、泄漏、注入、CI 风险 |
| P3（顺手修） | L1–L11 | 健壮性与性能隐患 |

另外两个系统性建议：

1. **消除复制粘贴**：`AvailabilityDiskCache`（18 份）、Record Store 兜底模式（5 份）、`objectWillChange` 强转（3 处）都是同一缺陷的多份拷贝，应抽到共享 Package 一次修复。
2. **并发纪律**：多数高严重度问题源于 `@unchecked Sendable` / `nonisolated(unsafe)` / 协作线程阻塞 / 主线程阻塞四类。建议在 CI 引入 TSan（Thread Sanitizer）跑测试套件，可提前暴露 H7、M5、M16 这类数据竞争。
