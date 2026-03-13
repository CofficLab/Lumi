# 改进建议：性能优化与资源管理

**参考产品**: Cursor, VS Code, Xcode  
**优先级**: 🟢 低  
**影响范围**: 全局性能

---

## 背景

高性能是优秀开发工具的基础。Cursor 和 VS Code 都非常注重性能优化：

- 快速启动时间
- 低内存占用
- 流畅的 UI 响应
- 智能资源管理
- 后台任务优化

当前 Lumi 作为 macOS 应用，需要关注这些性能指标。

---

## 改进方案

### 1. 启动优化

```swift
/// 应用启动管理器
class LaunchManager {
    /// 启动阶段
    enum LaunchPhase: Int, Comparable {
        case preInit = 0      // 预初始化
        case critical = 1     // 关键服务
        case essential = 2    // 必要服务
        case deferred = 3     // 延迟加载
        
        static func < (lhs: LaunchPhase, rhs: LaunchPhase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    /// 启动任务
    struct LaunchTask {
        let name: String
        let phase: LaunchPhase
        let priority: TaskPriority
        let action: @Sendable () async throws -> Void
    }
    
    private var tasks: [LaunchTask] = []
    private var startTime: Date?
    
    /// 注册启动任务
    func register(
        name: String,
        phase: LaunchPhase,
        priority: TaskPriority = .userInitiated,
        action: @escaping @Sendable () async throws -> Void
    ) {
        tasks.append(LaunchTask(
            name: name,
            phase: phase,
            priority: priority,
            action: action
        ))
    }
    
    /// 执行启动
    func launch() async throws {
        startTime = Date()
        
        // 按阶段分组
        let grouped = Dictionary(grouping: tasks) { $0.phase }
        
        // 依次执行各阶段
        for phase in [LaunchPhase.preInit, .critical, .essential] {
            let phaseTasks = grouped[phase] ?? []
            
            // 并行执行同阶段任务
            try await withThrowingTaskGroup(of: Void.self) { group in
                for task in phaseTasks {
                    group.addTask(priority: task.priority) {
                        let taskStart = Date()
                        try await task.action()
                        let duration = Date().timeIntervalSince(taskStart)
                        os_log(.info, "Launch task '%{public}@' completed in %.2fs", task.name, duration)
                    }
                }
                
                try await group.waitForAll()
            }
        }
        
        // 延迟任务在后台执行
        Task(priority: .background) {
            for task in grouped[.deferred] ?? [] {
                try? await task.action()
            }
        }
        
        let totalDuration = Date().timeIntervalSince(startTime!)
        os_log(.info, "App launched in %.2fs", totalDuration)
    }
    
    /// 获取启动统计
    func getLaunchStats() -> LaunchStats {
        LaunchStats(
            totalDuration: Date().timeIntervalSince(startTime ?? Date()),
            taskCount: tasks.count
        )
    }
}

/// 启动统计
struct LaunchStats {
    let totalDuration: TimeInterval
    let taskCount: Int
}
```

---

### 2. 内存管理

```swift
/// 内存管理器
class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    
    @Published private(set) var memoryUsage: UInt64 = 0
    @Published private(set) var memoryPressure: MemoryPressure = .normal
    
    private var timer: Timer?
    
    enum MemoryPressure {
        case normal
        case warning
        case critical
    }
    
    /// 开始监控
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryStats()
            }
        }
    }
    
    /// 停止监控
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 更新内存统计
    private func updateMemoryStats() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            memoryUsage = info.resident_size
            
            // 计算内存压力
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let usedRatio = Double(memoryUsage) / Double(totalMemory)
            
            if usedRatio > 0.8 {
                memoryPressure = .critical
            } else if usedRatio > 0.6 {
                memoryPressure = .warning
            } else {
                memoryPressure = .normal
            }
            
            // 内存压力大时触发清理
            if memoryPressure != .normal {
                Task {
                    await performMemoryCleanup()
                }
            }
        }
    }
    
    /// 执行内存清理
    private func performMemoryCleanup() async {
        // 1. 清理缓存
        await CacheManager.shared.clearExpired()
        
        // 2. 释放未使用的资源
        await ResourceManager.shared.releaseUnused()
        
        // 3. 压缩数据结构
        await DataCompressor.shared.compress()
        
        os_log(.info, "Memory cleanup performed. Current usage: %llu MB", memoryUsage / 1024 / 1024)
    }
    
    /// 格式化内存使用
    var formattedMemoryUsage: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
    }
}
```

