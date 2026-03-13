# Issue #17: 插件热重载可能导致状态不一致

**严重程度**: 🟡 Medium  
**状态**: Open  
**文件**: 插件系统相关文件

---

## 问题描述

当前插件系统可能支持热重载，但在重载过程中可能导致状态不一致或资源泄漏。

---

## 问题分析

### 1. 插件生命周期管理

```swift
// 当前可能的实现
class Plugin {
    init() {
        // 初始化资源
        Task {
            // 启动后台任务
        }
    }
}

// 问题：
// - 没有明确的 cleanup 方法
// - 后台任务可能继续运行
// - 注册的回调没有清理
```

### 2. 状态迁移问题

```swift
// 插件重载时
let oldPlugin = currentPlugin
let newPlugin = loadPlugin()

// 问题：
// - oldPlugin 的状态如何迁移到 newPlugin？
// - 迁移过程中的状态一致性？
```

### 3. 依赖关系处理

```swift
// 插件 A 依赖插件 B
PluginA -> PluginB

// 重载插件 B 时
// - 插件 A 是否需要重新初始化？
// - 插件 A 如何知道依赖更新了？
```

---

## 建议修复

### 1. 定义完整的插件生命周期

```swift
/// 插件生命周期协议
protocol PluginLifecycle: AnyObject {
    /// 插件标识
    var id: String { get }
    var version: String { get }
    
    /// 初始化（首次加载）
    func initialize(context: PluginContext) async throws
    
    /// 激活（启用）
    func activate() async throws
    
    /// 停用（禁用）
    func deactivate() async throws
    
    /// 挂起（准备重载）
    func suspend() async throws
    
    /// 恢复（重载后恢复）
    func resume() async throws
    
    /// 清理（卸载）
    func cleanup() async throws
    
    /// 状态迁移
    func migrateState(to newPlugin: any PluginLifecycle) async throws
    
    /// 导出状态（用于持久化或迁移）
    func exportState() async -> PluginState?
    
    /// 导入状态
    func importState(_ state: PluginState) async throws
}

/// 插件状态
struct PluginState: Codable {
    let version: String
    let data: Data
    let exportedAt: Date
}
```

### 2. 插件管理器

```swift
/// 插件管理器
actor PluginManager {
    private var plugins: [String: any PluginLifecycle] = [:]
    private var pluginStates: [String: PluginState] = [:]
    private var dependencyGraph: [String: Set<String>] = [:]
    
    /// 加载插件
    func loadPlugin(_ plugin: any PluginLifecycle) async throws {
        let id = plugin.id
        
        // 检查是否已加载
        if let existing = plugins[id] {
            throw PluginError.alreadyLoaded(id)
        }
        
        // 检查依赖
        try await checkDependencies(for: plugin)
        
        // 初始化
        try await plugin.initialize(context: createPluginContext())
        
        // 恢复之前的状态（如果有）
        if let state = pluginStates[id] {
            try await plugin.importState(state)
        }
        
        // 激活
        try await plugin.activate()
        
        plugins[id] = plugin
    }
    
    /// 重载插件
    func reloadPlugin(id: String) async throws {
        guard let oldPlugin = plugins[id] else {
            throw PluginError.notFound(id)
        }
        
        // 1. 导出当前状态
        let state = await oldPlugin.exportState()
        if let state = state {
            pluginStates[id] = state
        }
        
        // 2. 挂起旧插件
        try await oldPlugin.suspend()
        
        // 3. 找到依赖此插件的其他插件
        let dependents = findDependents(of: id)
        
        // 4. 挂起依赖插件
        for dependentId in dependents {
            if let dependent = plugins[dependentId] {
                try await dependent.suspend()
            }
        }
        
        // 5. 加载新版本
        let newPlugin = try await loadNewPluginVersion(id: id)
        
        // 6. 迁移状态
        try await oldPlugin.migrateState(to: newPlugin)
        
        // 7. 清理旧插件
        try await oldPlugin.cleanup()
        
        // 8. 注册新插件
        plugins[id] = newPlugin
        
        // 9. 恢复新插件
        try await newPlugin.resume()
        
        // 10. 恢复依赖插件
        for dependentId in dependents {
            if let dependent = plugins[dependentId] {
                try await dependent.resume()
            }
        }
    }
    
    /// 卸载插件
    func unloadPlugin(id: String) async throws {
        guard let plugin = plugins[id] else {
            throw PluginError.notFound(id)
        }
        
        // 检查是否有其他插件依赖
        let dependents = findDependents(of: id)
        if !dependents.isEmpty {
            throw PluginError.hasDependents(id, dependents)
        }
        
        // 导出状态
        if let state = await plugin.exportState() {
            pluginStates[id] = state
        }
        
        // 停用并清理
        try await plugin.deactivate()
        try await plugin.cleanup()
        
        plugins.removeValue(forKey: id)
    }
    
    /// 查找依赖者
    private func findDependents(of pluginId: String) -> Set<String> {
        var dependents: Set<String> = []
        
        for (id, dependencies) in dependencyGraph {
            if dependencies.contains(pluginId) {
                dependents.insert(id)
            }
        }
        
        return dependents
    }
}
```

