# KernelCore

Lumi 的**最小内核核心**：提供 Provider 注册表与 SuperPlugin 生命周期，
不包含任何具体 Provider。

## 与 KernelLumi 的关系

KernelLumi 是完整内核（含全部核心服务协议与插件系统）；KernelCore 抽出其中
Generic Service Registry 的机制，形成零依赖的通用容器：

| KernelLumi（完整内核） | KernelCore（最小核心） |
| --- | --- |
| `registerService(_:_:)` | `registerProvider(_:_:)` |
| `resolveService(_:)` | `resolveProvider(_:)` |
| `unregisterService(_:)` | `unregisterProvider(_:)` |
| `isServiceRegistered(_:)` | `isProviderRegistered(_:)` |
| 定义 13+ 个核心服务协议（StorageProviding 等） | **不定义任何具体 Provider** |

## 设计理念

1. **不含具体 Provider** — KernelCore 不知道任何 `XxxProviding` 协议，由上层声明、插件注入。
2. **泛型注册表** — `[ObjectIdentifier: Any]`，按协议类型注册/解析，类型安全。
3. **依赖反转** — 内核只持有协议类型，不依赖具体实现。
4. **零外部依赖** — 仅使用 Foundation + Combine。
5. **对象变化转发** — 默认把 Provider 的 `objectWillChange` 转发到容器；高频变更的
   Provider 可关闭转发改为窄播订阅。
6. **原子插件启动** — 显式依赖拓扑排序，Boot/Ready 两阶段启动，失败自动逆序回滚。
7. **完整退出路径** — Shutdown、单插件卸载、插件所有 Provider 的自动清理。

## 使用方式

```swift
// 1. 创建最小核心
let core = KernelCore()

// 2. 上层声明 Provider 协议（不属于 KernelCore）
protocol StorageProviding: AnyObject { /* ... */ }
protocol ProjectProviding: AnyObject { /* ... */ }

// 3. 插件注入实现（通过注册方法，简单明了）
try core.registerProvider(StorageProviding.self, StorageService())
try core.registerProvider(ProjectProviding.self, ProjectService())

// 4. 使用 Provider（通过协议）
if let storage = core.resolveProvider(StorageProviding.self) {
    let pluginDir = storage.pluginDataDirectory(for: "my-plugin")
}

// 5. 生命周期
core.unregisterProvider(ProjectProviding.self)
```

## 插件生命周期

```swift
final class FeaturePlugin: SuperPlugin {
    let id = "com.example.feature"
    let dependencies = ["com.example.foundation"]

    func onBoot(kernel: KernelCoreContainer) throws {
        // 注册自身 Provider 与共享 Provider 贡献
    }

    func onReady(kernel: KernelCoreContainer) throws {
        // 此时全部插件均已完成 Boot，可解析跨插件能力
    }

    func onShutdown(kernel: KernelCoreContainer) throws {
        // 撤回写入共享 Provider 的贡献；自身注册的 Provider 由 Kernel 自动移除
    }
}

try core.start(plugins: plugins)
try core.unloadPlugin(id: "com.example.feature")
try core.stop()
```

`dependencies` 表达硬依赖，`order` 仅作为同一依赖层级的排序偏好。
启动前会完整校验重复 id、缺失依赖与依赖环。任一 Boot/Ready 失败时，
本批插件不会残留在可用内核中。

## 完整示例

见 [Examples/DirectUsageExample.swift](Examples/DirectUsageExample.swift)。

## 优势

1. **最小** — 真正的核心层，零依赖
2. **可测试** — 可以轻松 mock Provider
3. **可扩展** — 新能力通过注册方法添加
4. **解耦** — 核心层不依赖具体实现
5. **通用** — 任何宿主（KernelLumi / 单用途 App）都可复用