---

### 3. 缓存策略

```swift
/// 智能缓存管理器
actor CacheManager {
    static let shared = CacheManager()
    
    private var caches: [String: any CacheProtocol] = [:]
    private let maxTotalSize: Int64 = 500 * 1024 * 1024 // 500MB
    
    /// 注册缓存
    func register<T: CacheProtocol>(_ cache: T, for key: String) {
        caches[key] = cache
    }
    
    /// 清理过期缓存
    func clearExpired() async {
        for cache in caches.values {
            await cache.clearExpired()
        }
    }
    
    /// 清理所有缓存
    func clearAll() async {
        for cache in caches.values {
            await cache.clear()
        }
    }
    
    /// 获取缓存统计
    func getStats() async -> CacheStats {
        var totalSize: Int64 = 0
        var totalItems = 0
        
        for cache in caches.values {
            totalSize += await cache.totalSize
            totalItems += await cache.itemCount
        }
        
        return CacheStats(
            totalSize: totalSize,
            totalItems: totalItems,
            caches: await getCachesStats()
        )
    }
    
    /// 智能清理（基于访问频率和时间）
    func intelligentCleanup() async {
        let stats = await getStats()
        
        if stats.totalSize > maxTotalSize {
            // 计算需要清理的大小
            let targetSize = Int64(Double(maxTotalSize) * 0.8)
            let sizeToFree = stats.totalSize - targetSize
            
            // 按优先级清理
            var freed: Int64 = 0
            
            // 1. 首先清理最久未访问的
            for (key, cache) in caches {
                if freed >= sizeToFree { break }
                freed += await cache.evictLeastRecentlyUsed(targetSize: sizeToFree - freed)
            }
            
            // 2. 如果还不够，清理低优先级缓存
            if freed < sizeToFree {
                for (key, cache) in caches where cache.priority == .low {
                    if freed >= sizeToFree { break }
                    let size = await cache.totalSize
                    await cache.clear()
                    freed += size
                }
            }
        }
    }
}

/// 缓存协议
protocol CacheProtocol: Actor {
    var priority: CachePriority { get }
    var totalSize: Int64 { get async }
    var itemCount: Int { get async }
    
    func clear() async
    func clearExpired() async
    func evictLeastRecentlyUsed(targetSize: Int64) async -> Int64
}

/// 缓存优先级
enum CachePriority {
    case high
    case medium
    case low
}

/// 缓存统计
struct CacheStats {
    let totalSize: Int64
    let totalItems: Int
    let caches: [String: CacheInfo]
}

/// 缓存信息
struct CacheInfo {
    let name: String
    let size: Int64
    let itemCount: Int
}
```

---

### 4. 后台任务管理

