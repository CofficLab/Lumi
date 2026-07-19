# LumiKernel 使用指南

## 快速开始

### 1. 创建具体实现

首先，创建一个实现 `StorageProviding` 协议的具体类：

```swift
import Foundation
import LumiKernel

@MainActor
public final class StorageService: StorageProviding {
    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
    }

    public func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent("Plugins/\(pluginID)")
    }

    public func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("Core")
    }
}
```

### 2. 创建服务提供者

创建一个实现 `CoreServiceProvider` 协议的提供者：

```swift
import LumiKernel

@MainActor
public final class StorageServiceProvider: CoreServiceProvider {
    private let storageService: StorageService

    public init(dataRootDirectory: URL) {
        self.storageService = StorageService(dataRootDirectory: dataRootDirectory)
    }

    public var storage: (any StorageProviding)? {
        storageService
    }
}
```

### 3. 注册方式

#### 方式一：通过 bootstrap() 注入（推荐）

```swift
import LumiKernel

// 创建核心
let kernel = LumiKernel()

// 创建服务提供者
let dataRoot = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)
    .first!
    .appendingPathComponent("Lumi")

let storageProvider = StorageServiceProvider(dataRootDirectory: dataRoot)

// 注入服务
try await kernel.bootstrap(with: [storageProvider])

// 使用服务
if let storage = kernel.storage {
    let pluginDir = storage.pluginDataDirectory(for: "my-plugin")
    print("Plugin directory: \(pluginDir.path)")
}
```

#### 方式二：直接注册单个服务

```swift
import LumiKernel

let kernel = LumiKernel()

let storage = StorageService(
    dataRootDirectory: URL(filePath: "/path/to/data")
)

// 直接注册
kernel.registerService(StorageProviding.self, storage)

// 使用服务
if let storage = kernel.storage {
    print("Data root: \(storage.dataRootDirectory.path)")
}
```

### 4. 多个服务同时注入

```swift
import LumiKernel

// 创建多个服务提供者
let storageProvider = StorageServiceProvider(dataRootDirectory: dataRoot)
let projectProvider = ProjectServiceProvider()
let chatProvider = ChatServiceProvider()

// 一次性注入所有服务
try await kernel.bootstrap(with: [
    storageProvider,
    projectProvider,
    chatProvider
])

// 访问各种服务
if let storage = kernel.storage {
    print("Storage ready")
}

if let project = kernel.project {
    print("Project ready")
}

if let chat = kernel.chat {
    print("Chat ready")
}
```

### 5. 服务发现和依赖

服务之间可以相互依赖：

```swift
@MainActor
public final class ProjectServiceProvider: CoreServiceProvider {
    private unowned let kernel: LumiKernel

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var project: (any ProjectProviding)? {
        // ProjectService 可能依赖 Storage
        let storage = kernel.storage
        return ProjectService(storage: storage)
    }
}
```

## 插件系统集成

### 在插件中提供服务

```swift
import LumiKernel

public final class MyPlugin: LumiPlugin {
    public static var info: LumiPluginInfo {
        LumiPluginInfo(
            id: "com.example.my-plugin",
            name: "My Plugin",
            version: "1.0.0"
        )
    }

    // 扩展：提供核心服务
    public static func provideServices() -> [any CoreServiceProvider] {
        [MyPluginServiceProvider()]
    }
}

@MainActor
private final class MyPluginServiceProvider: CoreServiceProvider {
    public var storage: (any StorageProviding)? {
        MyPluginStorageService()
    }
}
```

### 应用启动时收集插件服务

```swift
import LumiKernel

func bootstrapApp() async throws {
    let kernel = LumiKernel()

    // 1. 收集应用内置服务
    var providers: [any CoreServiceProvider] = [
        StorageServiceProvider(dataRootDirectory: dataRoot),
        ProjectServiceProvider()
    ]

    // 2. 收集插件提供的服务
    for plugin in pluginRegistry.plugins {
        if let pluginProviders = plugin.provideServices?() {
            providers.append(contentsOf: pluginProviders)
        }
    }

    // 3. 一次性注入所有服务
    try await kernel.bootstrap(with: providers)
}
```

## 测试和 Mock

### 创建 Mock 服务

```swift
import LumiKernel

@MainActor
final class MockStorageService: StorageProviding {
    var dataRootDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent("Plugins/\(pluginID)")
    }

    func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("Core")
    }
}
```

### 在测试中使用

```swift
import Testing
@testable import LumiKernel

@Suite("My Tests")
@MainActor
struct MyTests {
    @Test("Test with mock storage")
    func testWithMockStorage() async throws {
        let kernel = LumiKernel()

        // 注入 Mock 服务
        let mockStorage = MockStorageService()
        kernel.registerService(StorageProviding.self, mockStorage)

        // 测试代码...
        #expect(kernel.storage != nil)
    }
}
```

## 最佳实践

### 1. 服务生命周期

- **单例服务**: 大多数核心服务应该是单例
- **懒加载**: 在 provider 中懒加载服务实例
- **线程安全**: 使用 `@MainActor` 确保线程安全

### 2. 错误处理

```swift
public var storage: (any StorageProviding)? {
    do {
        return try StorageService(dataRootDirectory: dataRoot)
    } catch {
        print("Failed to create storage service: \(error)")
        return nil
    }
}
```

### 3. 依赖检查

```swift
func someFunction() throws {
    guard let storage = kernel.storage else {
        throw NSError(domain: "LumiKernel", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Storage service not available"])
    }

    // 使用 storage...
}
```

### 4. 服务优先级

如果多个插件提供相同服务，后注册的会覆盖先注册的：

```swift
// 第一个 storage 服务
kernel.registerService(StorageProviding.self, storage1)

// 会被第二个覆盖
kernel.registerService(StorageProviding.self, storage2)

// kernel.storage 现在是 storage2
```

## 架构优势

1. **解耦**: 核心不依赖具体实现
2. **可测试**: 轻松 mock 服务
3. **可扩展**: 新功能通过插件添加
4. **灵活**: 可以替换具体实现
5. **清晰**: 依赖关系明确

## 完整示例

查看 `Examples/` 目录中的完整示例代码。