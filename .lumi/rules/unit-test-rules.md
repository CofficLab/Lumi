# 单元测试规范

> 本规范定义了 Lumi 项目中单元测试的代码组织、目录结构与**环境隔离**要求。

---

## 核心原则

**测试必须在完全隔离的环境里运行：只读写自己造的数据，绝不触碰本机真实数据。**

这条原则有两个方向，缺一不可：

- **不污染本机** —— 测试不得读写开发者本机的真实数据目录、真实偏好、真实 Keychain。
- **不受本机影响** —— 测试结果不得依赖本机残留的历史数据，否则断言会随机失败。

> 隔离的**目的**不是「每次跑都是空库」，而是「测试只依赖自己造的数据」。
> 因此**不要**去清空本机真实数据库——那会删掉用户数据。正确做法是让测试
> **根本不指向**真实目录。

---

## 目录结构

单元测试放在**各 SPM 包内**的 `Tests/<PackageName>Tests/` 目录中。

```text
Packages/
├── PluginAgentRules/
│   ├── Package.swift              <-- 声明 testTarget
│   ├── Sources/PluginAgentRules/  <-- 生产代码
│   └── Tests/PluginAgentRulesTests/
│       ├── AgentRulesRuntimeDirectoryTests.swift
│       └── ...
└── KitTestSupport/                <-- 测试隔离基建（见下）
    ├── Sources/KitTestSupport/
    └── Tests/KitTestSupportTests/
```

| 类型 | 命名规范 | 示例 |
|------|---------|------|
| 测试目录 | `<PackageName>Tests` | `PluginAgentRulesTests` |
| 测试文件 | `<SourceFileName>Tests.swift` | `AgentRulesRuntimeTests` |
| 测试类型 | `@Suite` / `XCTestCase` | `AgentRulesRuntimeTests` |

- 目录名不必与包名完全一致，但需能看出归属（如 `KitEditorKernel/Tests/EditorKernelTests/`）。
- 新代码优先使用 **Swift Testing**（`import Testing`）；遗留 **XCTest** 可保留，不强制迁移。

### 为什么不在仓库根目录建 `Tests/`

历史上曾约定「测试统一放根目录 `Tests/`」，该约定**已废弃**。实际做法是包内 `Tests/`：

- 单元测试与被测代码同包，`@testable import` 与内部类型访问最直接；
- 包内 `testTarget` 天然随包构建，`swift build --build-tests` 能验证该包测试可编译；
- 避免在 `project.pbxproj` 里维护跨包的 membership 排除列表。

---

## 测试隔离基建：`KitTestSupport`

统一隔离能力集中在 `Packages/KitTestSupport`，**不要**在每个包里各造一份。

该包拆成两个 target，边界依据是「是否会进入生产包」：

| Target | 内容 | 被谁引用 |
|--------|------|---------|
| `KitTestIsolation` | 测试进程判定 + 目录守卫 | 各插件的**生产 target** |
| `KitTestSupport` | 临时目录 / 隔离 UserDefaults / 临时存储 Provider | 各包的 **testTarget** |

两者若合并，测试辅助代码会跟着打进 App；反过来把守卫放进 testTarget，
各插件在生产代码里就无从引用。**边界必须切开。**

### KitTestIsolation

**`TestProcessDetector.isTestProcess`** —— 判断当前进程是否为单元测试进程。

三重判据（缺一不可）：

1. `ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil`（`xcodebuild test`）
2. `Bundle.main.bundlePath.hasSuffix(".xctest")`（`xcodebuild test`）
3. 可执行文件名为 `xctest` 或 `swiftpm-testing-helper`（`swift test`）

> **刻意不用** `NSClassFromString("XCTestCase")`：它在两种方式下都为 true，
> 但无法区分「测试进程」与「为承载 UI 测试而链接了 XCTest 的 Debug App」。
> 误判会让正式 App 把数据写进临时目录——那比测试污染严重得多。

**`IsolatedDirectoryGuard`** —— 目录守卫。插件运行时目录的统一解析方式：

```swift
nonisolated(unsafe) static var injectedSettingsDirectory: URL?

static func settingsDirectory() -> URL {
    IsolatedDirectoryGuard.directory(
        injected: injectedSettingsDirectory,
        owner: "XxxRuntime",
        accessor: "settingsDirectory()",
        fallback: { productionFallbackDirectory }   // 仅生产环境可达
    )
}
```

契约：

- **生产进程**：未注入则回退到真实目录（保留「插件尚未 boot 的极早期访问」这一场景）。
- **测试进程**：未注入则 **`fatalError`**，不返回真实目录。

