# 日志规范

本文档定义了项目中统一的日志记录标准和最佳实践。

## SuperLog 协议

所有管理器（Manager）、服务（Service）、视图模型（ViewModel）类必须遵循 `SuperLog` 协议，实现统一的日志记录。

### 协议要求

```swift
import OSLog
import MagicKit

class MyClass: SuperLog {
    // 必需：类标识 emoji（用于日志中快速识别）
    nonisolated static let emoji = "🔧"

    // 必需：是否输出详细日志
    nonisolated static let verbose = true
}
```

### 日志格式规范

**标准日志：**

```swift
os_log("\(self.t)操作描述")
```

**错误日志：**

```swift
os_log(.error, "\(self.t)错误描述: \(error.localizedDescription)")
```

**详细日志（仅在 verbose=true 时输出）：**

```swift
if Self.verbose {
    os_log("\(self.t)详细调试信息")
}
```

### 实现示例

#### CacheManager 缓存管理器

```swift
class CacheManager: SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = true

    private init() {
        if Self.verbose {
            os_log("\(self.t)缓存管理器已初始化")
        }
    }

    func getCachedApp(at path: String, currentModificationDate: Date) -> AppCacheItem? {
        guard let item = cache[path] else {
            stats.missCount += 1
            if Self.verbose {
                os_log("\(self.t)缓存未命中: \(path.components(separatedBy: "/").last ?? path)")
            }
            return nil
        }

        // 验证时间戳（允许 1 秒内的误差）
        if abs(item.lastModified - currentModificationDate.timeIntervalSince1970) < 1.0 {
            stats.hitCount += 1
            if Self.verbose {
                os_log("\(self.t)缓存命中: \(item.name)")
            }
            return item
        } else {
            stats.missCount += 1
            if Self.verbose {
                os_log("\(self.t)缓存已过期: \(item.name)，正在移除")
            }
            cache.removeValue(forKey: path)
            return nil
        }
    }
}
```

#### AppService 应用服务

```swift
class AppService: SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = true

    func uninstallApp(_ app: AppModel) async throws {
        os_log("\(self.t)准备卸载应用: \(app.displayName)")

        guard fileManager.fileExists(atPath: appPath) else {
            os_log(.error, "\(self.t)应用不存在: \(appPath)")
            throw AppError.appNotFound
        }

        guard fileManager.isWritableFile(atPath: appPath) else {
            os_log(.error, "\(self.t)权限不足: \(appPath)")
            throw AppError.permissionDenied
        }

        try fileManager.trashItem(at: app.bundleURL, resultingItemURL: nil)
        os_log("\(self.t)应用已移至废纸篓: \(app.displayName)")
    }
}
```

#### AppManagerViewModel 视图模型

```swift
@MainActor
class AppManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = true

    func loadFromCache() async {
        let apps = await appService.scanInstalledApps(force: false)
        if !apps.isEmpty {
            installedApps = apps
            if Self.verbose {
                os_log("\(self.t)从缓存加载了 \(apps.count) 个应用")
            }
        }
    }

    func scanApps(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let apps = await appService.scanInstalledApps(force: force)
            installedApps = apps
            if Self.verbose {
                os_log("\(self.t)应用列表已加载: \(self.installedApps.count) 个应用")
            }
        } catch {
            os_log(.error, "\(self.t)扫描失败: \(error.localizedDescription)")
            errorMessage = "扫描失败: \(error.localizedDescription)"
        }
    }
}
```

#### CaffeinateManager 防休眠管理器

```swift
@Observable
class CaffeinateManager: SuperLog {
    nonisolated static let emoji = "🍽️"
    nonisolated static let verbose: Bool = true

    private init() {
        if Self.verbose {
            os_log("\(self.t)防休眠管理器已初始化")
        }
    }

    func activate(mode: SleepMode, duration: TimeInterval = 0) {
        guard !isActive else {
            if Self.verbose {
                os_log("\(self.t)防休眠已激活，忽略重复激活请求")
            }
            return
        }

        // ... 创建电源断言

        if systemResult == kIOReturnSuccess && displayResult == kIOReturnSuccess {
            isActive = true
            if Self.verbose {
                os_log("\(self.t)防休眠已激活，持续时长: \(duration)秒")
            }
        } else {
            if systemResult != kIOReturnSuccess {
                os_log(.error, "\(self.t)创建系统休眠断言失败: \(systemResult)")
            }
            if displayResult != kIOReturnSuccess {
                os_log(.error, "\(self.t)创建显示器休眠断言失败: \(displayResult)")
            }
        }
    }
}
```

### Emoji 选择指南

为不同类型的类选择有意义的 emoji：

| 类别 | Emoji | 示例 |
| ------ | ------- | ------ |
| 缓存管理 | 💾 | CacheManager |
| 服务层 | 📦、🔧、⚙️ | AppService, BrewService |
| 视图模型 | 📋、📊 | AppManagerViewModel |
| 插件主类 | 🎯、⚡、🔌 | CaffeinatePlugin |
| 管理器 | 🍽️、📡 | CaffeinateManager |
| 网络请求 | 🌐、📡 | NetworkManager |
| 数据处理 | 🗃️、📊 | DataManager |

### 最佳实践

1. **所有 Manager/Service/ViewModel 必须遵循 SuperLog**
2. **每个类使用唯一的 emoji 标识**
3. **verbose 默认为 true**
4. **使用 `self.t` 前缀自动添加 emoji 标识**
5. **关键操作始终输出日志（不受 verbose 影响）**
6. **详细调试信息用 `if Self.verbose` 包裹**
7. **错误必须用 `os_log(.error)` 记录**
8. **日志消息使用中文描述**

### 日志输出示例

```
[💾] 缓存管理器已初始化
[💾] 缓存命中: Safari
[💾] 缓存未命中: /Applications/MyApp.app
[📦] 准备卸载应用: Xcode
[📦] 应用已移至废纸篓: Xcode
[📋] 从缓存加载了 150 个应用
[📋] 扫描失败: 权限不足
[🍽️] 防休眠已激活，持续时长: 3600秒
```

### 相关文件

- `MagicKit/Sources/MagicKit/Protocols/SuperLog.swift` - SuperLog 协议定义
- `.claude/SWIFTUI_GUIDE.md` - SwiftUI 项目开发指南
