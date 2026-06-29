# 主线程并发优化 Roadmap

## 执行摘要

本 Roadmap 围绕"让整个 App 更流畅、所有可后台的操作移出主线程"这一目标，对 Lumi（3267 个真实源文件）做了主线程性能扫描，识别出 **5 个层级、共 9 个具体优化点**。

核心原则：**凡是不需要立即更新 UI 的工作（磁盘 I/O、JSON 解析、内核采样、网络、PNG 编码、正则编译）一律放到后台 `Task.detached` / `Task`；主线程只负责应用结果。**

> 与现有文档的关系：
> - `docs/editor-performance-analysis.md` 关注**编辑器内部**（TreeSitter 解析、Highlighting、布局缓存等）。
> - `docs/memory-growth-audit.md` 关注**内存增长**。
> - 本文档聚焦**主线程并发模型**（轮询、同步 I/O、采样线程归属），三者互补、不重叠。

预期收益：消除全局常驻的菜单栏 1 秒轮询，编辑 Swift 代码时打字更顺滑，打开设备/监视页面不再卡顿。

---

## 改造总览

| 优先级 | 项目 | 影响范围 | 触发频率 | 收益 |
|---|---|---|---|---|
| 🔴 P0 | 菜单栏 1 秒轮询 → 事件驱动 | 全局常驻、所有用户 | 每秒 | 消除持续性主线程负担 |
| 🔴 P0 | LSP 诊断 `.compile` 读取加缓存 | 编辑 Swift 代码 | 每次诊断发布（键入时高频） | 打字流畅度显著提升 |
| 🟠 P1 | `SystemMonitorService` 采样移后台 | 设备/系统监视页面 | 每秒 | 打开页面不再卡 |
| 🟠 P1 | QuickOpen 候选项预归一化 | 文件/符号搜索 | 每次按键 | 大项目搜索更顺 |
| 🟠 P1 | Find References 行读取缓存 | 查找引用 | 每个结果位置 | N 个结果不再 N 次全量读 |
| 🟡 P2 | 进程网络图标预取移后台 | 进程网络列表 | 每 0.2s 突发 | 列表滚动更顺 |
| 🟡 P2 | Cmd+Click 正则编译缓存 | 跳转定义回退路径 | 每次跳转 | 减少正则编译开销 |
| 🟢 P3 | 快捷键保存写盘移后台 | 改快捷键 | 用户改键时 | 清理主线程 I/O |
| 🟢 P3 | 文档打开/历史加载移后台 | 开文件/启动 | 开文件、插件加载 | 观感更顺滑 |

---

## Phase 0：通用约定与验收标准

### 后台化改造模板

凡是采样类、I/O 类工作，遵循同一模式（已在同插件的 `CPUService` 中验证可行）：

```swift
// ✅ 正确模式（CPUService.swift:79 已在用）
private func updateCPUUsage() {
    guard samplingTask == nil else { return }
    let previousTicks = previousTicks

    samplingTask = Task.detached(priority: .utility) { [previousTicks] in
        let snapshot = Self.calculateCPUSnapshot(previousTicks: previousTicks)  // 重活在后台
        await MainActor.run { [weak self] in                                    // 主线程只赋值 @Published
            guard let self else { return }
            self.samplingTask = nil
            self.cpuUsage = snapshot.totalUsage
            // ...
        }
    }
}
```

### 验收标准

- [ ] 所有 P0/P1 项改造后，用 Instruments Time Profiler 复测，主线程采样占比显著下降。
- [ ] 改造不改变任何对外行为（数据值、刷新频率、UI 表现一致）。
- [ ] 每项配最小化单元测试（采样值正确性、缓存命中/失效、后台 Task 可取消）。
- [ ] 新增的后台 Task 在视图/服务销毁时正确取消，避免泄漏（参考 `CPUService.stopMonitoring`）。

---

## Phase 1（P0）：最高收益项

### 1.1 菜单栏 1 秒轮询改为事件驱动

**位置**：`LumiApp/Services/MenuBarService.swift:184-193`

**现状问题**

```swift
private let contentRefreshInterval: TimeInterval = 1.0   // 每秒

private func startContentTimer() {
    let timer = DispatchSource.makeTimerSource(queue: .main)   // 主线程
    timer.schedule(deadline: .now() + contentRefreshInterval, repeating: contentRefreshInterval)
    timer.setEventHandler { [weak self] in
        self?.replaceMenuBarContent()   // ← 每秒重建整个 SwiftUI 视图树
    }
    timer.activate()
    contentTimer = timer
}
```

