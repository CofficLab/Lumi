# Issue #014: TaskGroup 取消与错误传播机制缺失（Critical）

## 📋 问题概述

项目中多个关键服务使用 `withTaskGroup` 进行并行任务处理，但**没有正确实现取消传播和错误处理机制**，导致：

- 无法响应用户取消操作
- 部分任务失败时结果不一致
- 潜在的资源泄漏
- 后台任务变成"孤儿任务"继续运行

这是并发编程中最危险的缺陷之一，可能导致应用行为不可预测。

---

## 🔴 严重程度：Critical (最高级别)

**风险等级**: ⚠️ 可能导致：
- 用户无法取消长时间运行的操作
- 数据不一致（部分成功/部分失败）
- 内存和 CPU 资源浪费
- 应用响应性下降
- 文件系统操作可能处于中间状态

**优先级**: P0 - 需要立即修复

---

## 📍 问题位置汇总

| # | 文件路径 | 方法 | TaskGroup 类型 | 风险级别 |
|---|----------|------|---------------|----------|
| 1 | `LumiApp/Plugins/DiskManagerPlugin/Services/CacheCleanerService.swift` | `scanCaches()` | `CacheCategory?` | 🔴 高 |
| 2 | `LumiApp/Plugins/DiskManagerPlugin/ViewModels/XcodeCleanerViewModel.swift` | `scanXcodeItems()` | `(XcodeCleanCategory, [XcodeCleanItem])` | 🔴 高 |
| 3 | `LumiApp/Plugins/DiskManagerPlugin/Services/CacheCleanerService.swift` | `cleanup()` | 无返回值 | 🔴 高 |
| 4 | `LumiApp/Plugins/DiskManagerPlugin/Services/ProjectCleanerService.swift` | `scanProjects()` | `[ProjectInfo]` | 🟠 中 |
| 5 | `LumiApp/Plugins/DiskManagerPlugin/Services/DiskService.swift` | `scanLargeFiles()` | `(DirectoryEntry?, [LargeFileEntry])` | 🟠 中 |
| 6 | `LumiApp/Plugins/AppManagerPlugin/AppService.swift` | `findRelatedFiles()` | `RelatedFile?` | 🟡 低 |

---

## 🐛 问题分析

### 问题模式 1: TaskGroup 错误被静默吞噬

**典型代码** (CacheCleanerService.swift:58-75):

```swift
func scanCaches() async {
    isScanning = true
    scanProgress = String(localized: "Initializing...")

    let rules = scanRules
    let results = await withTaskGroup(of: CacheCategory?.self, returning: [CacheCategory].self) { group in
        for rule in rules {
            group.addTask(priority: .utility) {
                await Self.scanCategory(rule: rule)
            }
        }

        var categories: [CacheCategory] = []
        for await category in group {
            if let category {
                categories.append(category)
            }
        }
        return categories
    }

    categories = results.sorted { $0.safetyLevel < $1.safetyLevel }
    isScanning = false
    scanProgress = ""
}
```

**❌ 问题分析**:

```swift
// 问题 1: 子任务抛出错误时被静默吞噬
group.addTask(priority: .utility) {
    await Self.scanCategory(rule: rule)  // 如果这里抛出错误怎么办？
}

// 问题 2: 没有检查 Task.isCancelled
private static func scanCategory(rule: CacheScanRule) async -> CacheCategory? {
    // 没有检查取消状态
    // 即使用户取消操作，任务仍会继续运行
}

// 问题 3: 错误不会传播到调用方
// 调用 scanCaches() 的代码无法知道扫描是否部分失败
```

### 问题模式 2: Task.detached 取消链断裂

**典型代码** (CacheCleanerService.swift:78-93):