### 3. 插件重载协调器

```swift
/// 插件重载协调器
class PluginReloadCoordinator {
    let pluginManager: PluginManager
    
    /// 重载过程状态
    enum ReloadState {
        case idle
        case preparing
        case exporting
        case suspending
        case loading
        case migrating
        case resuming
        case completed
        case failed(Error)
    }
    
    @Published var state: ReloadState = .idle
    @Published var progress: Double = 0
    
    /// 执行重载
    func reload(pluginId: String) async throws {
        await updateState(.preparing, progress: 0.0)
        
        do {
            // 验证
            await updateState(.preparing, progress: 0.1)
            
            // 导出状态
            await updateState(.exporting, progress: 0.2)
            
            // 挂起
            await updateState(.suspending, progress: 0.3)
            
            // 加载新版本
            await updateState(.loading, progress: 0.5)
            
            // 迁移状态
            await updateState(.migrating, progress: 0.7)
            
            // 恢复
            await updateState(.resuming, progress: 0.9)
            
            try await pluginManager.reloadPlugin(id: pluginId)
            
            await updateState(.completed, progress: 1.0)
        } catch {
            await updateState(.failed(error), progress: 0)
            throw error
        }
    }
    
    @MainActor
    private func updateState(_ state: ReloadState, progress: Double) {
        self.state = state
        self.progress = progress
    }
}
```

### 4. 状态迁移策略

```swift
/// 状态迁移策略
protocol StateMigrationStrategy {
    func migrate(
        from oldVersion: String,
        to newVersion: String,
        state: PluginState
    ) async throws -> PluginState
}

/// 默认迁移策略
class DefaultMigrationStrategy: StateMigrationStrategy {
    func migrate(
        from oldVersion: String,
        to newVersion: String,
        state: PluginState
    ) async throws -> PluginState {
        // 版本相同，直接返回
        guard oldVersion != newVersion else {
            return state
        }
        
        // 解析版本号
        let oldParts = oldVersion.split(separator: ".").map { Int($0) ?? 0 }
        let newParts = newVersion.split(separator: ".").map { Int($0) ?? 0 }
        
        // 主版本号不同，需要完全迁移
        if oldParts[0] != newParts[0] {
            throw MigrationError.incompatibleVersions(oldVersion, newVersion)
        }
        
        // 次版本号不同，需要部分迁移
        if oldParts.count >= 2 && newParts.count >= 2 && oldParts[1] != newParts[1] {
            return try await partialMigrate(state: state, from: oldVersion, to: newVersion)
        }
        
        // 补丁版本号不同，直接兼容
        return state
    }
    
    private func partialMigrate(
        state: PluginState,
        from oldVersion: String,
        to newVersion: String
    ) async throws -> PluginState {
        // 实现部分迁移逻辑
        // ...
        return state
    }
}
```

### 5. 重载 UI

```swift
/// 插件重载视图
struct PluginReloadView: View {
    @ObservedObject var coordinator: PluginReloadCoordinator
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // 状态图标
            stateIcon
                .font(.system(size: 60))
            
            // 状态文字
            Text(stateText)
                .font(.headline)
            
            // 进度条
            if coordinator.state.isInProgress {
                ProgressView(value: coordinator.progress) {
                    Text("\(Int(coordinator.progress * 100))%")
                }
                .progressViewStyle(.linear)
                .frame(width: 200)
            }
            
            // 操作按钮
            if coordinator.state == .completed {
                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            
            if case .failed(let error) = coordinator.state {
                VStack {
                    Text("重载失败")
                        .foregroundColor(.red)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("重试") {
                        // 重新尝试
                    }
                }
            }
        }
        .padding(40)
    }
    
    @ViewBuilder
    private var stateIcon: some View {
        switch coordinator.state {
        case .idle:
            Image(systemName: "circle")
        case .preparing, .exporting, .suspending, .loading, .migrating, .resuming:
            Image(systemName: "arrow.triangle.2.circlepath")
                .symbolEffect(.rotate)
        case .completed:
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle")
                .foregroundColor(.red)
        }
    }
    
    private var stateText: String {
        switch coordinator.state {
        case .idle: return "准备重载..."
        case .preparing: return "准备中..."
        case .exporting: return "导出状态..."
        case .suspending: return "挂起插件..."
        case .loading: return "加载新版本..."
        case .migrating: return "迁移状态..."
        case .resuming: return "恢复插件..."
        case .completed: return "重载完成"
        case .failed: return "重载失败"
        }
    }
}

extension PluginReloadCoordinator.ReloadState {
    var isInProgress: Bool {
        switch self {
        case .preparing, .exporting, .suspending, .loading, .migrating, .resuming:
            return true
        default:
            return false
        }
    }
}
```

---

## 测试清单

- [ ] 测试插件正常加载和卸载
- [ ] 测试插件重载时状态迁移
- [ ] 测试依赖插件的处理
- [ ] 测试重载失败时的回滚
- [ ] 测试并发重载多个插件
- [ ] 测试状态迁移的版本兼容性

---

## 修复优先级

中 - 影响开发体验和系统稳定性

---

*创建时间: 2026-03-13*