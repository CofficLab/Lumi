# 插件包目录结构规范

> 本规范定义了 Lumi 项目中 `Packages/` 下所有 SPM 插件包的内部目录结构标准。
> 基于项目中 140+ 插件包的实际分析，提炼出统一的最佳实践。
> 本规范聚焦 **SPM Package 级别**的目录组织；`LumiApp/Plugins/` 下的 monorepo 插件内部结构参见 [插件目录结构规范](./plugin-directory-rules.md)。

---

## 1. SPM Package 目录结构

### 1.1 包级目录

每个 SPM Package 的根目录必须包含以下结构：

```
Packages/<PackageName>/
├── Package.swift              # 必需
├── README.md                  # 必需
├── Resources/                 # 可选，需要本地化或媒体资源时创建
│   └── *.xcstrings
├── Sources/
│   └── <PackageName>/         # 必需，包裹目录（与包名一致）
│       └── ...                # 源码文件与子目录
└── Tests/
    └── <PackageName>Tests/    # 必需，测试包裹目录
        └── ...                # 测试文件
```

### 1.2 必需项

| 项目 | 必需 | 说明 |
|------|:----:|------|
| `Package.swift` | ✅ | SPM 包声明文件 |
| `README.md` | ✅ | 包功能说明 |
| `Sources/<PackageName>/` | ✅ | 源码包裹目录，名称与包名一致 |
| `Tests/<PackageName>Tests/` | ✅ | 测试包裹目录，名称为包名 + Tests |
| `Resources/` | ⬚ | 仅当需要 `.xcstrings` 或媒体资源时创建 |

### 1.3 命名规范

| 范畴 | 规范 | 示例 |
|------|------|------|
| 插件包名 | `Plugin<Feature>` | `PluginConversationList` |
| 工具包名 | `Kit<Feature>` | `KitLLM` |
| 提供者包名 | `Provider<Feature>` | `ProviderConversation` |
| 工厂包名 | `Factory<App>` | `FactoryLumi` |
| 测试目录 | `<PackageName>Tests` | `PluginConversationListTests` |

---

## 2. Sources 内部代码组织

### 2.1 核心规则：包裹目录

`Sources/` 下**必须**使用与包名一致的子目录作为命名空间，所有源码文件放入该目录中。

```
Sources/
  PluginConversationList/         ← ✅ 包裹目录
    ConversationListPlugin.swift
    Models/
    ViewModels/
    Views/

Sources/
  StoragePlugin.swift             ← ❌ 禁止：缺少包裹目录
  StorageSettingView.swift
```

### 2.2 Plugin 类包分层

#### 简单插件（≤ 3 个源文件）

入口文件与可选的支持文件直接放在包裹目录下：

```
Sources/
  PluginWelcome/
    WelcomePlugin.swift           # 入口
    Support/
      PluginLocalization.swift
```

#### 标准插件（4 ~ 10 个源文件）

按职责分层，仅创建实际需要的目录：

```
Sources/
  PluginXxx/
    XxxPlugin.swift               # 插件入口
    Models/                        # 数据模型
    Observers/                     # 事件订阅
    Support/                       # 本地化、扩展等
    ViewModels/                    # 视图模型
    Views/                         # SwiftUI 视图
```

#### 复杂插件（> 10 个源文件）

在标准分层基础上增加更多目录，或按功能对 Views 等进行二级分组：

```
Sources/
  PluginConversationList/
    ConversationListPlugin.swift
    Helpers/                       # 轻量辅助（Date 扩展、通知名等）
    Models/
    Observers/
    Support/
    Tools/                         # Agent 工具实现
    ViewModels/
    Views/
      ListView/                    # 按功能分组
      RailView/
      Toolbar/
```

### 2.3 目录职责说明

| 目录 | 职责 | 存放内容 |
|------|------|---------|
| `Models/` | 数据模型 | struct / class / enum 数据定义 |
| `Observers/` | 事件订阅 | `*Observer`、`*Controller` 等监听类型 |
| `Support/` | 辅助 | `PluginLocalization.swift`、轻量扩展 |
| `ViewModels/` | 视图模型 | `@Observable` / `ObservableObject` 类 |
| `Views/` | 视图 | SwiftUI `View` 组件 |
| `Capabilities/` | 能力扩展 | 可选的插件能力声明 |
| `Tools/` | Agent 工具 | `AgentTool` 实现 |
| `Middleware/` | 中间件 | 各类中间件（SendMiddleware 等） |
| `Providers/` | 协议实现 | `*Providing` 协议的具体实现 |
| `Helpers/` | 辅助函数 | 比 Support 更轻量的工具代码 |
| `Services/` | 业务服务 | 复杂业务逻辑、网络请求等 |
| `LLMProviders/` | LLM 供应商 | 仅 `PluginLLMProvider*` 使用 |
| `Managers/` | 管理器 | 复杂的状态管理、生命周期管理 |

### 2.4 Kit / 框架类包分层

Kit 类包不使用 MVC 分层，而按架构层次组织：