> 为什么用 `fatalError` 而不是 `throw`：这些访问点在 `static var` 初始化器与
> `onBoot` 里，不在错误可传播的上下文中；而且**静默降级才是真正的危害**。
> 让「忘记注入」在第一次发生时就以明确的错误信息终止，而不是伪装成通过。
> 若某个访问点确实可恢复，用 `IsolatedDirectoryGuard.resolve(...)`（返回
> `Outcome` 而不终止进程）自行处理。

### KitTestSupport

**`TemporaryDirectory`** —— 临时目录，集中创建 + 幂等清理。

```swift
let directory = try TemporaryDirectory.make("conversation-store")
defer { directory.remove() }
```

**`IsolatedUserDefaults`** —— 隔离偏好实例（`suiteName = com.coffic.lumi.test.<prefix>.<UUID>`）。

**`TemporaryStorageProvider`** —— 根落在临时目录的 `StorageProviding`。

> **保留 `db_debug_v6` 命名**很关键：内核的 `allVersionDataRootDirectories`
> 与 `PluginDataMigrationRunner` 都按 `db_debug_v*` 前缀做版本解析，
> 换成任意名字会让这些逻辑在测试中走不到真正的分支。

---

## 规则一：目录必须注入，不得回退真实路径

**插件的运行时目录（数据库、设置、缓存）一律由 `onBoot` 从 `StorageProviding` 注入，
测试进程下未注入即失败。**

```swift
// ✅ 正确
public func onBoot(kernel: KernelCoreContainer) throws {
    if let storage = kernel.resolveProvider((any StorageProviding).self) {
        XxxRuntime.configure(settingsDirectory: storage.pluginDataDirectory(for: id))
    }
}
```

**禁止**在运行时目录的解析路径上直接调用 `FileManager.default.urls(for: .applicationSupportDirectory, ...)`。
这类「存根回退路径」是历史上最大的污染源：测试忘了注入目录时不会失败，
而是安静地读写开发者本机的真实数据目录。失败点漂移到几百行之外的路径拼接，极难归因。

**新增插件运行时目录时的检查清单**：

- [ ] 目录由 `onBoot` 从 `StorageProviding` 注入
- [ ] 回退路径改名为 `productionFallback*`，且**只**经 `IsolatedDirectoryGuard` 可达
- [ ] 生产 target 依赖 `KitTestIsolation`
- [ ] 存在「未注入即拒绝」的守卫用例

### 判据：可达才加守卫

**守卫的价值完全来自「测试进程可达」这一条路径。** 判据因此只有一条：

> **凡测试进程可达的真实数据路径，必须在测试进程里失败。**

这条判据**可验证**：跑一遍测试就知道。不需要人工维护「哪些点该加守卫」的清单——
清单会过期，而且换个人做同样的改动未必会去逐条核查。

**不可达的回退路径不必加守卫。** 加了是净负价值：

- 为一个永不可达的断言，让公共基础包多一个生产依赖；
- 把「不可达的路径」变成「可能终止进程的路径」。

典型的「已核查、确认不可达、无需改造」：

| 位置 | 为什么不可达 |
|------|-------------|
| `PluginFileLog` 的 `fallbackDirectory` | 目录来源是 `directoryOverride ?? FileLogRuntimeBridge.logsDirectory ?? fallback`，测试全部走前两层 |
| `EditorConfigStore` | `static let store` 虽在首次访问固化目录，但测试只调纯函数 `settingsDirectoryURL(...)`，不触达 store |
| `EditorKeybindingStore` | `shared` 首次访问会读真实目录，但测试全部用 `init(bindingsFileURL:)` 显式注入，不碰 `shared` |

> 这三处的结论是**核查后的判断**，不是永久豁免。若将来某个测试开始触达它们，
> 判据自动生效：可达了就必须加守卫或改为显式注入。

---

## 规则二：偏好与 Keychain 必须隔离

`UserDefaults.standard` 是**用户级全局状态**：写入会留到用户下次启动，
用户残留的值又会让断言随机失败。

**禁止**在测试中直接写 `UserDefaults.standard`。

```swift
// ✅ 正确：注入隔离的偏好域
let defaults = UserDefaults(suiteName: "com.coffic.lumi.test.\(UUID().uuidString)")
defer { defaults.removePersistentDomain(forName: suiteName) }
```

**生产代码**若必须读写真实偏好域，须做成可注入：

```swift
// KeychainStore
public init(service: String, ..., legacyUserDefaults: UserDefaults = .standard)

// LLM 管理器
nonisolated(unsafe) public static var legacyUserDefaults: UserDefaults = .standard
```

Keychain 同理：测试必须注入 **Stub backend**，不得写真实 Keychain 条目。
（`KitLLM` 的 `VendorAPIKeyTools` 已有测试进程下的 service 重定向兜底，可参考。）

