# 插件体系统一化路线图

## 目标

将当前分散的 **App 插件体系**（`Plugins/` + `SuperPlugin`）与 **编辑器子插件体系**（`Plugins-Editor/` + `EditorFeaturePlugin`）合并为一套统一的 `SuperPlugin` 插件体系。

一个插件只需实现 `SuperPlugin`，即可同时贡献系统 UI（工具栏、状态栏、面板等）和编辑器能力（补全、hover、code action 等）。

## 现状

### 当前三套独立体系

| 体系 | 路径 | 协议 | 管理器 | 发现规则 | 配置存储 |
|------|------|------|--------|----------|----------|
| **App 插件** | `Plugins/` (~80个) | `SuperPlugin` (Actor) | `PluginVM` | `Lumi.*Plugin` | `PluginSettingsVM` |
| **编辑器子插件** | `Plugins-Editor/` (~29个) | `EditorFeaturePlugin` (NSObject class) | `EditorPluginManager` | `*EditorPlugin` | `EditorConfigStore` |
| **LLM 插件** | `Plugins-LLM/` (~12个) | (独立协议) | (独立管理) | 独立 | 独立 |

### 核心问题

1. **双重发现机制**：`PluginVM` 和 `EditorPluginManager` 各自通过 Objective-C Runtime 扫描类
2. **双重配置存储**：App 插件用 `PluginSettingsVM`，Editor 插件用 `EditorConfigStore`
3. **协议不统一**：`SuperPlugin` 是 Actor，`EditorFeaturePlugin` 是 `@objc` NSObject class
4. **能力边界固化**：Editor 子插件无法直接贡献 App 层 UI（如状态栏显示 LSP 连接状态），App 插件也无法注入编辑器扩展点
5. **EditorPlugin 嵌套结构**：`EditorPlugin` 作为 SuperPlugin 持有 `EditorPluginManager`，形成"插件内嵌管理器"的反模式

## 目标架构

```
PluginVM (唯一事实来源)
    │
    ├── 自动发现所有 SuperPlugin (一次扫描)
    ├── 统一维护 isPluginEnabled 状态
    ├── 统一 PluginSettingsVM 配置存储
    │
    └── @EnvironmentObject → EditorRootOverlay
                               │
                               filter { isPluginEnabled && providesEditorExtensions }
                               │
                               EditorPluginManager.install(plugins:)  ← 纯安装器，不维护开关
                               │
                               EditorExtensionRegistry
                               │
                               CodeEditSourceEditor 消费
```

### 设计原则

1. **单一发现**：只有 `PluginVM` 通过 Runtime 扫描发现插件
2. **单一协议**：所有插件实现 `SuperPlugin` Actor
3. **单一配置**：`PluginSettingsVM` 统一管理所有插件开关
4. **Editor 内核不维护开关**：Editor 只负责接收已过滤的插件列表并安装
5. **能力正交**：一个插件可以同时贡献 App UI + Editor 扩展，也可以只贡献其中之一

---

## Phase 1: SuperPlugin 协议扩展

### 目标

在 `SuperPlugin` 上新增编辑器扩展点，使一个插件可以声明并注入编辑器能力。

### 任务

1. 在 `SuperPlugin` 协议中新增 `providesEditorExtensions` 属性（默认 `false`）
2. 在 `SuperPlugin` 协议中新增 `registerEditorExtensions(into:)` 方法（默认空实现）
3. 在 `SuperPlugin+UIView.swift` 中提供默认实现
4. 在 `EditorPluginManager` 中新增 `install(plugins:)` 方法

### 新增 API

```swift
protocol SuperPlugin: Actor {
    // MARK: - Editor Extension Points (新增)
    
    /// 标记该插件是否提供编辑器扩展能力
    nonisolated var providesEditorExtensions: Bool { get }
    
    /// 向编辑器扩展注册中心注入能力
    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry)
}

extension SuperPlugin {
    nonisolated var providesEditorExtensions: Bool { false }
    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {}
}
```

```swift
extension EditorPluginManager {
    /// 安装一组编辑器插件（完全由外部传入，不维护开关）
    func install(plugins: [any SuperPlugin]) {
        // 重置 registry
        // 按 order 排序
        // 调用每个插件的 registerEditorExtensions(into:)
    }
}
```

### 验收

