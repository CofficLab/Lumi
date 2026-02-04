# DiskManagerPlugin 功能扩展计划

> 参考项目：[Mole](https://github.com/tw93/Mole) - All-in-one macOS system toolkit
>
> 目标：将 Mole 的核心功能集成到 SwiftUI 磁盘管理插件中

---

## 目录

1. [参考项目分析](#1-参考项目分析)
2. [技术架构设计](#2-技术架构设计)
3. [分阶段实施计划](#3-分阶段实施计划)
4. [数据模型设计](#4-数据模型设计)
5. [服务层设计](#5-服务层设计)
6. [UI/UX 设计](#6-uiux-设计)
7. [测试策略](#7-测试策略)

---

## 1. 参考项目分析

### 1.1 Mole 功能矩阵

| 功能模块 | 命令 | 核心能力 | 集成优先级 |
|---------|------|---------|-----------|
| 磁盘分析 | `mo analyze` | 目录树扫描、大文件追踪、缓存机制 | P0 |
| 系统清理 | `mo clean` | 缓存/日志/浏览器残留清理 | P0 |
| 系统优化 | `mo optimize` | 数据库重建、服务刷新 | P1 |
| 状态监控 | `mo status` | CPU/GPU/内存/磁盘/网络实时监控 | P1 |
| 应用卸载 | `mo uninstall` | 完全移除应用及配置 | P2 |
| 项目清理 | `mo purge` | 构建产物清理 (node_modules/target) | P2 |
| 安装包清理 | `mo installer` | DMG/PKG 查找清理 | P2 |

### 1.2 Mole 核心技术特点

```go
// Mole 的并发扫描模式
func scanPathConcurrent(path string) scanResult {
    // 1. 使用 sync.SingleFlight 避免重复扫描
    // 2. goroutine 并发遍历目录
    // 3. 堆结构维护 Top N 大文件
    // 4. 结果持久化到本地缓存
}
```

**Swift 转译要点**：
- `SingleFlight` → `Task` + `actor` 模式
- goroutine → Swift `async/await` + `TaskGroup`
- 堆结构 → Swift Collections / 手动实现
- 持久化 → `UserDefaults` / `CoreData` / JSON 文件

---

## 2. 技术架构设计

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftUI Views                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Dashboard│  │ Analyzer │  │ Cleaner  │  │ Monitor  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ViewModels (@MainActor)                  │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │ DiskManagerVM    │  │ SystemMonitorVM  │               │
│  │ CacheCleanerVM   │  │ AppUninstallerVM │               │
│  └──────────────────┘  └──────────────────┘               │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Services (actor)                       │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │ ScanService      │  │ CacheService     │               │
│  │ MonitorService   │  │ UninstallService │               │
│  │ StorageService   │  │ SafetyService    │               │
│  └──────────────────┘  └──────────────────┘               │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Foundation Layer                        │
│  FileManager / Process / FSEvents / IOKit / SystemPolicy   │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 并发模型

```swift
// 使用 actor 确保线程安全
actor ScanCoordinator {
    private var activeScans: [String: Task<Void, Never>] = [:]
    private var scanCache: [String: ScanResult] = [:]

    func scan(_ path: String) async throws -> ScanResult {
        // 1. 检查缓存
        if let cached = scanCache[path] {
            return cached
        }

        // 2. 检查是否已有扫描任务
        if let existing = activeScans[path] {
            // 等待现有任务完成
            return await scanCache[path]!
        }

        // 3. 创建新扫描任务
        let task = Task {
            await performScan(path)
        }
        activeScans[path] = task

        let result = await task.value
        scanCache[path] = result
        activeScans[path] = nil

        return result
    }
}
```

### 2.3 缓存策略

```swift
// 扫描结果缓存模型
struct ScanCache: Codable {
    let path: String
    let entries: [DirectoryEntry]
    let largeFiles: [LargeFileEntry]
    let timestamp: Date
    let checksum: String  // 目录内容校验和

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 3600  // 1小时过期
    }
}

// 缓存存储服务
actor ScanCacheService {
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func save(_ cache: ScanCache) async throws {
        let fileURL = cacheDirectory.appendingPathComponent("\(cache.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!).json")
        let data = try encoder.encode(cache)
        try data.write(to: fileURL)
    }

    func load(for path: String) async throws -> ScanCache? {
        let fileURL = cacheDirectory.appendingPathComponent("\(path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!).json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(ScanCache.self, from: data)
    }
}
```

---

## 3. 分阶段实施计划

### Phase 1: 增强磁盘分析 (2-3周)

**目标**：实现 Mole 级别的磁盘分析能力

- [x] 基础大文件扫描 (已有)
- [x] **1.1 目录树扫描与可视化**
  - 实现目录树数据模型
  - SwiftUI 树形视图组件
  - 目录大小聚合计算
- [x] **1.2 并发扫描优化**
  - Swift TaskGroup 并发遍历
  - 进度追踪与取消支持
  - 扫描结果缓存
- [x] **1.3 大文件追踪增强**
  - Top-N 大文件堆结构
  - 按类型/日期/大小分组
  - 文件预览功能

### Phase 2: 系统清理功能 (2-3周)

**目标**：实现智能系统缓存清理

- [x] **2.1 缓存扫描**
  - 系统缓存目录识别
  - 浏览器缓存检测 (Chrome, Safari, Firefox)
  - 开发工具缓存 (Xcode DerivedData, npm, cargo)
- [x] **2.2 安全清理机制**
  - 白名单/黑名单管理 (基础安全分级)
  - Dry-run 预览模式 (选中列表预览)
  - 清理前备份
- [x] **2.3 清理统计**
  - 空间释放计算
  - 清理历史记录 (本次会话)

### Phase 3: 系统监控 (2周)

**目标**：实时系统健康监控

- [x] **3.1 指标收集器**
  - CPU 使用率 (每核心)
  - 内存压力与统计
  - 磁盘 I/O 监控
  - 网络流量统计
- [x] **3.2 实时图表**
  - SwiftUI 动态图表组件
  - 数据采样与平滑
  - 健康评分算法

### Phase 4: 应用卸载与项目管理 (1-2周)

- [x] **4.1 应用卸载器**
  - 应用与关联文件检测
  - Bundle 扫描 (~/Library, /Library)
  - 安全卸载流程
- [x] **4.2 项目构建清理**
  - node_modules, target, build 目录检测
  - 按项目分组
  - 智能推荐清理

---

## 4. 数据模型设计

### 4.1 核心模型

```swift
// MARK: - 目录扫描模型

struct DirectoryEntry: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    let lastAccessed: Date
    let modificationDate: Date
    let children: [DirectoryEntry]?  // nil 表示未扫描

    var isScanned: Bool { children != nil }
    var depth: Int { path.components(separatedBy: "/").count }
}

// MARK: - 大文件模型

struct LargeFileEntry: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let modificationDate: Date
    let fileType: FileType
    let icon: NSImage  // 不参与 Codable

    enum FileType: String, Codable {
        case document, image, video, audio, archive, code, other
    }
}

// MARK: - 扫描结果

struct ScanResult {
    let entries: [DirectoryEntry]
    let largeFiles: [LargeFileEntry]
    let totalSize: Int64
    let totalFiles: Int
    let scanDuration: TimeInterval
    let scannedAt: Date
}

// MARK: - 缓存清理模型

struct CacheCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let paths: [CachePath]
    let safetyLevel: SafetyLevel

    enum SafetyLevel: Int {
        case safe = 0      // 可安全删除
        case medium = 1    // 需要用户确认
        case risky = 2     // 可能影响系统
    }
}

struct CachePath {
    let path: String
    let description: String
    let size: Int64
    let fileCount: Int
    let canDelete: Bool
}

struct CleanupResult {
    let categories: [CacheCategory]
    let totalSize: Int64
    let totalFiles: Int
    let estimatedSpaceToFree: Int64
}

// MARK: - 系统监控模型

struct SystemMetrics: Codable {
    let cpu: CPUMetrics
    let memory: MemoryMetrics
    let disk: DiskMetrics
    let network: NetworkMetrics
    let timestamp: Date

    var healthScore: Int {
        // 0-100 健康评分
        let cpuScore = cpu.healthScore
        let memScore = memory.healthScore
        let diskScore = disk.healthScore
        return (cpuScore + memScore + diskScore) / 3
    }
}

struct CPUMetrics: Codable {
    let overallUsage: Double  // 0.0 - 1.0
    let coreUsage: [Double]   // 每核心使用率
    let temperature: Double?  // 摄氏度
    let loadAverage: (Double, Double, Double)

    var healthScore: Int {
        let usage = Int(overallUsage * 100)
        if usage < 50 { return 100 }
        if usage < 75 { return 80 }
        if usage < 90 { return 50 }
        return 20
    }
}

struct MemoryMetrics: Codable {
    let total: Int64
    let used: Int64
    let free: Int64
    let compressed: Int64
    let swapUsed: Int64
    let pressure: MemoryPressure

    enum MemoryPressure: String, Codable {
        case normal, warning, critical
    }

    var healthScore: Int {
        switch pressure {
        case .normal: return 100
        case .warning: return 60
        case .critical: return 20
        }
    }
}

struct DiskMetrics: Codable {
    let readBytesPerSecond: Int64
    let writeBytesPerSecond: Int64
    let queueDepth: Int
    let usedPercentage: Double

    var healthScore: Int {
        let usage = Int(usedPercentage * 100)
        if usage < 70 { return 100 }
        if usage < 85 { return 70 }
        if usage < 95 { return 40 }
        return 10
    }
}

struct NetworkMetrics: Codable {
    let downloadBytesPerSecond: Int64
    let uploadBytesPerSecond: Int64
    let interface: String
}
```

---

## 5. 服务层设计

### 5.1 扫描服务

```swift
import Foundation
import OSLog

@MainActor
class ScanService: ObservableObject, SuperLog {
    static let shared = ScanService()

    @Published var currentScan: ScanProgress?
    @Published var scanHistory: [ScanResult] = []

    private let coordinator = ScanCoordinator()
    private let cacheService = ScanCacheService()

    // MARK: - 扫描方法

    /// 扫描指定路径
    func scan(_ path: String, forceRefresh: Bool = false) async throws -> ScanResult {
        if !forceRefresh,
           let cached = try? await cacheService.load(for: path),
           !cached.isExpired {
            return ScanResult(from: cached)
        }

        return await coordinator.scan(path)
    }

    /// 取消当前扫描
    func cancelScan() {
        coordinator.cancelCurrentScan()
    }

    /// 获取扫描进度
    var progress: ScanProgress? { currentScan }
}

// MARK: - 扫描进度

struct ScanProgress {
    let path: String
    let currentPath: String
    let scannedFiles: Int
    let scannedDirectories: Int
    let scannedBytes: Int64
    let startTime: Date

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var filesPerSecond: Double {
        Double(scannedFiles) / duration
    }
}

// MARK: - 扫描协调器

actor ScanCoordinator {
    private var activeTask: Task<Void, Never>?
    private var progress: ScanProgress?

    func scan(_ path: String) async -> ScanResult {
        // 取消之前的任务
        activeTask?.cancel()

        let task = Task {
            await performScan(path)
        }
        activeTask = task
        return await task.value
    }

    func cancelCurrentScan() {
        activeTask?.cancel()
    }

    private func performScan(_ path: String) async -> ScanResult {
        let startTime = Date()
        var totalSize: Int64 = 0
        var totalFiles = 0
        var entries: [DirectoryEntry] = []
        var largeFiles: [LargeFileEntry] = []
        var maxHeap = MaxHeap<LargeFileEntry>(capacity: 100)  // Top 100

        // 使用 TaskGroup 并发扫描
        await withTaskGroup(of: (Int, [DirectoryEntry]).self) { group in
            await scanDirectory(at: path, depth: 0, group: group)

            for await (depth, dirEntries) in group {
                entries.append(contentsOf: dirEntries)
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        return ScanResult(
            entries: entries.sorted { $0.size > $1.size },
            largeFiles: Array(largeFiles.sorted { $0.size > $1.size }),
            totalSize: totalSize,
            totalFiles: totalFiles,
            scanDuration: duration,
            scannedAt: Date()
        )
    }

    private func scanDirectory(
        at path: String,
        depth: Int,
        group: TaskGroup<(Int, [DirectoryEntry])>
    ) async {
        // 实现细节...
    }
}

// MARK: - 最大堆 (用于 Top N 大文件)

struct MaxHeap<Element: Hashable & Comparable> {
    private var heap: [Element] = []
    private let capacity: Int

    mutating func insert(_ element: Element) {
        if heap.count < capacity {
            heap.append(element)
            siftUp(from: heap.count - 1)
        } else if element < heap.first! {
            heap[0] = element
            siftDown(from: 0)
        }
    }

    var elements: [Element] { heap.sorted() }

    private mutating func siftUp(from index: Int) { /* ... */ }
    private mutating func siftDown(from index: Int) { /* ... */ }
}
```

### 5.2 缓存清理服务

```swift
@MainActor
class CacheCleanerService: ObservableObject, SuperLog {
    static let shared = CacheCleanerService()

    @Published var categories: [CacheCategory] = []
    @Published var isScanning = false
    @Published var scanProgress: String = ""

    // MARK: - 预定义缓存类别

    private let predefinedCategories: [CacheCategory] = [
        CacheCategory(
            id: "user_app_cache",
            name: "应用缓存",
            description: "各应用程序的缓存文件",
            icon: "app.badge",
            paths: [],
            safetyLevel: .safe
        ),
        CacheCategory(
            id: "browser_cache",
            name: "浏览器缓存",
            description: "Chrome、Safari、Firefox 浏览器缓存",
            icon: "safari",
            paths: [],
            safetyLevel: .safe
        ),
        CacheCategory(
            id: "dev_cache",
            name: "开发工具缓存",
            description: "Xcode、npm、cargo 等开发工具缓存",
            icon: "hammer",
            paths: [],
            safetyLevel: .safe
        ),
        CacheCategory(
            id: "system_logs",
            name: "系统日志",
            description: "系统和应用程序日志文件",
            icon: "doc.text",
            paths: [],
            safetyLevel: .medium
        ),
        CacheCategory(
            id: "trash",
            name: "废纸篓",
            description: "已删除但未清空的文件",
            icon: "trash",
            paths: [],
            safetyLevel: .safe
        )
    ]

    // MARK: - 扫描方法

    func scanCaches() async throws {
        isScanning = true
        scanProgress = "正在扫描缓存..."

        var scannedCategories: [CacheCategory] = []

        for category in predefinedCategories {
            scanProgress = "正在扫描 \(category.name)..."
            let paths = await scanCachePaths(for: category)
            let totalSize = paths.reduce(0) { $0 + $1.size }
            let totalCount = paths.reduce(0) { $0 + $1.fileCount }

            scannedCategories.append(CacheCategory(
                id: category.id,
                name: category.name,
                description: category.description,
                icon: category.icon,
                paths: paths,
                safetyLevel: category.safetyLevel
            ))
        }

        categories = scannedCategories.filter { !$0.paths.isEmpty }
        isScanning = false
    }

    // MARK: - 清理方法

    func cleanup(categories: [CacheCategory], dryRun: Bool = false) async throws -> CleanupResult {
        var totalSize: Int64 = 0
        var totalFiles = 0

        for category in categories {
            for cachePath in category.paths where cachePath.canDelete {
                if !dryRun {
                    try await deleteCache(at: cachePath.path)
                }
                totalSize += cachePath.size
                totalFiles += cachePath.fileCount
            }
        }

        return CleanupResult(
            categories: categories,
            totalSize: totalSize,
            totalFiles: totalFiles,
            estimatedSpaceToFree: totalSize
        )
    }

    // MARK: - 私有方法

    private func scanCachePaths(for category: CacheCategory) async -> [CachePath] {
        // 根据类别扫描相应的缓存路径
        switch category.id {
        case "browser_cache":
            return await scanBrowserCaches()
        case "dev_cache":
            return await scanDevCaches()
        case "trash":
            return await scanTrash()
        default:
            return []
        }
    }

    private func scanBrowserCaches() async -> [CachePath] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let browserPaths = [
            ("Chrome", "\(home)/Library/Caches/Google/Chrome"),
            ("Safari", "\(home)/Library/Caches/com.apple.Safari"),
            ("Firefox", "\(home)/Library/Caches/Firefox")
        ]

        var caches: [CachePath] = []
        for (name, path) in browserPaths {
            if let info = await getDirectoryInfo(at: path) {
                caches.append(CachePath(
                    path: path,
                    description: "\(name) 浏览器缓存",
                    size: info.size,
                    fileCount: info.fileCount,
                    canDelete: true
                ))
            }
        }
        return caches
    }

    private func scanDevCaches() async -> [CachePath] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let devPaths = [
            ("Xcode DerivedData", "\(home)/Library/Developer/Xcode/DerivedData"),
            ("npm Cache", "\(home)/.npm"),
            ("Cargo Registry", "\(home)/.cargo/registry"),
            ("Swift Package Manager", "\(home)/.swiftpm")
        ]

        var caches: [CachePath] = []
        for (name, path) in devPaths {
            if let info = await getDirectoryInfo(at: path) {
                caches.append(CachePath(
                    path: path,
                    description: name,
                    size: info.size,
                    fileCount: info.fileCount,
                    canDelete: true
                ))
            }
        }
        return caches
    }

    private func scanTrash() async -> [CachePath] {
        let trashURL = FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        if let info = await getDirectoryInfo(at: trashURL.path) {
            return [CachePath(
                path: trashURL.path,
                description: "废纸篓",
                size: info.size,
                fileCount: info.fileCount,
                canDelete: true
            )]
        }
        return []
    }

    private func getDirectoryInfo(at path: String) async -> (size: Int64, fileCount: Int)? {
        // 实现目录大小和文件数统计
        return nil
    }

    private func deleteCache(at path: String) async throws {
        try FileManager.default.removeItem(atPath: path)
    }
}
```

### 5.3 系统监控服务

```swift
@MainActor
class SystemMonitorService: ObservableObject, SuperLog {
    static let shared = SystemMonitorService()

    @Published var metrics: SystemMetrics?
    @Published var isMonitoring = false
    @Published var updateInterval: TimeInterval = 1.0

    private var monitorTask: Task<Void, Never>?
    private let cpuCollector = CPUMetricsCollector()
    private let memoryCollector = MemoryMetricsCollector()
    private let diskCollector = DiskMetricsCollector()
    private let networkCollector = NetworkMetricsCollector()

    // MARK: - 监控控制

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitorTask = Task {
            while !Task.isCancelled {
                await updateMetrics()
                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorTask?.cancel()
        monitorTask = nil
    }

    // MARK: - 指标收集

    private func updateMetrics() async {
        async let cpu = cpuCollector.collect()
        async let memory = memoryCollector.collect()
        async let disk = diskCollector.collect()
        async let network = networkCollector.collect()

        let (cpuResult, memoryResult, diskResult, networkResult) = await (cpu, memory, disk, network)

        metrics = SystemMetrics(
            cpu: cpuResult,
            memory: memoryResult,
            disk: diskResult,
            network: networkResult,
            timestamp: Date()
        )
    }
}

// MARK: - CPU 指标收集器

actor CPUMetricsCollector {
    func collect() async -> CPUMetrics {
        var totalUsage: Double = 0
        var coreUsage: [Double] = []
        var loadAvg: (Double, Double, Double) = (0, 0, 0)

        // 使用 host_processor_info 获取 CPU 使用率
        var host: host_t = 0
        var numCpuU: natural_t = 0
        var numCpuInfo: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfoSize: natural_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpuU, &cpuInfo, &numCpuInfoSize)

        if result == KERN_SUCCESS {
            // 解析 CPU 使用率
            // ... 详细实现
        }

        // 获取负载平均值
        var loadavg = [Double](repeating: 0, count: 3)
        if getloadavg(&loadavg, 3) == 3 {
            loadAvg = (loadavg[0], loadavg[1], loadavg[2])
        }

        return CPUMetrics(
            overallUsage: totalUsage,
            coreUsage: coreUsage,
            temperature: nil,  // 需要 IOKit
            loadAverage: loadAvg
        )
    }
}

// MARK: - 内存指标收集器

actor MemoryMetricsCollector {
    func collect() async -> MemoryMetrics {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryMetrics.default
        }

        // 计算内存使用情况
        let pageSize = Int64(vm_kernel_page_size)
        let free = Int64(stats.free_count) * pageSize
        let active = Int64(stats.active_count) * pageSize
        let inactive = Int64(stats.inactive_count) * pageSize
        let wired = Int64(stats.wire_count) * pageSize
        let compressed = Int64(stats.compressor_page_count) * pageSize

        let total = free + active + inactive + wired

        return MemoryMetrics(
            total: total,
            used: active + inactive + wired,
            free: free,
            compressed: compressed,
            swapUsed: 0,  // 需要额外获取
            pressure: .normal
        )
    }
}
```

---

## 6. UI/UX 设计

### 6.1 导航结构

```
DiskManagerPlugin
├── DashboardView           # 总览仪表板
├── AnalyzerView            # 磁盘分析器
│   ├── DirectoryTreeView   # 目录树视图
│   ├── LargeFilesView      # 大文件列表
│   └── FilePreviewPanel    # 文件预览面板
├── CleanerView             # 清理工具
│   ├── CacheCategoriesView # 缓存分类
│   └── CleanupPreviewView  # 清理预览
├── MonitorView             # 系统监控
│   ├── MetricsGrid         # 指标网格
│   └── RealtimeCharts      # 实时图表
└── SettingsView            # 设置
    ├── WhitelistConfig     # 白名单配置
    └── ScheduleConfig      # 定时任务
```

### 6.2 SwiftUI 组件设计

```swift
// MARK: - 仪表板视图

struct DashboardView: View {
    @StateObject private var scanVM = DiskManagerViewModel()
    @StateObject private var monitorVM = SystemMonitorViewModel()
    @StateObject private var cleanerVM = CacheCleanerViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 磁盘使用概览
                DiskUsageCard(usage: scanVM.diskUsage)
                    .frame(height: 120)

                // 系统健康评分
                HealthScoreCard(
                    score: monitorVM.healthScore,
                    metrics: monitorVM.metrics
                )
                .frame(height: 100)

                // 快速操作
                QuickActionsCard(
                    scanAction: { scanVM.startScan() },
                    cleanAction: { cleanerVM.scanCaches() },
                    monitorAction: { monitorVM.startMonitoring() }
                )
                .frame(height: 80)

                // 可清理空间预览
                CleanableSpaceCard(
                    spaceToFree: cleanerVM.estimatedSpaceToFree
                )
                .frame(height: 60)
            }
            .padding()
        }
        .navigationTitle("仪表板")
    }
}

// MARK: - 目录树视图

struct DirectoryTreeView: View {
    @State private var rootEntries: [DirectoryEntry] = []
    @State private var expandedPaths: Set<String> = []
    @State private var selectedPath: String?

    var body: some View {
        List(rootEntries, children: \.children) { entry in
            DirectoryRow(entry: entry)
                .onTapGesture {
                    selectedPath = entry.path
                }
                .contextMenu {
                    Button("在 Finder 中显示") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)])
                    }
                    Button("删除") {
                        // 删除操作
                    }
                }
        }
        .listStyle(.sidebar)
    }
}

struct DirectoryRow: View {
    let entry: DirectoryEntry

    var body: some View {
        HStack {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(entry.isDirectory ? .blue : .primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body)
                Text(formatBytes(entry.size))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if entry.isDirectory && !entry.isScanned {
                Spacer()
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
    }
}

// MARK: - 实时监控图表

struct MetricsChartView: View {
    @ObservedObject var viewModel: SystemMonitorViewModel
    let metricType: MetricType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metricType.title)
                .font(.headline)

            GeometryReader { geometry in
                ZStack {
                    // 网格线
                    ForEach(0..<5) { i in
                        Path { path in
                            let y = geometry.size.height * CGFloat(i) / 4
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    }

                    // 数据曲线
                    Path { path in
                        guard let dataPoints = viewModel.dataPoints(for: metricType),
                              !dataPoints.isEmpty else { return }

                        let xStep = geometry.size.width / CGFloat(dataPoints.count - 1)
                        let maxVal = dataPoints.map(\.value).max() ?? 1

                        for (index, point) in dataPoints.enumerated() {
                            let x = CGFloat(index) * xStep
                            let y = geometry.size.height * (1 - point.value / maxVal)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(metricType.color, lineWidth: 2)
                }
            }
            .frame(height: 100)

            // 当前值
            Text(viewModel.currentValue(for: metricType))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(metricType.color)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

enum MetricType {
    case cpu, memory, disk, network

    var title: String {
        switch self {
        case .cpu: return "CPU 使用率"
        case .memory: return "内存使用"
        case .disk: return "磁盘 I/O"
        case .network: return "网络流量"
        }
    }

    var color: Color {
        switch self {
        case .cpu: return .blue
        case .memory: return .purple
        case .disk: return .green
        case .network: return .orange
        }
    }
}
```

### 6.3 交互设计

**手势操作**：
- 左右滑动：切换视图
- 长按：显示上下文菜单
- 拖拽：多选文件
- 双指点击：快速预览

**快捷键**：
- `Cmd + Shift + D`: 打开仪表板
- `Cmd + Shift + A`: 开始扫描
- `Cmd + Shift + C`: 清理缓存
- `Space`: 快速预览

---

## 7. 测试策略

### 7.1 单元测试

```swift
import XCTest
@testable import DiskManagerPlugin

class ScanServiceTests: XCTestCase {
    var scanService: ScanService!

    override func setUp() {
        super.setUp()
        scanService = ScanService.shared
    }

    func testDirectoryScanning() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let result = try await scanService.scan(tempDir.path)

        XCTAssertFalse(result.entries.isEmpty)
        XCTAssertGreaterThan(result.totalSize, 0)
        XCTAssertGreaterThan(result.totalFiles, 0)
    }

    func testScanCancellation() async throws {
        let largePath = "/"  // 扫描根目录
        let task = Task {
            try await scanService.scan(largePath)
        }

        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1秒
        task.cancel()

        // 确保任务被取消
    }
}
```

### 7.2 性能测试

```swift
class PerformanceTests: XCTestCase {
    func testScanPerformance() throws {
        let measure = MeasureMetricsBlock()
        measure.startMeasuring()

        // 扫描操作
        // ...

        measure.stopMeasuring()
        XCTAssertLessThan(measure.duration, 5.0)  // 5秒内完成
    }
}
```

### 7.3 UI 测试

```swift
class DiskManagerUITests: XCTestCase {
    func testScanButton() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["扫描大文件"].tap()
        XCTAssertTrue(app.progressViews.firstMatch.exists)
    }
}
```

---

## 附录：依赖与工具

### 必需的 System Frameworks

- `Foundation`: 文件系统操作
- `AppKit`: Finder 交互
- `IOKit`: 系统硬件信息
- `os.log`: 日志记录
- `Combine`: 响应式编程

### 推荐的 Swift Packages

```
// Package.swift
dependencies: [
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    .package(url: "https://github.com/sindresorhus/Files", from: "2.0.0"),
]
```

### 开发工具

- **Instruments**: 性能分析
- **Xcode Profiler**: 内存泄漏检测
- **SwiftLint**: 代码规范
- **SwiftFormat**: 代码格式化

---

**文档版本**: v1.0
**最后更新**: 2025-02-04
**维护者**: @colorfy