- `contentTimer` 在 `RootContainer`（应用启动即创建的单例）初始化时启动，**永不停止**（无任何 `invalidate` 逻辑）。
- 每秒 `replaceMenuBarContent()`：重新调用所有插件 `menuBarContentItems(context:)`、重建 `MenuBarIconView`、`hostingView.layoutSubtreeIfNeeded()` + `fittingSize`（强制同步布局）、更新 `statusItem.length`。
- 反复触发 `AppUpdateStatusBarStore.shared.start()` 等 side effect。
- **这是所有用户、整个运行期间都在付出的主线程成本，是本次最大收益项。**

**优化方案**

- [ ] 方案 A（首选）：改为**事件驱动**。各插件内容已是 `ObservableObject` + `@Published`，用 Combine 订阅数据变化，变化时才刷新；取消 1 秒定时器。
- [ ] 方案 B（过渡）：保留轮询但降损——把"采集数据"放 `Task.detached`，主线程只 apply；用 `Equatable` diff 判断内容是否真变化，无变化跳过重建。
- [ ] `layoutSubtreeIfNeeded()` + `fittingSize` 降频（3-5 秒一次，或仅在内容变化时）。
- [ ] 移除 `makeView` 闭包内的 side effect（如 `store.start()` 应在插件激活时调用一次）。

**预期效果**：持续性的每秒主线程负担基本消除，空闲时主线程接近零负担。

---

### 1.2 LSP 诊断 `.compile` 读取加缓存

**位置**：`Packages/EditorService/Sources/LSP/LSPDiagnosticBuildContextPolicy.swift:49-60`，调用方 `LSPService.swift:1245-1263`

**现状问题**

```swift
// handlePublishDiagnostics 跑在 Task { @MainActor } 里（LSPService.swift:203-207）
let knownModuleNames = readyBuildServerPath.map {
    LSPDiagnosticBuildContextPolicy.knownModuleNames(inCompileDatabaseForBuildServerPath: $0)
} ?? []

// 内部：每次都同步读盘 + 全量 JSON 反序列化
guard let data = try? Data(contentsOf: URL(fileURLWithPath: compileDatabasePath)),
      let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { ... }
```

- LSP 服务器在**用户键入时频繁重发诊断**，每次都触发主线程同步磁盘读取 + JSON 解析。
- 结果每次完全相同（`.compile` 不会因键入而变），属于纯重复计算。
- 直接拖慢 Swift 项目的代码编辑流畅度。

**优化方案**

- [ ] 按 `buildServerPath` + `.compile` 文件 `mtime` 做内存缓存（mtime 未变即命中缓存）。
- [ ] 或把读取/解析移到后台 `Task`，回主线程后再执行 `filteredDiagnostics`。
- [ ] 缓存需在项目切换 / `buildServerPath` 变化时失效。

**预期效果**：编辑 Swift 代码时打字流畅度显著提升，重复的磁盘 I/O 与 JSON 解析归零。

---

## Phase 2（P1）：按需页面的卡顿

> 这些是 `@StateObject`，打开对应页面才激活，但一旦打开就持续卡顿。修复样板就是同插件的 `CPUService`（已正确异步）。

### 2.1 `SystemMonitorService` 采样移后台

**位置**：`Plugins/DeviceInfoPlugin/Sources/Services/SystemMonitorService.swift:156-160, 208-325`

**现状问题**：`updateMetrics()` 在 MainActor 上直接调用 `getCPUUsage()`（`host_processor_info` + 遍历所有核 + `vm_deallocate`）、`getMemoryUsage()`（`host_statistics64`）、`getNetworkUsage()`（`getifaddrs` 遍历所有网卡）。只有磁盘采样被放到了后台（`scheduleDiskCountersUpdateIfNeeded`），其余三个内核调用留在主线程。

**优化方案**

- [ ] 把 `getCPUUsage` / `getMemoryUsage` / `getNetworkUsage` 的**采集**移入 `Task.detached(priority: .utility)`，主线程只更新 `@Published` 的历史缓冲与 `currentMetrics`。
- [ ] 注意 `state.prevCpuInfo`、`prevNetworkIn/Out` 等跨采样状态需正确跨后台 Task 传递（参考 `CPUService` 用 `previousTicks` 闭包捕获的方式）。
- [ ] `startMonitoring` / `stopMonitoring` 的引用计数与 `samplingTask` 取消逻辑保持不变。

**预期效果**：打开系统监视页面时主线程不再每秒被内核采样阻塞。

---

### 2.3 QuickOpen 候选项预归一化

**位置**：`Packages/EditorService/Sources/Kernel/EditorQuickOpenController.swift:108-112`

**现状问题**

```swift
let filteredSymbols = flattenedSymbols.filter { item in
    return item.name.lowercased().contains(normalizedSearch)        // 每项每次按键都分配新串
        || item.id.lowercased().contains(normalizedSearch)
        || (item.detail?.lowercased().contains(normalizedSearch) ?? false)
}
```

- 候选项加载时未预归一化，每个候选的 `name`/`id`/`detail` 每次按键都重新 `lowercased()`（堆分配）。大项目下 O(n) 临时分配/按键。