```swift
/// 后台任务管理器
class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private var tasks: [String: BackgroundTask] = [:]
    private let maxConcurrentTasks = 3
    
    /// 后台任务定义
    struct BackgroundTask {
        let id: String
        let name: String
        let priority: TaskPriority
        let interval: TimeInterval?
        let action: @Sendable () async throws -> Void
        
        var task: Task<Void, Error>?
    }
    
    /// 启动后台任务
    func startTask(
        id: String,
        name: String,
        priority: TaskPriority = .background,
        interval: TimeInterval? = nil,
        action: @escaping @Sendable () async throws -> Void
    ) {
        let task = BackgroundTask(
            id: id,
            name: name,
            priority: priority,
            interval: interval,
            action: action
        )
        
        tasks[id] = task
        
        if let interval = interval {
            // 周期性任务
            startPeriodicTask(task, interval: interval)
        } else {
            // 一次性任务
            startOneTimeTask(task)
        }
    }
    
    /// 启动周期性任务
    private func startPeriodicTask(_ task: BackgroundTask, interval: TimeInterval) {
        tasks[task.id]?.task = Task(priority: task.priority) {
            while !Task.isCancelled {
                do {
                    try await task.action()
                } catch {
                    os_log(.error, "Background task '%{public}@' failed: %{public}@", task.name, error.localizedDescription)
                }
                
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
    
    /// 启动一次性任务
    private func startOneTimeTask(_ task: BackgroundTask) {
        tasks[task.id]?.task = Task(priority: task.priority) {
            do {
                try await task.action()
            } catch {
                os_log(.error, "Background task '%{public}@' failed: %{public}@", task.name, error.localizedDescription)
            }
            tasks.removeValue(forKey: task.id)
        }
    }
    
    /// 停止任务
    func stopTask(id: String) {
        tasks[id]?.task?.cancel()
        tasks.removeValue(forKey: id)
    }
    
    /// 停止所有任务
    func stopAll() {
        for task in tasks.values {
            task.task?.cancel()
        }
        tasks.removeAll()
    }
    
    /// 暂停任务（低电量/低内存时）
    func pauseNonEssentialTasks() {
        for task in tasks.values where task.priority == .background {
            task.task?.cancel()
        }
    }
}
```

---

### 5. 性能监控

```swift
/// 性能监控器
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published private(set) var metrics: PerformanceMetrics = PerformanceMetrics()
    
    private var samples: [PerformanceSample] = []
    private let maxSamples = 1000
    
    struct PerformanceMetrics {
        var cpuUsage: Double = 0
        var memoryUsage: UInt64 = 0
        var diskUsage: Int64 = 0
        var networkBytesIn: UInt64 = 0
        var networkBytesOut: UInt64 = 0
        var frameRate: Double = 60
        var launchTime: TimeInterval = 0
        var responsiveness: Responsiveness = .excellent
        
        enum Responsiveness {
            case excellent  // < 50ms
            case good       // < 100ms
            case fair       // < 200ms
            case poor       // >= 200ms
        }
    }
    
    struct PerformanceSample {
        let timestamp: Date
        let cpuUsage: Double
        let memoryUsage: UInt64
        let frameTime: TimeInterval
    }
    
    /// 开始监控
    func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.collectSample()
            }
        }
    }
    
    /// 收集样本
    private func collectSample() {
        let cpu = getCPUUsage()
        let memory = getMemoryUsage()
        let frameTime = measureFrameTime()
        
        let sample = PerformanceSample(
            timestamp: Date(),
            cpuUsage: cpu,
            memoryUsage: memory,
            frameTime: frameTime
        )
        
        samples.append(sample)
        
        // 保持样本数量
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        
        // 更新指标
        updateMetrics(sample: sample)
    }
    
    /// 更新指标
    private func updateMetrics(sample: PerformanceSample) {
        metrics.cpuUsage = sample.cpuUsage
        metrics.memoryUsage = sample.memoryUsage
        
        // 计算响应性
        let frameTimeMs = sample.frameTime * 1000
        if frameTimeMs < 16 { // 60fps
            metrics.responsiveness = .excellent
        } else if frameTimeMs < 33 { // 30fps
            metrics.responsiveness = .good
        } else if frameTimeMs < 100 {
            metrics.responsiveness = .fair
        } else {
            metrics.responsiveness = .poor
        }
        
        // 发送性能警告
        if metrics.cpuUsage > 80 || metrics.memoryUsage > 500_000_000 {
            NotificationCenter.default.post(name: .performanceWarning, object: nil)
        }
    }
    
    /// 获取 CPU 使用率
    private func getCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threads = threadList else {
            return 0
        }
        
        var totalUsage: Double = 0
        
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let kr = withUnsafePointer(to: &threads[i]) { thread in
                thread_info(thread.pointee, thread_flavor_t(THREAD_BASIC_INFO), &info, &count)
            }
            
            if kr == KERN_SUCCESS && info.flags & TH_FLAGS_IDLE == 0 {
                totalUsage += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100
            }
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride))
        
        return totalUsage
    }
    
    /// 获取内存使用
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    /// 测量帧时间
    private func measureFrameTime() -> TimeInterval {
        // 使用 CADisplayLink 或类似机制测量
        // 简化实现
        return 1.0 / 60.0
    }
}
```