1. `SuperPlugin` 编译通过，现有 App 插件不受影响（默认实现保证向后兼容）
2. `EditorPluginManager.install(plugins:)` 方法可用
3. 新增的扩展点方法在协议文档中有注释说明

### 清单

- [x] `SuperPlugin` 协议新增 `providesEditorExtensions` 和 `registerEditorExtensions`
- [x] 新建 `SuperPlugin+Editor.swift` 提供默认实现
- [x] `EditorPluginManager` 新增 `install(plugins: [any SuperPlugin])` 和 `uninstallAll()` 方法
- [x] `EditorPluginManager` 删除所有旧发现和开关逻辑（`autoDiscoverAndRegisterPlugins`、`register`、`isPluginEnabled`、`setPluginEnabled`、`applyEnabledPlugins`、`createInstance`）
- [x] `EditorPluginManager` 精简为纯安装器（代码减少约 60%）

---

## Phase 2: EditorState 接入 PluginVM ✅

### 目标

Editor 不再自己发现插件，改为从 `PluginVM` 拉取已启用的编辑器插件。

### 任务

1. `EditorRootOverlay` 通过 `@EnvironmentObject var pluginVM: PluginVM` 获取插件列表
2. 在 `onAppear` 中过滤 `isPluginEnabled && providesEditorExtensions` 的插件
3. 调用 `editorPluginManager.install(plugins:)` 安装
4. 监听 `pluginVM.plugins` 变化，自动重新安装
5. 将 `editorPluginManager` 注入环境，供编辑器子视图使用

### 关键代码

```swift
struct EditorRootOverlay<Content: View>: View {
    @EnvironmentObject var pluginVM: PluginVM
    @StateObject private var editorPM = EditorPluginManager()
    let content: Content
    
    var body: some View {
        ZStack { content }
            .onAppear { syncEditorPlugins() }
            .onChange(of: pluginVM.isLoaded) { _ in syncEditorPlugins() }
            .onChange(of: pluginVM.plugins) { _ in syncEditorPlugins() }
            .environmentObject(editorPM)
    }
    
    private func syncEditorPlugins() {
        let editorPlugins = pluginVM.plugins.filter {
            pluginVM.isPluginEnabled($0) && $0.providesEditorExtensions
        }
        editorPM.install(plugins: editorPlugins)
    }
}
```

### 验收

1. `EditorRootOverlay` 编译通过，Editor 子插件正常加载到 `EditorExtensionRegistry`
2. 启/禁用 Editor 插件后，Editor 重新打开时反映新状态
3. 旧 `autoDiscoverAndRegisterPlugins()` 不再被调用（或作为 fallback 保留）

### 清单

- [x] `EditorState` 新增 `installEditorPluginsFromPluginVM()` 替代 `autoDiscoverAndRegisterPlugins()`
- [x] `EditorState.editorFeaturePlugins` 改为从 `editorPluginManager.installedPlugins` 派生
- [x] `EditorState.setEditorFeaturePluginEnabled` 改为调用 `PluginSettingsVM.shared.setPluginEnabled`
- [x] `EditorLoadedPluginsViewModel` 改为从 `PluginVM` 获取已启用的编辑器插件
- [x] 新增 `EditorState.editorExtensions` 和 `editorExtensionResolver` 兼容属性
- [x] 验证：`editorExtensions` 调用链正常工作（SourceEditorViewBridge、HoverCoordinator 等）

---

## Phase 3: 配置存储统一 ✅

### 目标

统一所有插件开关到 `PluginSettingsVM`，废弃 `EditorConfigStore`。

### 任务

1. 确认 `PluginSettingsVM` 的 key 格式能覆盖 Editor 插件的 ID（如 `builtin.css.language-tools`）
2. 在 `PluginSettingsVM` 中增加 Editor 插件的迁移逻辑（从 `EditorConfigStore` 读取旧值）
3. Editor 插件设置 UI 改用 `PluginSettingsVM`
4. 废弃 `EditorConfigStore`（标记 deprecated，保留读取方法用于迁移）

### 验收

1. 用户在设置页启/禁用 Editor 插件，状态持久化到 `PluginSettingsVM`
2. 老用户的 Editor 插件开关设置自动迁移，不丢失
3. `EditorConfigStore` 不再被写入

### 清单