```swift
func cleanup(paths: [CachePath]) async throws -> Int64 {
    let freedSpace = await Task.detached(priority: .utility) {
        var total: Int64 = 0
        let fileManager = FileManager.default
        for item in paths {
            do {
                try fileManager.removeItem(atPath: item.path)
                total += item.size
            } catch {
                os_log(.error, "\(Self.t)Cleanup failed: \(item.path) - \(error.localizedDescription)")
            }
        }
        return total
    }.value

    await scanCaches()
    return freedSpace
}
```

**❌ 问题分析**:

```swift
// 问题 1: Task.detached 与父任务取消链断裂
Task.detached(priority: .utility) {
    // 即使调用方取消了，这个任务仍会继续运行
    // 可能导致删除操作在用户取消后仍然执行
}

// 问题 2: 错误被局部捕获但不影响整体结果
// 部分文件删除失败，但返回值仍然被使用
```

### 问题模式 3: 部分失败导致数据不一致

**典型代码** (DiskService.swift):

```swift
await withTaskGroup(of: (DirectoryEntry?, [LargeFileEntry]).self) { group in
    for directory in directories {
        group.addTask {
            // 如果某个目录扫描失败，整个结果可能不一致
            await self.scanDirectory(directory)
        }
    }
    
    var allFiles: [LargeFileEntry] = []
    for await (_, files) in group {
        allFiles.append(contentsOf: files)  // 部分失败的数据被合并
    }
    return allFiles
}
```

---

## ⚠️ 为什么这是严重问题？

### 1. 取消链断裂示意

```
用户点击"取消"
    ↓
主任务被取消
    ↓
Task.detached 任务继续运行 ❌
    ↓
文件删除操作在后台继续
    ↓
用户看到取消成功，但数据已被修改
```

### 2. 错误传播缺失

```
scanCaches() 被调用
    ↓
10 个扫描任务并行执行
    ↓
3 个任务抛出错误（权限不足/路径不存在）
    ↓
错误被静默吞噬
    ↓
返回 7 个成功的结果
    ↓
调用方不知道有 3 个失败 ❌
```

### 3. 资源泄漏风险

```
withTaskGroup 开始
    ↓
添加 20 个子任务
    ↓
父任务因错误提前退出
    ↓
子任务仍在运行（没有检查 Task.isCancelled）
    ↓
CPU/内存持续占用
```

---

## ✅ 修复方案

### 方案 1: 正确的 TaskGroup 取消与错误处理

```swift
func scanCaches() async throws {
    isScanning = true
    scanProgress = String(localized: "Initializing...")

    defer {
        isScanning = false
        scanProgress = ""
    }

    let rules = scanRules
    
    do {
        let results = try await withThrowingTaskGroup(
            of: CacheCategory?.self,
            returning: [CacheCategory].self
        ) { group in
            for rule in rules {
                group.addTask(priority: .utility) { [weak self] in
                    // ✅ 检查取消状态
                    try Task.checkCancellation()
                    
                    guard let self else { return nil }
                    return try await self.scanCategoryWithCancellation(rule: rule)
                }
            }

            var categories: [CacheCategory] = []
            for try await category in group {
                // ✅ 每次迭代检查取消
                try Task.checkCancellation()
                
                if let category {
                    categories.append(category)
                }
            }
            return categories
        }

        categories = results.sorted { $0.safetyLevel < $1.safetyLevel }
        
    } catch is CancellationError {
        // ✅ 正确处理取消
        os_log(.info, "\(Self.t)扫描已取消")
        throw CancellationError()
    } catch {
        // ✅ 错误传播到调用方
        os_log(.error, "\(Self.t)扫描失败：\(error)")
        throw error
    }
}

// ✅ 支持取消的扫描方法
private func scanCategoryWithCancellation(rule: CacheScanRule) async throws -> CacheCategory? {
    try Task.checkCancellation()
    
    // 扫描逻辑...
    
    // 在长时间循环中定期检查取消
    for path in rule.paths {
        try Task.checkCancellation()
        // 处理路径...
    }
    
    return category
}
```

