# StorageComponent 化方案

## 目标

仿照 ProjectComponent/LayoutComponent，把 LumiCore 的"存储"功能抽成 StorageComponent，挂在 LumiCore 上作为显式字段。归拢当前分散在 3 处的存储代码。

## 设计

**StorageComponent 形态**（与 Project/Layout 同构，但不转发 objectWillChange——因为存储无状态）：
- `@MainActor public final class StorageComponent`（不是 ObservableObject，无需观察——dataRootDirectory 是 let 常量，不变）
- 持有 `public let dataRootDirectory: URL`
- 提供 `coreDataDirectory: URL`（computed）+ `pluginDataDirectory(for:) -> URL`（方法）
- 收纳 `LumiCore+Storage.swift` 的 `_directory` / `_sanitizeDirectoryName` 私有 helper（归拢一处，消除分散）

**LumiCore 挂载**：
- 新增 `public let storage: StorageComponent`（init 时创建，dataRootDirectory 传给它）
- 保留 `dataRootDirectory` 字段（转发到 `storage.dataRootDirectory`，或直接保留——因为太多地方读 `lumiCore.dataRootDirectory`，保留字段最省改动）
- 删除 `LumiCore+Storage.swift`（`coreDataDirectory`/`pluginDataDirectory` 改为转发到 `storage`）

**LumiCoreAccessing 协议**：
- 新增 `var storage: StorageComponent { get }`
- 保留 `dataRootDirectory` / `coreDataDirectory` / `pluginDataDirectory(for:)` 作 computed 转发（调用方零改动，与 Project/Layout 当时直接替换不同——存储调用点太多且分散，保留兼容层更稳）

## 改动清单

### 1. 新建 `Packages/LumiCoreKit/Sources/Storage/StorageComponent.swift`
- `@MainActor public final class StorageComponent`
- `public let dataRootDirectory: URL`
- `public var coreDataDirectory: URL`（computed，复用 `_directory(named:"Core")`）
- `public func pluginDataDirectory(for pluginName: String) -> URL`（复用 sanitize + _directory）
- `private static func _directory(named:under:)` + `_sanitizeDirectoryName`（从 LumiCore+Storage.swift 搬来）

### 2. 改 `LumiCore.swift`
- 新增字段 `public let storage: StorageComponent`
- init 内创建：`self.storage = StorageComponent(dataRootDirectory: standardizedRoot)`（在 dataRoot 物化之后）
- 保留 `public let dataRootDirectory: URL`（不动，太多调用方）
- `coreDataDirectory` / `pluginDataDirectory(for:)` 从 `LumiCore+Storage.swift` 改为转发到 `storage`

### 3. 删除 `LumiCore+Storage.swift`
逻辑已并入 StorageComponent。LumiCore 的 `coreDataDirectory`/`pluginDataDirectory(for:)` 改为直接定义在 LumiCore 本体（或一个小 extension），转发到 `storage`。

### 4. 改 `LumiCoreAccessing.swift`
- 新增 `var storage: StorageComponent { get }`
- 保留 `dataRootDirectory` / `coreDataDirectory` / `pluginDataDirectory(for:)`（转发，调用方零改动）

### 5. Preview stub 适配（3 个）
`PreviewLumiCoreStub` 需要新增 `var storage: StorageComponent` 实现。

## 不在范围

- 不动测试（保持既定策略）
- 不改 plugin bootstrap（它们走 `lumiCore.pluginDataDirectory(for:)` 协议方法，转发层保证零改动）
- 不删 `dataRootDirectory` 字段（调用点太多，保留+转发更稳）

## 验证

编译 Lumi scheme 通过。重点确认 plugin bootstrap 读路径不受影响（走的是转发后的 `pluginDataDirectory(for:)`，行为不变）。