# 插件数据存储规范

> 本规范定义了 Lumi 项目中所有插件的数据存储方式和最佳实践。

---

## 核心原则

**数据放在插件的专属目录，由插件自己负责管理。**

每个插件拥有独立的存储目录，位于 `AppConfig.getDBFolderURL()/<PluginName>/` 下，插件自行负责其目录内所有数据的读写、迁移和清理工作。

---

## 1. 配置类数据

配置类数据是指插件的设置项、用户偏好等小型、需要持久化的数据。

### 1.1 存储方式

- **格式**：Plist 文件（Binary Property List）
- **位置**：`AppConfig.getDBFolderURL()/<PluginName>/settings.plist`
- **实现**：每个插件自行实现 Store 类，封装读写逻辑

### 1.2 目录结构

```
~/Library/Application Support/com.coffic.Lumi/db_{debug|production}/
├── Core/                              # 主数据库（Core 模块）
│   └── Lumi.db
├── ClipboardManager/                  # ClipboardManager 插件
│   └── settings.plist
├── MenuBarManager/                    # MenuBarManager 插件
│   └── settings.plist
├── InputPlugin/                       # InputPlugin 插件
│   └── settings.plist
└── [PluginName]/                      # 其他插件
    └── settings.plist
```

### 1.3 实现模板

每个插件应实现一个 `<PluginName>LocalStore` 类，遵循以下模板：

```swift
import Foundation

/// <PluginName> 插件本地存储
///
/// 负责持久化插件的配置和设置项。
/// 存储位置：AppConfig.getDBFolderURL()/<PluginName>/settings.plist
final class <PluginName>LocalStore: @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = <PluginName>LocalStore()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "<PluginName>LocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL
    
    // MARK: - Initialization
    
    private init() {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent("<PluginName>", isDirectory: true)
        self.pluginDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
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
extension <PluginName>LocalStore {
    private enum Keys {
        static let enabled = "enabled"
        static let maxHistoryCount = "max_history_count"
        static let lastUpdated = "last_updated"
    }
}

// 在 ViewModel 或 Service 中使用
class <PluginName>ViewModel: ObservableObject {
    private let store = <PluginName>LocalStore.shared
    
    @Published var isEnabled: Bool {
        didSet { store.set(isEnabled, forKey: Keys.enabled) }
    }
    
    @Published var maxHistoryCount: Int {
        didSet { store.set(maxHistoryCount, forKey: Keys.maxHistoryCount) }
    }
    
    init() {
        self.isEnabled = store.bool(forKey: Keys.enabled)
        self.maxHistoryCount = store.integer(forKey: Keys.maxHistoryCount)
    }
}
```

### 1.5 最佳实践

#### ✅ 推荐

1. **使用单例模式**：通过 `static let shared` 提供全局访问点
2. **线程安全**：使用 `DispatchQueue` 确保并发访问安全
3. **原子写入**：先写入临时文件，再替换原文件，避免数据损坏
4. **键名常量化**：定义 `Keys` 枚举或结构体集中管理配置键名
5. **类型化访问方法**：提供 `bool(forKey:)`、`string(forKey:)` 等便捷方法

#### ❌ 避免

1. **直接使用 UserDefaults**：配置类数据应使用 Plist 文件，便于管理和迁移
2. **硬编码键名**：避免在代码中散落字符串键名
3. **阻塞主线程**：大量数据操作应在后台队列执行
4. **忽略错误处理**：文件操作应妥善处理可能的错误

### 1.6 现有实现参考

以下插件已正确实现配置存储，可作为参考：

| 插件 | 文件路径 | 特点 |
|-----|---------|------|
| ClipboardManager | `Plugins/ClipboardManagerPlugin/ClipboardManagerPluginLocalStore.swift` | 完整实现 |
| MenuBarManager | `Plugins/MenuBarManagerPlugin/MenuBarManagerPluginLocalStore.swift` | 完整实现 |
| InputPlugin | `Plugins/InputPlugin/InputPluginLocalStore.swift` | 完整实现 |
| TextActionsPlugin | `Plugins/TextActionsPlugin/TextActionsPluginLocalStore.swift` | 完整实现 |
| ModelPreferencePlugin | `Plugins/ModelPreferencePlugin/ModelPreferenceStore.swift` | 支持按项目存储 |

---

## 2. 历史记录类数据

历史记录类数据是指插件运行时产生的时间序列数据，需要长期存储并支持按时间范围查询。

### 2.1 存储方式

- **格式**：SwiftData（SQLite）
- **位置**：`AppConfig.getDBFolderURL()/<PluginName>/history.sqlite`
- **实现**：参考 AppManagerPlugin 的 CacheManager 实现模式

### 2.2 适用场景