---

### 6. 延迟加载机制

```swift
/// 延迟加载管理器
class LazyLoader {
    /// 延迟加载的资源
    private var resources: [String: LazyResource] = [:]
    
    struct LazyResource {
        let key: String
        let loadAction: @Sendable () async throws -> Any
        var loadedValue: Any?
        var isLoaded: Bool = false
        var lastAccessed: Date?
        var accessCount: Int = 0
    }
    
    /// 注册延迟加载资源
    func register<T>(
        key: String,
        loadAction: @escaping @Sendable () async throws -> T
    ) {
        resources[key] = LazyResource(
            key: key,
            loadAction: loadAction
        )
    }
    
    /// 获取资源
    func get<T>(_ key: String) async throws -> T {
        guard var resource = resources[key] else {
            throw LazyLoadError.resourceNotFound(key)
        }
        
        resource.lastAccessed = Date()
        resource.accessCount += 1
        
        if !resource.isLoaded {
            resource.loadedValue = try await resource.loadAction()
            resource.isLoaded = true
        }
        
        resources[key] = resource
        
        guard let value = resource.loadedValue as? T else {
            throw LazyLoadError.typeMismatch
        }
        
        return value
    }
    
    /// 预加载资源
    func preload(_ keys: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for key in keys {
                group.addTask {
                    do {
                        _ = try await self.get(key)
                    } catch {
                        os_log(.error, "Failed to preload resource: %{public}@", key)
                    }
                }
            }
        }
    }
    
    /// 卸载未使用的资源
    func unloadUnused(maxIdleTime: TimeInterval = 3600) async {
        let now = Date()
        
        for (key, resource) in resources {
            if let lastAccessed = resource.lastAccessed,
               now.timeIntervalSince(lastAccessed) > maxIdleTime,
               resource.accessCount < 3 { // 低访问频率
                resources[key]?.loadedValue = nil
                resources[key]?.isLoaded = false
                os_log(.info, "Unloaded unused resource: %{public}@", key)
            }
        }
    }
}

enum LazyLoadError: Error {
    case resourceNotFound(String)
    case typeMismatch
}
```

---

## 实施计划

### 阶段 1: 基础监控 (1 周)
1. 实现启动管理器
2. 实现内存监控
3. 添加性能指标收集

### 阶段 2: 缓存优化 (1 周)
1. 实现智能缓存系统
2. 实现缓存清理策略
3. 优化缓存命中率

### 阶段 3: 高级优化 (1 周)
1. 实现后台任务管理
2. 实现延迟加载
3. 添加性能分析工具

---

## 预期效果

1. **启动时间**: 从冷启动到可用 < 2 秒
2. **内存占用**: 正常使用 < 200MB
3. **CPU 使用**: 空闲时 < 5%
4. **响应时间**: UI 操作响应 < 50ms
5. **流畅度**: 保持 60fps

---

## 参考资源

- [App Startup Time](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance)
- [Memory Usage Performance Guidelines](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/ManagingMemory/)
- [Energy Efficiency Guide](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/)

---

*创建时间: 2026-03-13*