# EditorXcodePlugin 后台线程改造 TODO

> 目标：确保 `LumiApp/Plugins/EditorXcodePlugin` 及其依赖的 `Packages/XcodeKit` 中，项目解析、文件系统 I/O、外部进程调用、build context 生成等耗时操作尽量在后台线程执行；MainActor 仅负责 UI 状态发布和 SwiftUI 视图更新。

## 背景

当前 `EditorXcodePlugin` 中部分补全、Hover、Quick Open 逻辑已经通过 `Task.detached` 后台化，但仍存在多处主线程占用风险。主要原因是 XcodeKit 核心服务被整体 `@MainActor` 标记，导致文件系统扫描、`xcodebuild`、`xcode-build-server`、pbxproj 解析、target 文件匹配等逻辑容易在主线程执行。

重点涉及路径：

- `LumiApp/Plugins/EditorXcodePlugin`
- `Packages/XcodeKit/Sources/XcodeKit`

---

## 当前进度

- 已完成：`XcodeBuildContextProvider` 初始化时的 `xcode-build-server` 查找后台化。
- 已完成：`XcodeProjectResolver.resolve()` 中的 pbxproj 解析和 target 文件枚举后台化。
- 已完成：`XcodeProjectContextBridge` 的项目识别、workspace 查找、buildServer 校验后台化。
- 已完成：最近项目预加载扫描后台化。
- 已完成：capability 同步接口增加项目类型缓存，优先读取 Bridge 的已解析状态。
- 已完成：`filePath -> matchedTargets` 缓存，减少状态栏/语义检查的重复 target 遍历。
- 已完成：状态栏语义检查基于 `XcodeEditorContextSnapshot` 做 debounce，避免通知风暴和主线程 target 重查询。
- 已完成：移除 `XcodeProjectResolver` 整体 `@MainActor` 隔离，让无状态解析器可从后台调用。
- 已完成：capability 判断使用共享项目类型缓存；同步协议暂不改 async，避免扩散修改 EditorService 注册链路。
- 已完成：生产默认关闭 Xcode 插件、build context、resolver verbose 日志。
- 已完成：评估是否拆出完整 `XcodeProjectBackgroundResolver`；当前 resolver 已无状态、无 MainActor 隔离，暂不新增一层类型。

## P0：高优先级任务

### 1. 异步化 `XcodeBuildContextProvider` 的工具查找逻辑

**文件：**

- `Packages/XcodeKit/Sources/XcodeKit/Services/XcodeBuildContextProvider.swift`

**问题：**

`XcodeBuildContextProvider.init` 中同步调用：

```swift
locateXcodeBuildServer()
```

而 `locateXcodeBuildServer()` 内部可能调用：

```swift
process.waitUntilExit()
```

这会在 provider 初始化时阻塞 MainActor。

**TODO：**

- [x] 不要在 `init` 中同步执行 `locateXcodeBuildServer()`。
- [x] 将 `which xcode-build-server` 调用迁移到后台任务。
- [x] 只在 MainActor 上写回 `xcodeBuildServerPath`。
- [x] 确认插件注册期间不会触发阻塞式进程等待。

**建议方案：**

```swift
public init(...) {
    self.resolver = resolver
    self.store = store
    Task {
        let path = await XcodeToolLocator.locateXcodeBuildServer()
        await MainActor.run {
            self.xcodeBuildServerPath = path
        }
    }
}
```

---

### 2. 将 Xcode 项目解析和文件枚举移出 MainActor

**文件：**

- `Packages/XcodeKit/Sources/XcodeKit/Services/XcodeProjectResolver.swift`

**问题：**

`XcodeProjectResolver` 整体是：

```swift
@MainActor
final public class XcodeProjectResolver
```

其中 `resolveTargetSourceFiles` 会解析 pbxproj 并递归枚举文件：

```swift
XcodePBXProjParser.parseMembershipGraph(projectURL: projectURL)
FileManager.default.enumerator(...)
```

大项目下会明显占用主线程。

**TODO：**

- [x] 移除 `XcodeProjectResolver` 整体 `@MainActor` 标记，或拆出后台 resolver。
- [x] 将 `resolve(workspaceURL:)` 中的 pbxproj 解析、目录枚举放到后台 actor / detached task。
- [x] 将 `findWorkspace`、`isXcodeProjectRoot` 设计为可后台调用的纯 I/O helper。
- [x] 检查调用方是否依赖 MainActor 隔离。