- 网络流量监控历史
- 内存使用历史
- CPU 占用历史
- 剪贴板历史记录
- 操作日志历史

### 2.3 目录结构

```
~/Library/Application Support/com.coffic.Lumi/db_{debug|production}/
├── MemoryManager/                     # MemoryManager 插件
│   └── history.sqlite
├── NetworkManager/                    # NetworkManager 插件
│   └── history.sqlite
├── CPUManager/                        # CPUManager 插件
│   └── history.sqlite
├── ClipboardManager/                  # ClipboardManager 插件
│   └── history.sqlite
└── [PluginName]/                      # 其他插件
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
/// 参考 AppManagerPlugin 的 CacheManager 实现模式。
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
    
    // MARK: - Initialization
    
    private init() {
        // 定义 Schema
        let schema = Schema([<DataPointName>.self])
        
        // 数据库路径
        let dbDir = AppConfig.getDBFolderURL()
            .appendingPathComponent("<PluginName>", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbURL = dbDir.appendingPathComponent("history.sqlite")
        
        // 配置 ModelContainer
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
    
    // MARK: - Public API
    
    /// 添加数据点
    func add(_ dataPoint: <DataPointName>) async {
        let context = ModelContext(container)
        
        context.insert(dataPoint)
        
        // 定期清理过期数据（每 100 条数据检查一次）
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
    
    // MARK: - Private Helpers
    
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

#### 定义具体的数据模型

```swift
// 例如：内存历史记录模型
@Model
final class MemoryDataPoint {
    var timestamp: TimeInterval
    var usagePercentage: Double
    var usedBytes: UInt64
    
    init(timestamp: TimeInterval, usagePercentage: Double, usedBytes: UInt64) {
        self.timestamp = timestamp
        self.usagePercentage = usagePercentage
        self.usedBytes = usedBytes
    }
    
    static func predicate(from startTime: TimeInterval, to endTime: TimeInterval) -> Predicate<MemoryDataPoint> {
        #Predicate<MemoryDataPoint> { item in
            item.timestamp >= startTime && item.timestamp <= endTime
        }
    }
}
```

#### 使用 HistoryManager

```swift
// 在 Service 中使用
@MainActor
class MemoryHistoryService: ObservableObject {
    static let shared = MemoryHistoryService()
    
    private let historyManager = MemoryHistoryManager.shared
    
    @Published var recentHistory: [MemoryDataPoint] = []
    @Published var longTermHistory: [MemoryDataPoint] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        Task {
            await loadHistory()
            startRecording()
        }
    }
    
    func startRecording() {
        // 监听内存变化并记录
        MemoryService.shared.$memoryUsagePercentage
            .sink { [weak self] usagePct in
                Task { [weak self] in
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

#### ❌ 避免

1. **手动 JSON 文件管理**：历史数据应使用 SwiftData，便于查询和清理
2. **内存数据无限累积**：设置 `retentionPeriod` 和 `maxRecords` 限制
3. **主线程大量写入**：写入操作应在后台 actor 中执行
4. **忽略错误处理**：数据库操作应妥善处理错误

### 2.7 现有实现参考

以下插件已实现历史记录存储，可作为参考：

| 插件 | 文件路径 | 存储方式 | 特点 |
|-----|---------|---------|------|
| AppManagerPlugin | `Plugins/AppManagerPlugin/Services/CacheManager.swift` | SwiftData | 完整实现 |
| MemoryManagerPlugin | `Plugins/MemoryManagerPlugin/Services/MemoryHistoryService.swift` | JSON + 内存 | 内存缓存 + 定期持久化 |
| NetworkManagerPlugin | `Plugins/NetworkManagerPlugin/Services/NetworkHistoryService.swift` | JSON + 内存 | 内存缓存 + 定期持久化 |
| CPUManagerPlugin | `Plugins/CPUManagerPlugin/Services/CPUHistoryService.swift` | JSON + 内存 | 内存缓存 + 定期持久化 |

> **注意**：MemoryManagerPlugin、NetworkManagerPlugin、CPUManagerPlugin 当前使用 JSON 文件存储，建议后续迁移到 SwiftData。

---

## 附录

### A. 存储类型对比

| 存储类型 | 格式 | 适用场景 | 示例 |
|---------|------|---------|------|
| 配置类 | Plist | 小型设置项、用户偏好 | `settings.plist` |
| 历史记录 | SwiftData (SQLite) | 时间序列数据、历史记录 | `history.sqlite` |

### B. 路径常量

```swift
// 基础路径
AppConfig.getDBFolderURL()  // ~/Library/Application Support/com.coffic.Lumi/db_{debug|production}/

// 插件专用路径
AppConfig.getPluginDBFolderURL(pluginName: "<PluginName>")  // 自动创建并返回插件目录
```