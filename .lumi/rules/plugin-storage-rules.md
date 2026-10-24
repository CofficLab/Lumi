# 插件数据存储规范

> 本规范定义了 Lumi 项目中所有插件的数据存储方式和最佳实践。

---

## 核心原则

**数据放在插件的专属目录，由插件自己负责管理。**

每个插件拥有独立的存储目录，由插件通过内核的 `StorageProviding` 能力获取，插件自行负责其目录内所有数据的读写、迁移和清理工作。

---

## 0. 基础设施：`StorageProviding`

所有插件存储的唯一正确入口是 `StorageProviding`（定义在 `LumiProviders/ProviderStorage`）：

```swift
@MainActor
public protocol StorageProviding: AnyObject {
    /// 数据根目录
    var dataRootDirectory: URL { get }

    /// 插件数据目录
    func pluginDataDirectory(for pluginID: String) -> URL

    /// 当前数据空间下所有可识别的版本根目录，包括当前目录
    var allVersionDataRootDirectories: [URL] { get }

    /// 核心数据目录
    func coreDataDirectory() -> URL
}
```

数据根目录形如：

```
~/Library/Application Support/com.coffic.Lumi/
├── db_debug_v6/          # Debug 构建
└── db_production_v6/     # Release 构建
```

> **重要**：根目录带 `_v6` **主版本号**。这正是插件必须通过 `StorageProviding` 获取路径的原因——版本升级时根目录会整体切换，由 `PluginDataMigrating` 负责把旧版本数据搬过来。**任何绕过 `StorageProviding` 写死路径的实现，升级后都会丢数据。**

### 0.1 在插件中获取目录

路径必须在 `onBoot(kernel:)` 中从内核解析，**不要**自己拼 `applicationSupportDirectory`：

```swift
public func onBoot(kernel: KernelCoreContainer) throws {
    if let storage = kernel.resolveProvider((any StorageProviding).self) {
        let pluginDirectory = storage.pluginDataDirectory(for: id)
        MyPluginRuntime.dataDirectoryProvider = { pluginDirectory }
    }
    // ...
}
```

因为迁移发生在 `onBoot` 之前，`onBoot` 里拿到的目录已经是**迁移完成后**的当前版本目录。

### 0.2 数据迁移：`PluginDataMigrating`

插件若历史上用过别的目录名（例如早期版本叫 `ClipboardManager`），需声明迁移：

```swift
@MainActor
public final class MyPlugin: SuperPlugin, PluginDataMigrating {
    public let id = "com.coffic.lumi.plugin.my-plugin"
    public let legacyDataDirectoryNames = ["MyPlugin", "OldMyPluginName"]

    // migrateData 有默认实现，无需覆写
}
```

- 迁移在 `onBoot` **之前**执行，由 `PluginDataMigrationRunner` 驱动（主应用与各专用宿主共用同一套时序）。
- 迁移采用**复制**而非移动，旧版本数据保留；目标中已有文件不覆盖，可安全重试。
- 迁移完成后写入 `.lumi-storage-migration.json` 标记文件，重复启动不会重复迁移。
- 已经始终使用自身 ID 作为目录名的插件，返回空数组即可（默认值）。

> **重要**：目录名一旦发布就不能随意改。改目录名等于让用户数据"失联"，必须同时提供 `legacyDataDirectoryNames` 声明旧名。

---

## 1. 配置类数据

配置类数据是指插件的设置项、用户偏好等小型、需要持久化的数据。

### 1.1 存储方式

- **格式**：Plist 文件（Binary Property List）
- **位置**：`pluginDataDirectory(for: id)` 下（通常直接放 `settings.plist`）
- **实现**：每个插件自行实现 Store 类，封装读写逻辑

### 1.2 目录结构

```
~/Library/Application Support/com.coffic.Lumi/db_{debug|production}_v6/
├── Core/                              # 主数据库（Core 模块）
│   └── Lumi.db
├── com.coffic.lumi.plugin.clipboard-manager/   # ClipboardManager 插件
│   ├── settings/
│   │   └── settings.plist
│   └── history.sqlite
└── <pluginID>/                        # 其他插件，目录名 = pluginID
    └── settings.plist
```