### 方案 2: 使用 Task 而非 Task.detached（保持取消链）

```swift
func cleanup(paths: [CachePath]) async throws -> Int64 {
    // ✅ 使用普通 Task 保持取消链
    let freedSpace = try await withTaskGroup(of: Int64.self, returning: Int64.self) { group in
        var total: Int64 = 0
        
        for item in paths {
            group.addTask(priority: .utility) { [item] in
                // ✅ 检查取消
                try Task.checkCancellation()
                
                do {
                    try FileManager.default.removeItem(atPath: item.path)
                    return item.size
                } catch {
                    // ✅ 重新抛出错误，让调用方决定如何处理
                    throw error
                }
            }
        }
        
        for try await size in group {
            total += size
        }
        return total
    }

    await scanCaches()
    return freedSpace
}
```

### 方案 3: 部分失败时的错误聚合

```swift
struct PartialFailureError: Error {
    let successfulCount: Int
    let failedCount: Int
    let errors: [Error]
}

func scanCaches() async throws -> [CacheCategory] {
    let rules = scanRules
    
    var successes: [CacheCategory] = []
    var failures: [(rule: CacheScanRule, error: Error)] = []
    
    try await withThrowingTaskGroup(of: Void.self) { group in
        for rule in rules {
            group.addTask {
                do {
                    let category = try await self.scanCategoryWithCancellation(rule: rule)
                    if let category {
                        successes.append(category)
                    }
                } catch {
                    failures.append((rule, error))
                }
            }
        }
    }
    
    // ✅ 如果有失败，抛出聚合错误
    if !failures.isEmpty {
        throw PartialFailureError(
            successfulCount: successes.count,
            failedCount: failures.count,
            errors: failures.map { $0.error }
        )
    }
    
    return successes.sorted { $0.safetyLevel < $1.safetyLevel }
}
```

---

## 📝 检查清单

### 代码审计要点

- [ ] 所有 `withTaskGroup` 改为 `withThrowingTaskGroup`
- [ ] 所有 `Task.detached` 评估是否可以改用普通 `Task`
- [ ] 每个 `addTask` 闭包开头添加 `try Task.checkCancellation()`
- [ ] 在 `for await` 循环中定期检查取消
- [ ] 长时间运行的操作分解为可取消的小步骤
- [ ] 错误要么重新抛出，要么记录并聚合
- [ ] 调用方能够感知部分失败

### 测试场景

- [ ] 用户取消操作时，所有子任务立即停止
- [ ] 部分任务失败时，调用方能获得错误信息
- [ ] 资源（文件句柄、内存）在取消时正确释放
- [ ] 没有孤儿任务在后台继续运行

---

## 🔗 相关问题

- **Issue #002**: @unchecked Sendable 并发安全 - 并发安全基础问题
- **Issue #003**: TurnContexts 内存泄漏 - Task 未正确取消导致
- **Issue #010**: Coordinator Task 泄漏 - Task 生命周期管理问题

---

## 📚 参考资源

- [Apple Developer: TaskGroup](https://developer.apple.com/documentation/swift/taskgroup)
- [Apple Developer: withThrowingTaskGroup](https://developer.apple.com/documentation/swift/withthrowingtaskgroupof:returning:operation:)
- [Swift Concurrency: Cancellation](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [WWDC21: Explore Structured Concurrency](https://developer.apple.com/videos/play/wwdc2021/10134/)

---

## 📊 修复估算

| 阶段 | 工作量 | 风险 |
|------|--------|------|
| 审计所有 TaskGroup 使用 | 2 小时 | 低 |
| 修复 CacheCleanerService | 3 小时 | 中 |
| 修复 XcodeCleanerViewModel | 2 小时 | 中 |
| 修复 DiskService | 2 小时 | 中 |
| 添加取消测试 | 4 小时 | 低 |
| **总计** | **13 小时** | - |

---

*最后更新: 2026-03-12*
*发现者: 代码审计*