---

## 规则三：进程级单例要有 reset 契约

进程级单例（`static let shared`）的状态会跨用例残留。后注册的观察者会收到
**前一个用例**留下的通知，计数断言随之漂移——这类失败极难复现。

**凡测试会触碰的单例，都必须提供清理入口**：

| 已有 | 形式 |
|------|------|
| `CADDocumentStore` / `IconDocumentStore` | `resetForTests()` |
| `CommandRegistry` | `clear()` |
| `LanguageRegistry` / `LanguageQueryRegistry` | `reset()` |
| `HorizontalFittingSizeStore` | `removeAll()` |
| `ClipboardHistoryChangeCenter` | `removeAllObservers()` |
| 各 `*Runtime` | `reset()`（清空注入状态） |

**契约**：测试在触碰单例前后各清理一次。

```swift
let center = ClipboardHistoryChangeCenter.shared
center.removeAllObservers()
defer { center.removeAllObservers() }
```

> **注意 `static let` 的固化时机**：单例在**首次访问**时固定状态。
> 注入必须发生在首次访问之前，且整个进程只注入一次。
> 若用例把注入清成 `nil`，另一个用例随后首次访问单例就会撞上目录守卫，
> 直接终止整个测试进程（signal 5）。

---

## 规则四：测试只依赖自己造的数据

**每个用例自己造数据、自己断言。** 不依赖执行顺序，不依赖其它用例的残留。

- 用例间**不要**通过共享单例隐式传数据。
- 共享单例的场景，标注 `.serialized` 并在用例内清理。
- 断言只针对**自造**的数据；不要对「本机当前状态」做断言。

---

## 测试分层

不是所有测试都该用内存替身。全部换成内存会丢掉真实行为——
SQL 层错误、事务边界、并发写冲突、schema 迁移、路径拼接，这些恰恰是 Bug 高发区。

| 层次 | 目标 | 做法 |
|------|------|------|
| **纯逻辑层** | 解析、布局、状态机、纯函数 | 直接调用；用内存替身替代外部依赖 |
| **持久化层** | 真实 SQLite / SwiftData 行为 | 临时目录里跑**真实**数据库，验证 schema、迁移、并发 |
| **集成 / 迁移层** | 插件完整 boot、版本迁移 | 临时目录 + 完整插件 boot，走真实 `StorageProviding` 注入链 |

判断标准：**这个测试如果跑在内存替身上，还能发现真实缺陷吗？**
不能，就说明该用真实持久化（配临时目录），而不是内存替身。

---

## 测试框架

新代码优先使用 **Swift Testing**（`import Testing`）：

```swift
import Testing
@testable import PluginAgentRules

@Suite("AgentRules 运行时目录")
@MainActor
struct AgentRulesRuntimeDirectoryTests {

    @Test("注入目录后 settingsDirectory 返回该目录")
    func usesInjectedDirectory() throws {
        let temporary = try TemporaryDirectory.make("agent-rules-runtime")
        defer { temporary.remove() }
        AgentRulesRuntime.configure(settingsDirectory: temporary.url)
        defer { AgentRulesRuntime.reset() }

        #expect(AgentRulesRuntime.settingsDirectory() == temporary.url)
    }
}
```

遗留 **XCTest** 可保留，不强制迁移。

---

## 运行测试

```bash
# 单包
cd Packages/<PackageName> && swift test

# 全量（并发 8）
./Scripts/run-all-package-tests.sh
```

---

## 检查清单

新增或改造测试时，确认：

- [ ] 测试目录在包内 `Tests/<PackageName>Tests/`
- [ ] 目录来自临时目录或注入的 `StorageProviding`，未回退本机真实路径
- [ ] 运行时目录未注入即失败（有守卫用例覆盖）
- [ ] 未写入 `UserDefaults.standard`；真实偏好域已做成可注入
- [ ] 未写真实 Keychain（用 Stub backend）
- [ ] 触碰的进程级单例在用例前后已清理
- [ ] 断言只依赖自造数据，不依赖执行顺序
- [ ] 持久化层测试用真实数据库（配临时目录），而非内存替身
- [ ] 若插件的 `static let` store / 单例会固化目录，已确认注入发生在**首次访问之前**

---

## 相关规范

* [插件包目录结构规范](./plugin-package-structure.md) — SPM 包分层与 `Tests/` 约定
* [插件数据存储规范](./plugin-storage-rules.md) — `StorageProviding` 与插件目录
* [中间件开发规范](./middleware-rules.md) — 中间件的可测试性说明
* [条件编译（DEBUG / Release）规范](./debug-only-code-guards.md) — `#if DEBUG` 夹具的守卫范围