> 目录名是 **pluginID**（如 `com.coffic.lumi.plugin.clipboard-manager`），不是简短类名。历史上用过的简短目录名需通过 `legacyDataDirectoryNames` 声明并迁移。

### 1.3 实现模板

每个插件应实现一个 `<PluginName>PluginLocalStore` 类，遵循以下模板：

```swift
import Foundation

/// <PluginName> 插件本地存储
///
/// 负责持久化插件的配置和设置项。
/// 存储位置：由 `onBoot` 注入的 `pluginDataDirectory(for: id)`
final class <PluginName>PluginLocalStore: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = <PluginName>PluginLocalStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "<PluginName>PluginLocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL

    // MARK: - Initialization

    /// 由插件入口在 `onBoot` 中调用，传入 `pluginDataDirectory(for: id)`。
    init(dataDirectory: URL) {
        self.pluginDirectory = dataDirectory
        self.settingsFileURL = dataDirectory.appendingPathComponent("settings.plist")
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// 存储值
    func set(_ value: Any?, forKey key: String) {
        queue.sync {
            var dict = readDict()
            if let value {
                dict[key] = value
            } else {
                dict.removeValue(forKey: key)
            }
            writeDict(dict)
        }
    }

    /// 获取值
    func object(forKey key: String) -> Any? {
        queue.sync { readDict()[key] }
    }

    /// 获取布尔值
    func bool(forKey key: String) -> Bool {
        (object(forKey: key) as? Bool) ?? false
    }

    /// 获取字符串
    func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    /// 获取整数
    func integer(forKey key: String) -> Int {
        (object(forKey: key) as? Int) ?? 0
    }

    /// 获取双精度浮点数
    func double(forKey key: String) -> Double {
        (object(forKey: key) as? Double) ?? 0.0
    }

    /// 删除指定键
    func remove(forKey key: String) {
        set(nil, forKey: key)
    }

    /// 清空所有配置
    func clearAll() {
        queue.sync {
            writeDict([:])
        }
    }

    // MARK: - Private Helpers

    /// 从文件读取字典
    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path),
              let data = try? Data(contentsOf: settingsFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }

    /// 写入字典到文件（原子操作）
    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else {
            return
        }

        let tmpURL = pluginDirectory.appendingPathComponent("settings.tmp")

        do {
            // 原子写入临时文件
            try data.write(to: tmpURL, options: .atomic)

            // 替换原文件
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try? fileManager.replaceItemAt(settingsFileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: settingsFileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmpURL)
        }
    }
}
```

### 1.4 使用示例

```swift
// 定义配置键常量
extension <PluginName>PluginLocalStore {
    private enum Keys {
        static let enabled = "enabled"
        static let maxHistoryCount = "max_history_count"
        static let lastUpdated = "last_updated"
    }
}

// 在 ViewModel 或 Service 中使用
class <PluginName>ViewModel: ObservableObject {
    private let store: <PluginName>PluginLocalStore

    @Published var isEnabled: Bool {
        didSet { store.set(isEnabled, forKey: Keys.enabled) }
    }

    @Published var maxHistoryCount: Int {
        didSet { store.set(maxHistoryCount, forKey: Keys.maxHistoryCount) }
    }

    init(store: <PluginName>PluginLocalStore) {
        self.store = store
        self.isEnabled = store.bool(forKey: Keys.enabled)
        self.maxHistoryCount = store.integer(forKey: Keys.maxHistoryCount)
    }
}
```

### 1.5 最佳实践

#### ✅ 推荐

1. **目录由 `onBoot` 注入**：Store 接收 `pluginDataDirectory(for: id)` 作为参数，不在内部解析路径
2. **二进制 Plist**：`PropertyListSerialization` 用 `.binary` 格式
3. **原子写入**：先写入临时文件，再替换原文件，避免数据损坏
4. **键名常量化**：定义 `Keys` 枚举或结构体集中管理配置键名
5. **类型化访问方法**：提供 `bool(forKey:)`、`string(forKey:)` 等便捷方法
6. **串行队列**：用 `DispatchQueue` 串行化 read-modify-write

#### ❌ 避免