- [x] `PluginSettingsVM` 新增 `migrateEditorConfigIfNeeded()` 一次性迁移逻辑
- [x] `EditorConfigStore` 新增 `loadAllSettings()` 方法支持迁移
- [x] `EditorConfigStore.saveEditorPluginEnabled` 标记 `@deprecated`
- [x] `EditorState.setEditorFeaturePluginEnabled` 已改为调用 `PluginSettingsVM.shared.setPluginEnabled`
- [x] `EditorConfigStore` 保留读取方法（编辑器配置如 fontSize 仍在使用）

---

## Phase 4: EditorPluginManager 精简 ✅

### 目标

`EditorPluginManager` 彻底退化为纯安装器，不再有任何发现/开关逻辑。

### 任务

1. 删除 `autoDiscoverAndRegisterPlugins()`
2. 删除 `isPluginEnabled(_:)`、`setPluginEnabled(_:enabled:)`
3. 删除 `applyEnabledPlugins()`
4. 删除 `createInstance(of:)` Runtime 实例化方法
5. 删除 `discoveredPluginInstances`、`discoveredPluginInfos`（改为只暴露 `installedPlugins`）
6. `PluginInfo` 结构体改为从 `installedPlugins` 派生，或直接从 `PluginVM` 获取

### 验收

1. `EditorPluginManager` 只保留 `install(plugins:)` + `uninstallAll()` + 状态查询
2. 编译通过，Editor 功能正常
3. 代码行数显著下降（删除约 60% 的管理逻辑）

### 清单

- [x] 删除 `autoDiscoverAndRegisterPlugins()`
- [x] 删除 `isPluginEnabled`、`setPluginEnabled`、`applyEnabledPlugins`、`register`
- [x] 删除 `createInstance(of:)` Runtime 实例化
- [x] 删除 `discoveredPluginInstances`、`discoveredPluginInfos`、`plugins: [any EditorFeaturePlugin]`
- [x] 清理 `EditorPluginManager` 对 `EditorConfigStore` 的依赖
- [x] 清理 `EditorLoadedPluginsView` 中旧的 `autoDiscoverAndRegisterPlugins` 调用
- [x] `EditorPluginManager` 从 ~180 行精简到 ~50 行（减少约 70%）
- [x] 不再导入 `ObjectiveC.runtime`

---

## Phase 5: Editor 子插件迁移为 SuperPlugin

### 目标

将 `Plugins-Editor/` 下的所有编辑器子插件从 `EditorFeaturePlugin` 迁移到 `SuperPlugin`。

### 迁移模板

**迁移前：**
```swift
@objc(LumiCSSEditorPlugin)
@MainActor
final class CSSEditorPlugin: NSObject, EditorFeaturePlugin {
    let id = "builtin.css.language-tools"
    let displayName = "CSS Language Tools"
    let order = 32
    func register(into registry: EditorExtensionRegistry) { ... }
}
```

**迁移后：**
```swift
actor CSSEditorPlugin: SuperPlugin {
    static let id = "CSSEditor"
    static let displayName = "CSS Language Tools"
    static let description = "CSS completions and hover help"
    static let iconName = "paintpalette"
    static let order = 32
    static let enable = true
    
    nonisolated var providesEditorExtensions: Bool { true }
    
    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerCompletionContributor(CSSCompletionContributor())
        registry.registerHoverContributor(CSSHoverContributor())
    }
}
```

### 迁移顺序建议

按依赖关系从低到高迁移：

| 批次 | 插件 | 说明 |
|------|------|------|
| **B1** | `CSSEditorPlugin` | 最简单，无外部依赖，验证迁移模板 |
| **B2** | `MarkdownEditorPlugin`、`HTMLEditorPlugin`、`JSEditorPlugin`、`GoEditorPlugin`、`VueEditorPlugin` | 语法高亮类，结构相似 |
| **B3** | `SwiftKeywordHoverEditorPlugin`、`SwiftPrimitiveTypesEditorPlugin`、`SwiftSelectionCodeActionEditorPlugin` | Swift 语言扩展 |
| **B4** | `ChatIntegrationEditorPlugin` | 编辑器与 Chat 集成 |
| **B5** | `MultiCursorCommandsEditorPlugin` | 多光标命令 |
| **B6** | LSP 系列插件（12个） | 批量迁移，结构高度相似 |
| **B7** | `XcodeProjectEditorPlugin` | 最复杂，依赖 Xcode 项目上下文 |