**建议方案：**

```swift
actor XcodeProjectBackgroundResolver {
    func resolve(workspaceURL: URL) async -> XcodeWorkspaceContext? {
        // xcodebuild + pbxproj parse + file enumeration
    }

    func findWorkspace(in directory: URL) -> URL? {
        // FileManager contentsOfDirectory
    }
}
```

---

### 3. 改造 `XcodeProjectContextBridge`：MainActor 只管状态，I/O 放后台

**文件：**

- `Packages/XcodeKit/Sources/XcodeKit/Bridge/XcodeProjectContextBridge.swift`

**问题：**

`XcodeProjectContextBridge` 是 `@MainActor`，但其中包含同步 I/O：

```swift
XcodeProjectResolver.isXcodeProjectRoot(projectURL)
XcodeProjectResolver.findWorkspace(in: projectURL)
provider.store.validate(forWorkspace: workspaceURL.path)
```

这些逻辑出现在：

- `projectOpened(at:)`
- `resyncBuildContext()`
- `initializeXcodeBuildContext(at:)`
- `isBuildServerValid(at:)`
- `updateCacheNow()` / `makeWorkspaceFoldersInternal()`

**TODO：**

- [x] 保留 Bridge 为 MainActor 状态协调器。
- [x] 将项目类型判断、workspace 查找、buildServer 校验迁移到后台 helper。
- [x] `projectOpened` 中只在 MainActor 上设置 `isXcodeProject`、`isInitialized`、`cachedState` 等状态。
- [x] `makeWorkspaceFoldersInternal()` 避免每次同步查找 workspace，可使用预先缓存的 workspace path。

---

### 4. 修复状态栏 ViewModel 的 MainActor 重任务

**文件：**

- `LumiApp/Plugins/EditorXcodePlugin/ViewModels/XcodeProjectStatusBarViewModel.swift`

**问题：**

`XcodeProjectStatusBarViewModel` 整体是 `@MainActor`，但会在主线程频繁执行：

```swift
XcodeSemanticAvailability.inspectCurrentFileContext(...)
```

`resyncBuildContext` 还将整个任务钉到 MainActor：

```swift
Task { @MainActor [weak self] in
    await XcodeProjectContextBridge.shared.resyncBuildContext()
    ...
}
```

**TODO：**

- [x] 不要用 `Task { @MainActor ... }` 包住整个 resync 流程。
- [x] 只在修改 `@Published` 属性时回到 MainActor。
- [x] 语义检查尽量使用快照数据或后台 inspector。
- [x] 对 project context / snapshot 通知增加 debounce，减少重复计算。

**建议：**

```swift
Task { [weak self] in
    await XcodeProjectContextBridge.shared.resyncBuildContext()
    let report = await XcodeSemanticInspector.inspect(...)
    await MainActor.run {
        self?.semanticReport = report
        self?.isResyncingBuildContext = false
    }
}
```

---

## P1：中优先级任务

### 5. 后台化最近 Xcode 项目预加载扫描

**文件：**

- `LumiApp/Plugins/EditorXcodePlugin/Views/EditorXcodePluginRootView.swift`

**问题：**

`EditorXcodePluginRootView` 是 `@MainActor`，但预加载逻辑中同步扫描最近项目：

```swift
let xcodeProjects = recentProjects.filter { project in
    XcodeProjectResolver.isXcodeProjectRoot(URL(filePath: project.path))
}
```

**TODO：**

- [x] `projectVM.getRecentProjects()` 可保留 MainActor。
- [x] 对最近项目执行 Xcode 项目判断时，放到后台线程。
- [x] `preloadProject` 中的 `findWorkspace`、`store.validate` 也应后台化。
- [x] 将 `preloadProject`、`generateBuildServer`、`fetchAvailableSchemes` 标记为 `nonisolated static` 或迁移到专门后台工具类型。

---

### 6. 优化 `XcodeEditorCapabilities` 的同步 I/O

**文件：**

- `LumiApp/Plugins/EditorXcodePlugin/Services/XcodeEditorCapabilities.swift`

**问题：**

以下方法在 MainActor 上同步判断 Xcode 项目：