1. **绕过 `StorageProviding` 自建路径**：不要直接调 `urls(for: .applicationSupportDirectory, ...)` 拼目录名——会脱离版本化根目录，升级时丢数据
2. **直接使用 UserDefaults**：配置类数据应使用 Plist 文件，便于管理和迁移
3. **多个插件共用同一个数据目录**：每个插件用 `pluginID` 作为目录名，不要写 `PluginSettings/` 这类共享目录
4. **硬编码键名**：避免在代码中散落字符串键名
5. **阻塞主线程**：大量数据操作应在后台队列执行
6. **忽略错误处理**：文件操作应妥善处理可能的错误

### 1.6 现有实现参考

以下实现符合当前规范，可作为参考：

| 包 | 文件 | 特点 |
|-----|------|------|
| PluginClipboardManager | `Packages/PluginClipboardManager/Sources/PluginClipboardManager/ClipboardManagerPluginLocalStore.swift` | 目录由 `onBoot` 注入 `ClipboardManagerRuntime`；含损坏文件备份 |
| PluginInput | `Packages/PluginInput/Sources/PluginInput/Services/InputPluginLocalStore.swift` | 完整实现 |
| PluginDiskManager | `Packages/PluginDiskManager/Sources/PluginDiskManager/DiskManagerPlugin.swift` | 在 `onBoot` 中解析目录后注入 |
| PluginDatabaseManager | `Packages/PluginDatabaseManager/Sources/PluginDatabaseManager/` | 完整实现 |
| PluginConversationManager | `Packages/PluginConversationManager/Sources/PluginConversationManager/` | 完整实现 |
| PluginMail | `Packages/PluginMail/Sources/PluginMail/Support/MailPluginLocalStore.swift` | 目录合规；邮箱凭据另存 Keychain |

---

## 2. 历史记录类数据

历史记录类数据是指插件运行时产生的时间序列数据，需要长期存储并支持按时间范围查询。

### 2.1 存储方式

- **格式**：SwiftData（SQLite）
- **位置**：`pluginDataDirectory(for: id)` 下的 `history.sqlite`
- **实现**：参考 PluginClipboardManager / PluginAppManager 的实现模式

### 2.2 适用场景

- 网络流量监控历史
- 内存使用历史
- CPU 占用历史
- 剪贴板历史记录
- 操作日志历史

### 2.3 目录结构

```
~/Library/Application Support/com.coffic.Lumi/db_{debug|production}_v6/
├── com.coffic.lumi.plugin.network-manager/    # PluginNetworkManager
│   └── history.sqlite
├── com.coffic.lumi.plugin.memory/             # PluginMemory
│   └── history.sqlite
└── <pluginID>/                                # 其他插件
    └── history.sqlite
```

### 2.4 实现模板

#### 2.4.1 定义模型

```swift
import Foundation
import SwiftData

/// 历史记录数据模型
///
/// 使用 @Model 宏定义 SwiftData 模型
@Model
final class <DataPointName> {
    /// 时间戳（作为主键或索引）
    var timestamp: TimeInterval

    /// 数据值 - 根据实际需求定义字段
    var value: Double
    var value2: Double?
    var metadata: String?

    // MARK: - 索引

    /// 按时间戳索引查询
    static func predicate(from startTime: TimeInterval, to endTime: TimeInterval) -> Predicate<<DataPointName>> {
        #Predicate<<DataPointName>> { item in
            item.timestamp >= startTime && item.timestamp <= endTime
        }
    }

    // MARK: - 初始化

    init(timestamp: TimeInterval, value: Double, value2: Double? = nil, metadata: String? = nil) {
        self.timestamp = timestamp
        self.value = value
        self.value2 = value2
        self.metadata = metadata
    }
}
```

#### 2.4.2 实现 HistoryManager