```
Sources/
  KitLLM/
    Contracts/                   # 公共协议（SuperLLMProvider 等）
    Core/                        # 核心实现
    Adapters/                    # 外部系统适配（Anthropic / OpenAI 兼容层）
    Base/                        # 基础类型（枚举、错误、配置）
    Support/                     # 辅助代码
```

| 目录 | 职责 |
|------|------|
| `Contracts/` | 公共协议和接口定义 |
| `Core/` | 核心逻辑实现 |
| `Adapters/` | 外部系统适配器 |
| `Base/` | 基础类型、枚举、错误定义 |
| `Support/` | 辅助代码 |

### 2.5 Provider 类包分层

Provider 包通常结构最简：

```
Sources/
  ProviderConversation/
    ConversationManaging.swift    # 协议 + 默认实现
    DefaultConversationManager.swift
    ConversationSummary.swift
```

当文件较多时可按 `Contracts/` + `Core/` 分层。

---

## 3. Views 二级分组规则

当 `Views/` 目录下文件 **超过 5 个** 时，应按功能模块拆分子目录：

```
Views/
  ListView/                      # 列表相关
    ListView.swift
    ListEmptyView.swift
    ListErrorView.swift
    ListLoadingView.swift
    ItemView.swift
  Settings/                      # 设置相关
    SettingsView.swift
    SettingsRowView.swift
  Toolbar/                       # 工具栏相关
    ToolbarButton.swift
    ToolbarPopoverContent.swift
```

**判断标准**：
- ≤ 5 个视图文件 → 平铺在 `Views/` 下
- \> 5 个视图文件 → 按功能分组为子目录
- 每个子目录至少 2 个文件（避免单独一个文件的分组）

---

## 4. Tests 组织规范

### 4.1 目录结构

所有测试使用包裹目录，放在 `Tests/<PackageName>Tests/` 下：

```
Tests/
  PluginConversationListTests/   ← ✅ 包裹目录
    ConversationAttentionStoreTests.swift
    ConversationListPluginTests.swift
    ConversationListViewModelTests.swift
    ConversationRailTabControllerTests.swift
    GetRecentConversationsToolTests.swift

Tests/
  StoragePluginTests.swift       ← ❌ 禁止：缺少包裹目录
```

### 4.2 文件命名

| 项 | 规范 | 示例 |
|----|------|------|
| 测试目录 | `<PackageName>Tests` | `PluginConversationListTests` |
| 测试文件 | `<SourceFileName>Tests.swift` | `ConversationListViewModelTests.swift` |

测试文件与源文件 **一一对应**，便于定位。

### 4.3 测试框架

新代码优先使用 **Swift Testing**（`import Testing`）：

```swift
import Testing
@testable import PluginConversationList

@Suite("ConversationListViewModel")
struct ConversationListViewModelTests {
    @Test("sorts conversations by date")
    func sortsConversationsByDate() async {
        // ...
    }
}
```

遗留的 **XCTest**（`import XCTest`）可保留，不强制迁移。

---

## 5. Package.swift 配置

### 5.1 测试 target

必须声明 `testTarget` 并正确设置依赖：

```swift
.testTarget(
    name: "PluginConversationListTests",
    dependencies: ["PluginConversationList"]
)
```

### 5.2 资源配置

需要本地化资源时：

```swift
.target(
    name: "PluginConversationList",
    dependencies: [...],
    resources: [.process("Resources")]
)
```

不需要资源时省略 `resources` 参数，且 **不要** 创建空的 `Resources/` 目录。

---

## 6. 最佳实践

### ✅ 推荐

- 只有 2 ~ 3 个文件时，直接放包裹目录下，不强行建子目录
- 文件名与主类型名一致（`ConversationListViewModel.swift` → `class ConversationListViewModel`）
- 每个视图单独一个文件，参照 [视图拆分规范](./views-should-be-separated.md)
- 目录嵌套不超过 3 层（`Sources/PluginXxx/Views/ListView/` 已达上限）
- 新插件包统一使用包裹目录结构（`Sources/<PackageName>/`）

### ❌ 避免

- 无脑为每个目录分类都创建子目录（文件少时直接放包裹目录）
- 在包裹目录下混放入口文件和子目录超过 3 个层级
- 创建空的占位目录

---

## 7. 实际参考

| 包 | 复杂度 | 分层方式 |
|----|--------|---------|
| `PluginConversationList` | 复杂 | Helpers / Models / Observers / Support / Tools / ViewModels / Views（含二级分组） |
| `PluginPluginManager` | 标准 | Capabilities / Models / Observers / Support / ViewModels / Views |
| `KitLLM` | 复杂框架 | Adapters / Base / Contracts / Core / Support |
| `ProviderConversation` | 简单 | 平铺在包裹目录下 |
| `PluginWelcome` | 极简 | 入口 + Support/ |

---

## 相关规范

- [插件目录结构规范](./plugin-directory-rules.md) — `LumiApp/Plugins/` 内部结构
- [视图拆分规范](./views-should-be-separated.md) — 视图文件独立拆分
- [单元测试规范](./unit-test-rules.md) — 测试编写最佳实践
- [Swift 代码组织规范](./swift-code-organization.md) — MARK 分段顺序
- [插件国际化规范](./plugin-i18n-rules.md) — xcstrings 文件管理