**优化方案**

- [ ] 候选列表加载时预计算并缓存每个项的小写形式（或 `CaseInsensitiveComparator`）。
- [ ] 文件搜索 filter（`EditorQuickOpenFilePolicy`）同改。

**预期效果**：大项目下文件/符号搜索减少按键延迟与 GC 压力。

---

### 2.4 Find References 行读取缓存

**位置**：`Packages/EditorService/Sources/Kernel/EditorLSPActionController.swift:51-57`、`Sources/Editor/JumpToDefinitionDelegate.swift:803-810`

**现状问题**

```swift
guard let content = try? EditorTextFileReader.read(url) else { return nil }  // String(contentsOf:) 整个文件
let lines = content.components(separatedBy: .newlines)                        // 整个文件 split
return lines[lineNumber - 1]...                                               // 只为取一行
```

- Find References 有 N 个结果就 N 次全量同步读 + 全文 split，全部在主线程。

**优化方案**

- [ ] 按 URL + mtime 缓存"已解析的行数组"；或按字节范围只读所需行。
- [ ] 读取与解析移到后台 `Task`，主线程只展示。

**预期效果**：查找引用结果较多时不再阻塞主线程。

---

## Phase 3（P2）：中频热点

### 3.1 进程网络图标预取移后台

**位置**：`Plugins/NetworkManagerPlugin/Sources/ProcessNetworkMonitor/ProcessMonitorService.swift:214-218`

**现状问题**：nettop 每批数据汇总时，对每个新 PID 在主线程调 `NSRunningApplication(processIdentifier:)?.icon`，0.2s 一次突发。

**优化方案**

- [ ] 图标预取移到后台队列，主线程只读 `processDetails` 缓存。

**预期效果**：进程网络列表滚动更顺滑。

---

### 3.2 Cmd+Click 正则编译缓存

**位置**：`Packages/EditorService/Sources/Editor/JumpToDefinitionDelegate.swift:683-717`

**现状问题**：跳转定义回退路径每次重新编译 5 个 `NSRegularExpression`；其中 3 个与用户输入无关，可静态化。

**优化方案**

- [ ] 与用户输入无关的 3 个 pattern 提为 `static let` 编译一次；含 `escapedWord` 的 2 个保留即时编译。
- [ ] 可对 `escapedWord` 维护小规模 LRU 缓存。

**预期效果**：跳转定义响应更快，减少正则编译开销。

---

## Phase 4（P3）：低频主线程 I/O 清理

> 多为用户操作触发，频率低，但都是"可后台就后台"的明确候选，建议一并清理以保持并发模型一致性。

| 位置 | 问题 | 处理 |
|---|---|---|
| `Packages/EditorService/Sources/Kernel/EditorDocumentController.swift:167` | 打开文档同步 `String(contentsOf:)` | 大文件读取移后台（小文件保留） |
| `Plugins/NetworkManagerPlugin/Sources/Services/NetworkHistoryService.swift:203-217` | 启动时同步读 + 解析最多 43200 个数据点 | 解码移后台，UI 先展示空态再回填 |
| `LumiApp/Services/PluginSettingsStore.swift:23` / `LumiUIService.swift:86` | 切换插件/主题时同步 plist 读写 | 写盘进后台 `Task` |

**预期效果**：整体观感更顺滑，并发模型统一。

---

## 验证清单（Instruments）

改造完成后建议按下列场景用 Time Profiler / Main Thread Checker 复测：

- [ ] **空闲态**：App 启动后不操作，观察主线程是否接近空闲（验证 1.1）。
- [ ] **编辑 Swift 代码**：持续键入，观察主线程是否被 `.compile` 读取占用（验证 1.2）。
- [ ] **设备信息页 / 系统监视页**：打开后观察主线程是否被内核采样占用（验证 2.1）。
- [ ] **文件/符号搜索**：大项目下连续输入，观察按键延迟（验证 2.3）。
- [ ] **查找引用**：多结果场景观察主线程（验证 2.4）。
- [ ] **进程网络列表**：观察偶发卡顿是否消除（验证 3.1）。

---

## 实施建议

1. **P0 两项可并行、独立交付**：菜单栏轮询改造（LumiApp 层）与 LSP 诊断缓存（EditorService 层）互不影响，建议优先做，收益最大、风险可控。
2. **P1 一组对照样板改**：`SystemMonitorService` 直接照搬同插件 `CPUService` 的 `Task.detached` 模式，改动小、模式成熟。
3. **每项配回归测试**：尤其采样类，需断言"采样值正确"与"采样在后台线程执行"两点，避免后续回归。
4. **后台 Task 生命周期**：所有新增后台 Task 必须在对应服务/视图停止时取消，纳入 `stopMonitoring` / `deinit` 流程，避免泄漏。