```swift
import Foundation
import SwiftData

/// 历史记录管理器
///
/// 负责历史数据的增删改查和数据清理。
/// 数据库目录由插件入口在 `onBoot` 中注入。
actor <PluginName>HistoryManager: SuperLog {
    nonisolated static let emoji = "📊"
    nonisolated static let verbose = false

    // MARK: - Singleton

    static let shared = <PluginName>HistoryManager()

    // MARK: - Properties

    private let container: ModelContainer

    // 数据保留期限（秒）
    private let retentionPeriod: TimeInterval = 30 * 24 * 60 * 60  // 默认保留 30 天

    // 最大记录数
    private let maxRecords = 50000

    // MARK: - 初始化

    /// - Parameter dataDirectory: `pluginDataDirectory(for: pluginID)`
    init(dataDirectory: URL) {
        let schema = Schema([<DataPointName>.self])
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let dbURL = dataDirectory.appendingPathComponent("history.sqlite")

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - 公开方法

    /// 添加数据点
    func add(_ dataPoint: <DataPointName>) async {
        let context = ModelContext(container)

        context.insert(dataPoint)

        // 定期清理过期数据
        let descriptor = FetchDescriptor<<DataPointName>>()
        if let count = try? context.fetchCount(descriptor), count > maxRecords {
            await cleanupOldData(context: context)
        }

        try? context.save()

        if Self.verbose {
            <PluginName>Plugin.logger.info("\(Self.t)添加数据点：\(dataPoint.timestamp)")
        }
    }

    /// 批量添加数据点
    func addBatch(_ dataPoints: [<DataPointName>]) async {
        let context = ModelContext(container)

        for dataPoint in dataPoints {
            context.insert(dataPoint)
        }

        try? context.save()

        if Self.verbose {
            <PluginName>Plugin.logger.info("\(Self.t)批量添加 \(dataPoints.count) 个数据点")
        }
    }

    /// 查询指定时间范围内的数据
    func query(from startTime: TimeInterval, to endTime: TimeInterval) async -> [<DataPointName>] {
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<<DataPointName>>(
            predicate: <DataPointName>.predicate(from: startTime, to: endTime),
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        // 限制返回数量，避免内存溢出
        descriptor.fetchLimit = 10000

        do {
            return try context.fetch(descriptor)
        } catch {
            <PluginName>Plugin.logger.error("\(Self.t)查询失败：\(error.localizedDescription)")
            return []
        }
    }

    /// 获取最新 N 条记录
    func getLatest(limit: Int = 100) async -> [<DataPointName>] {
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<<DataPointName>>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            let results = try context.fetch(descriptor)
            return results.reversed() // 按时间正序返回
        } catch {
            return []
        }
    }

    /// 清理过期数据
    func cleanup() async {
        let context = ModelContext(container)
        await cleanupOldData(context: context)
    }

    /// 清空所有历史记录
    func clearAll() async {
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<<DataPointName>>()
        guard let allItems = try? context.fetch(descriptor) else { return }

        for item in allItems {
            context.delete(item)
        }

        try? context.save()

        if Self.verbose {
            <PluginName>Plugin.logger.info("\(Self.t)已清空所有历史记录")
        }
    }

    // MARK: - 私有方法

    /// 清理过期数据
    private func cleanupOldData(context: ModelContext) async {
        let cutoffTime = Date().timeIntervalSince1970 - retentionPeriod

        let descriptor = FetchDescriptor<<DataPointName>>(
            predicate: #Predicate<<DataPointName>> { item in
                item.timestamp < cutoffTime
            }
        )

        guard let oldItems = try? context.fetch(descriptor) else { return }

        for item in oldItems {
            context.delete(item)
        }

        try? context.save()

        if Self.verbose {
            <PluginName>Plugin.logger.info("\(Self.t)清理了 \(oldItems.count) 条过期记录")
        }
    }
}
```

### 2.5 使用示例

```swift
// 在 Service 中使用
@MainActor
class MemoryHistoryService: ObservableObject {
    static let shared = MemoryHistoryService()

    private let historyManager: MemoryHistoryManager

    @Published var recentHistory: [MemoryDataPoint] = []
    @Published var longTermHistory: [MemoryDataPoint] = []

    private var cancellables = Set<AnyCancellable>()

    init(historyManager: MemoryHistoryManager) {
        self.historyManager = historyManager
        startRecording()
    }

    func startRecording() {
        // 监听内存变化并记录
        MemoryService.shared.$memoryUsagePercentage
            .sink { [weak self] usagePct in
                Task {
                    let point = MemoryDataPoint(
                        timestamp: Date().timeIntervalSince1970,
                        usagePercentage: usagePct,
                        usedBytes: MemoryService.shared.usedMemory
                    )
                    await self?.historyManager.add(point)
                }
            }
            .store(in: &cancellables)
    }

    func getData(for range: TimeRange) async -> [MemoryDataPoint] {
        let now = Date().timeIntervalSince1970
        let cutoff = now - range.duration
        return await historyManager.query(from: cutoff, to: now)
    }

    private func loadHistory() async {
        let now = Date().timeIntervalSince1970
        let cutoff = now - 30 * 24 * 60 * 60  // 30 天
        longTermHistory = await historyManager.query(from: cutoff, to: now)
    }
}
```