```swift
func canHandleProject(at path: String?) -> Bool
func supports(languageId: String, projectPath: String?) -> Bool
```

内部调用：

```swift
XcodeProjectResolver.isXcodeProjectRoot(...)
```

**TODO：**

- [x] 优先考虑将接口改为 async。
- [x] 如果协议限制必须同步，增加缓存，避免频繁 FileManager I/O。
- [x] 在项目打开阶段预计算 `isXcodeProject`，后续能力判断直接读缓存。

---

### 7. 缓存 target 文件匹配结果

**文件：**

- `Packages/XcodeKit/Sources/XcodeKit/Services/XcodeBuildContextProvider.swift`
- `Packages/XcodeKit/Sources/XcodeKit/Services/XcodeSemanticAvailability.swift`
- `Packages/XcodeKit/Sources/XcodeKit/Bridge/XcodeProjectContextBridge.swift`

**问题：**

状态栏、语义可用性检查、snapshot 创建会调用：

```swift
findTargetsForFile(fileURL:)
resolvePreferredTarget(for:)
targetsCompatibleWithActiveScheme(for:)
```

每次都可能遍历 workspace targets。

**TODO：**

- [x] 为 `filePath -> matchedTargets` 增加缓存。
- [x] scheme/configuration 切换或项目重解析时清空缓存。
- [x] snapshot 创建尽量使用缓存结果。
- [x] 语义检查尽量基于快照，不直接访问 provider 的重查询。

---

## P2：低优先级和清理任务

### 8. 评估 Contributors 的 MainActor 标记

**文件：**

- `LumiApp/Plugins/EditorXcodePlugin/Contributors/XcodePlistHoverContributor.swift`
- `LumiApp/Plugins/EditorXcodePlugin/Contributors/XcodePackageManifestHoverContributor.swift`
- `LumiApp/Plugins/EditorXcodePlugin/Contributors/XcodePlistCompletionContributor.swift`
- `LumiApp/Plugins/EditorXcodePlugin/Contributors/XcodeProjectQuickOpenContributor.swift`

**现状：**

文本解析和文件枚举大多已通过 `Task.detached` 后台化。

**TODO：**

- [x] 确认 `SuperEditorRuntimeContext.shared.currentContent` 是否为纯内存读取。
- [x] 如果 `currentContent` 可能同步访问文件或编辑器，应改为异步快照读取。
- [x] 对 `provideHover` / `provideSuggestions` 前置逻辑做轻量化。
- [x] 保留 UI suggestion 构造和 action 闭包在 MainActor。

---

### 9. 减少 verbose 日志在高频路径上的开销

**涉及文件：**

- `LumiApp/Plugins/EditorXcodePlugin/**/*`
- `Packages/XcodeKit/Sources/XcodeKit/**/*`

**问题：**

当前多处高频路径都有详细日志，例如 completion、hover、状态通知、semantic inspect。

**TODO：**

- [x] 高频路径日志改为 debug 级别或增加采样。
- [x] 避免在日志字符串中做重计算。
- [x] 生产环境默认关闭 `XcodePluginLog.verbose` / `XcodeBuildContextProvider.verbose` / `XcodeProjectResolver.verbose`。

---

## 验收标准

- [ ] 打开大型 Xcode 项目时 UI 不明显卡顿。
- [x] 插件注册阶段不会阻塞主线程等待 `which` 或其他外部进程。
- [x] 最近项目预加载不会造成启动后 UI 卡顿。
- [x] 状态栏更新、snapshot 变更不会频繁触发主线程 target 遍历。
- [x] `xcodebuild -list`、`xcodebuild -showBuildSettings`、`xcode-build-server config` 都通过异步后台流程执行。
- [x] MainActor 主要只负责：`@Published` 状态更新、SwiftUI 视图构造、UI action。

---

## 建议执行顺序

1. 修复 `XcodeBuildContextProvider.init` 中的同步 `which`。
2. 拆分 `XcodeProjectResolver`，将项目解析和文件枚举后台化。
3. 改造 `XcodeProjectContextBridge`，避免主线程 I/O。
4. 改造 `XcodeProjectStatusBarViewModel.resyncBuildContext` 和通知回调。
5. 后台化最近项目预加载扫描。
6. 为 capability 判断和 target 匹配增加缓存。
7. 清理高频日志和 contributor 前置逻辑。