### 验收

1. 所有 `Plugins-Editor/` 下的插件不再继承 `NSObject`，不再使用 `@objc`
2. 所有 Editor 插件实现 `SuperPlugin` 协议
3. `EditorFeaturePlugin` 协议标记 deprecated
4. 编辑器功能（补全、hover、code action、LSP 等）全部正常

### 清单

- [x] B1: `CSSEditorPlugin` 迁移验证
- [x] B2: 语法高亮类插件批量迁移（Markdown, CSS, 语法语言插件）
- [x] B3: Swift 语言扩展插件迁移
- [x] B4: `ChatIntegrationEditorPlugin` 迁移
- [x] B5: `MultiCursorCommandsEditorPlugin` 迁移
- [x] B6: LSP 系列插件迁移（17个）
- [x] B7: `XcodeProjectEditorPlugin` 迁移
- [x] `EditorFeaturePlugin` 协议标记 `@available(*, deprecated)`
- [x] 全量验证：所有 `@objc` 和 `NSObject` 继承已从编辑器插件移除
- [x] 空目录清理（GoEditorPlugin, HTMLEditorPlugin, JSEditorPlugin, VueEditorPlugin）

---

## Phase 6: 目录合并与清理

### 目标

物理结构反映逻辑统一，合并插件目录，清理废弃代码。

### 任务

1. 将 `Plugins-Editor/` 下的插件目录移入 `Plugins/`
2. 将 `Plugins-LLM/` 下的插件目录移入 `Plugins/`（如果 LLM 插件也需要统一）
3. 删除 `Plugins-Editor/` 和 `Plugins-LLM/` 目录
4. 更新 Xcode 项目文件中的文件引用
5. 废弃 `EditorFeaturePlugin` 协议（保留文件但标记 deprecated）
6. 废弃 `EditorConfigStore`（保留文件但标记 deprecated，迁移完成后可删除）
7. 清理所有 `@objc(Lumi...EditorPlugin)` 命名

### 验收

1. `Plugins/` 包含所有类型的插件
2. Xcode 编译通过
3. 运行正常，所有插件功能不受影响

### 清单

- [x] 迁移 `Plugins-Editor/` 到 `Plugins/`（24 个有文件的插件，4 个空目录已删除）
- [x] 迁移 `Plugins-LLM/` 到 `Plugins/`（12 个 LLM 提供商）
- [x] 删除空目录 `Plugins-Editor/`、`Plugins-LLM/`
- [x] `EditorFeaturePlugin` 协议标记 `@available(*, deprecated)`
- [x] `EditorConfigStore.saveEditorPluginEnabled` 标记 `@deprecated`
- [x] 统一 `Plugins/` 目录包含 120 个插件（App + Editor + LLM）

---

## 迁移风险与缓解

| 风险 | 影响 | 缓解策略 |
|------|------|----------|
| Editor 插件从 class → Actor，线程安全变化 | Editor 子插件内部可能依赖 `@MainActor` class 行为 | 编辑器扩展点方法标注 `@MainActor`，内部逻辑不变 |
| `@objc` 移除后 Runtime 扫描失效 | 旧发现机制依赖 `@objc` 类名 | Phase 2 已切换为 `PluginVM` 扫描 `SuperPlugin`，不再依赖 `@objc` |
| 配置迁移丢失 | 用户自定义的 Editor 插件开关丢失 | Phase 3 一次性迁移，读取旧值写入新存储 |
| Xcode 项目文件引用错乱 | 编译失败 | Phase 6 仔细更新 pbxproj，或使用 Xcode 拖拽移动文件 |
| LSP 插件依赖 `EditorPluginManager.shared` | 编译断裂 | 通过 `@EnvironmentObject` 传递，或在 `EditorRootOverlay` 中注入 |

## 总体时间线

```
Phase 1 ──→ Phase 2 ──→ Phase 3 ──→ Phase 4 ──→ Phase 5 ──→ Phase 6
 协议扩展     Editor接入    配置统一     精简管理器    子插件迁移    目录合并
 (向后兼容)  (双轨运行)   (一次性迁移)  (删除代码)   (逐批迁移)   (最终清理)
```

每个 Phase 完成后应保证编译通过、已有功能不受影响，可独立提交。