### 2.6 最佳实践

#### ✅ 推荐

1. **使用 Actor**：确保线程安全，避免数据竞争
2. **SwiftData 模型**：使用 `@Model` 宏，简化持久化代码
3. **时间索引**：对 timestamp 字段建立查询谓词，支持范围查询
4. **数据清理**：定期清理过期数据，避免数据库膨胀
5. **批量操作**：大量数据使用 `addBatch` 减少 IO 次数
6. **fetchLimit**：查询时限制返回数量，防止内存溢出
7. **目录注入**：ModelContainer 的 `url` 基于 `pluginDataDirectory(for: id)`

#### ❌ 避免

1. **写死数据库路径**：不要用 `AppConfig.getDBFolderURL()` 或自建 `applicationSupportDirectory` 路径
2. **手动 JSON 文件管理**：历史数据应使用 SwiftData，便于查询和清理
3. **内存数据无限累积**：设置 `retentionPeriod` 和 `maxRecords` 限制
4. **主线程大量写入**：写入操作应在后台 actor 中执行
5. **忽略错误处理**：数据库操作应妥善处理错误

### 2.7 现有实现参考

| 包 | 存储方式 | 特点 |
|----|---------|------|
| PluginClipboardManager | SwiftData | 目录注入 + `legacyDataDirectoryNames` 迁移 |
| PluginAppManager | SwiftData | 缓存管理完整实现 |
| PluginConversationManager | SwiftData | 会话历史存储 |
| PluginNetworkManager | SwiftData | 网络指标历史，支持范围查询 |

---

## 附录

### A. 存储类型对比

| 存储类型 | 格式 | 适用场景 | 示例 |
|---------|------|---------|------|
| 配置类 | Binary Plist | 小型设置项、用户偏好 | `settings.plist` |
| 历史记录 | SwiftData (SQLite) | 时间序列数据、历史记录 | `history.sqlite` |
| 凭据 | Keychain | 密码、Token、API Key | 见 `KitKeychain` |

### B. 路径常量（已废弃，勿使用）

```swift
// ❌ 已废弃：以下 API 在当前代码库中不存在，勿在新代码中使用
AppConfig.getDBFolderURL()
AppConfig.getPluginDBFolderURL(pluginName:)
```

正确写法：

```swift
// ✅ 在 onBoot 中从内核解析
let storage = kernel.resolveProvider((any StorageProviding).self)
let dir = storage?.pluginDataDirectory(for: id)
```

---

## 检查清单

新增或改造插件存储时，确认：

- [ ] 目录来自 `storage.pluginDataDirectory(for: pluginID)`，未自行拼 `applicationSupportDirectory`
- [ ] 插件声明 `PluginDataMigrating` 并正确填写 `legacyDataDirectoryNames`
- [ ] 配置类数据用 Binary Plist，未用 UserDefaults
- [ ] 历史数据用 SwiftData，未手写 JSON 管理时序数据
- [ ] 每个插件独占目录，未与其他插件共用 `PluginSettings/` 之类共享目录
- [ ] 凭据类数据存 Keychain，未落盘到 plist
- [ ] 文件写入使用原子操作
- [ ] 错误处理已覆盖，未静默 `try?` 掉关键失败

---

## 相关规范

- [插件目录结构规范](./plugin-directory-rules.md) — `LumiApp/Plugins/` 内部结构
- [插件包目录结构规范](./plugin-package-structure.md) — `Packages/` 下 SPM 包分层
- [Swift 日志记录规范](./swift-log.md) — Logger 分配与格式
- [Commit 规范](./commit-convention.md) — Git 提交信息约定
- [最少功能原则](./minimal-functionality.md) — 代码最小化
