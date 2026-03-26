# 插件目录结构规范

> 本规范定义了 Lumi 项目中所有插件的代码组织方式和目录结构。

---

## 核心原则

**插件目录自包含，代码组织清晰，遵循统一的结构约定。**

每个插件位于 `LumiApp/Plugins/<PluginName>/` 或 `LumiApp/Plugins-Agent/<PluginName>/` 目录下（Agent 相关插件在 `Plugins-Agent`），自行管理其内部的所有代码文件、资源和文档。

凡插件内的**中间件**实现（任意协议、任意管线：发送、网络、请求编排等，只要类型职责是「中间件」）**必须**放在 `Middleware/` 子目录中，不得在插件根目录散落；历史遗留可择机迁入。

---

## 标准目录结构

```
LumiApp/Plugins/<PluginName>/          # 或 LumiApp/Plugins-Agent/<PluginName>/
├── <PluginName>Plugin.swift          # 插件主入口（必须）
├── <PluginName>.xcstrings             # 本地化字符串（必须）
├── <PluginName>LocalStore.swift       # 配置存储（可选）
├── README.md                          # 插件说明文档（推荐）
│
├── Middleware/                        # 各类中间件（按需）
│   └── *.swift
│
├── Models/                            # 数据模型
│   └── *.swift
│
├── Services/                          # 业务逻辑/服务
│   └── *.swift
│
├── ViewModels/                        # 视图模型
│   └── *.swift
│
└── Views/                             # SwiftUI 视图
    └── *.swift
```

---

## 文件说明

### 必须文件

| 文件名 | 用途 | 说明 |
|--------|------|------|
| `<PluginName>Plugin.swift` | 插件主入口 | 实现 `SuperPlugin` 协议，注册插件 |
| `<PluginName>.xcstrings` | 本地化字符串 | 插件的本地化文本资源 |

### 可选文件

| 文件名 | 用途 | 说明 |
|--------|------|------|
| `<PluginName>LocalStore.swift` | 配置存储 | 遵循存储规范，管理插件配置 |
| `README.md` | 插件文档 | 说明插件功能、使用方式、数据流 |

---

## 目录说明

### Middleware/

存放插件提供的**所有中间件类型**（不区分具体协议或挂载点）。例如：

- **发送管线**：实现 `SendMiddleware`，由 `SuperPlugin.sendMiddlewares()` 注册，在 `SendController` 落库用户消息之后、`send()` 请求模型之前执行。
- **未来**若新增其它中间件协议（如请求/网络层切面），同样放在本目录，按协议命名与注册。

```swift
// Middleware/ExampleSendMiddleware.swift — 当前已存在的 SendMiddleware 示例
@MainActor
struct ExampleSendMiddleware: SendMiddleware {
    let id: String = "plugin.example"
    let order: Int = 0

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        await next(ctx)
    }
}
```

**最佳实践**：

- 每个中间件一个文件，文件名与类型名一致（如 `FooSendMiddleware.swift` → `struct FooSendMiddleware`）。
- 类型名建议以 `Middleware` 结尾，或带管线前缀（如 `…SendMiddleware`），便于与 `Services/` 等区分。
- 对 `SendMiddleware`：通过 `ctx.chatHistoryService` 等做持久化时，注意与 `SendMessageContext` 生命周期一致；`order` 与同插件内其它中间件及全局排序（插件 `order` × 中间件 `order`）配合使用。

### Models/

存放数据模型和实体类。

```swift
// Models/DockerImage.swift
struct DockerImage: Codable, Identifiable {
    let id: String
    let repository: String
    let tag: String
    let size: Int64
    let createdAt: Date
}
```

**最佳实践**：
- 使用 `Codable` 协议便于序列化
- 使用 `Identifiable` 协议便于 SwiftUI 列表
- 值类型使用 `struct`，引用类型使用 `class`

### Services/

存放业务逻辑和服务实现。

```swift
// Services/DockerService.swift
actor DockerService {
    static let shared = DockerService()
    
    func listImages() async throws -> [DockerImage] { ... }
    func removeImage(_ id: String) async throws { ... }
}
```

**最佳实践**：
- 使用 `actor` 确保线程安全
- 使用单例模式 `static let shared` 提供全局访问
- 错误处理使用 `throws` 抛出具体错误类型

### ViewModels/

存放 SwiftUI 视图模型，管理视图状态和业务逻辑。

```swift
// ViewModels/DockerViewModel.swift
@MainActor
class DockerViewModel: ObservableObject {
    @Published var images: [DockerImage] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadImages() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            images = try await DockerService.shared.listImages()
        } catch {
            self.error = error
        }
    }
}
```

**最佳实践**：
- 使用 `@MainActor` 确保 UI 更新在主线程
- 继承 `ObservableObject`，使用 `@Published` 发布状态
- 处理加载状态、错误状态

### Views/

存放 SwiftUI 视图组件。

```swift
// Views/DockerImageListView.swift
struct DockerImageListView: View {
    @StateObject private var viewModel = DockerViewModel()
    
    var body: some View {
        List(viewModel.images) { image in
            DockerImageRow(image: image)
        }
        .task {
            await viewModel.loadImages()
        }
    }
}
```

**最佳实践**：
- 使用 `@StateObject` 创建视图模型
- 保持视图简洁，业务逻辑放入 ViewModel
- 复杂视图拆分为子视图组件

---

## 命名规范

### 文件命名

| 类型 | 命名规范 | 示例 |
|------|---------|------|
| 插件主文件 | `<PluginName>Plugin.swift` | `AppManagerPlugin.swift` |
| 本地化文件 | `<PluginName>.xcstrings` | `AppManager.xcstrings` |
| 配置存储 | `<PluginName>LocalStore.swift` | `InputPluginLocalStore.swift` |
| 模型 | `<ModelName>.swift` | `DockerImage.swift` |
| 服务 | `<Feature>Service.swift` | `DockerService.swift` |
| 视图模型 | `<Feature>ViewModel.swift` | `DockerViewModel.swift` |
| 视图 | `<Feature>View.swift` | `DockerImageListView.swift` |
| 行组件 | `<Feature>Row.swift` | `DockerImageRow.swift` |
| 中间件 | `<Feature>Middleware.swift`、`<Pipeline>Middleware.swift`（如 `…SendMiddleware`） | `AutoConversationTitleSendMiddleware.swift` |

### 类/结构体命名

| 类型 | 命名规范 | 示例 |
|------|---------|------|
| 插件 | `<PluginName>Plugin` | `AppManagerPlugin` |
| 配置存储 | `<PluginName>LocalStore` | `InputPluginLocalStore` |
| 模型 | `<ModelName>` | `DockerImage` |
| 服务 | `<Feature>Service` | `DockerService` |
| 视图模型 | `<Feature>ViewModel` | `DockerViewModel` |
| 视图 | `<Feature>View` | `DockerImageListView` |
| 中间件 | `<Feature>Middleware`、`<Feature>SendMiddleware` 等 | `AutoConversationTitleSendMiddleware` |

---

## 插件主入口模板

每个插件必须提供一个主入口文件，实现 `SuperPlugin` 协议：

```swift
import Foundation
import SwiftUI
import MagicKit

/// <PluginName> 插件
///
/// 插件功能简介
struct <PluginName>Plugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🎯"
    
    let id = "<plugin-id>"
    let name = "<PluginName>"
    
    /// 导航栏图标
    var navigationIcon: some View {
        Image(systemName: "icon-name")
    }
    
    /// 导航栏标题
    var navigationTitle: String {
        "<DisplayName>"
    }
    
    /// 插件主视图
    var body: some View {
        <PluginName>RootView()
    }
    
    /// 插件初始化
    func onEnable() {
        // 插件启用时的初始化逻辑
    }
    
    /// 插件禁用
    func onDisable() {
        // 插件禁用时的清理逻辑
    }
}

// MARK: - 预览

#Preview("<PluginName>") {
    ContentLayout()
        .withNavigation("<plugin-id>")
        .inRootView()
}
```

---

## 简单插件结构

对于功能简单的插件，可以简化目录结构：

```
<PluginName>/
├── <PluginName>Plugin.swift
├── <PluginName>.xcstrings
└── Views/
    └── <PluginName>View.swift
```

**适用场景**：
- 仅提供状态栏显示的插件
- 简单的设置按钮
- 功能单一的工具插件

---

## 复杂插件结构

对于功能复杂的插件，可以增加子目录组织：

```
<PluginName>/
├── <PluginName>Plugin.swift
├── <PluginName>.xcstrings
├── <PluginName>LocalStore.swift
├── README.md
│
├── Middleware/
│   └── ExampleSendMiddleware.swift
│
├── Models/
│   ├── ModelA.swift
│   └── ModelB.swift
│
├── Services/
│   ├── ServiceA.swift
│   └── ServiceB.swift
│
├── ViewModels/
│   ├── ViewModelA.swift
│   └── ViewModelB.swift
│
└── Views/
    ├── RootView.swift
    ├── SectionA/
    │   ├── ViewA1.swift
    │   └── ViewA2.swift
    └── SectionB/
        ├── ViewB1.swift
        └── ViewB2.swift
```

---

## 现有实现参考

| 插件 | 路径 | 结构类型 | 特点 |
|-----|------|---------|------|
| AgentRecentProjectsPlugin | `Plugins-Agent/AgentRecentProjectsPlugin/` | 含 Middleware/、Tools/ | 中间件在 `Middleware/` |
| AppManagerPlugin | `Plugins/AppManagerPlugin/` | 标准结构 | 完整实现 |
| ClipboardManagerPlugin | `Plugins/ClipboardManagerPlugin/` | 标准结构 | 含存储实现 |
| InputPlugin | `Plugins/InputPlugin/` | 标准结构 | 含测试目录 |
| DatabaseManagerPlugin | `Plugins/DatabaseManagerPlugin/` | 特殊结构 | Core/, Drivers/, Managers/ |
| SettingsButtonPlugin | `Plugins/SettingsButtonPlugin/` | 极简结构 | 仅主文件 |
| TimeStatusPlugin | `Plugins/TimeStatusPlugin/` | 极简结构 | 仅主文件 |

---

## 附录

### A. 目录对比

| 目录类型 | 标准结构 | 极简结构 | 特殊结构 |
|---------|---------|---------|---------|
| 插件数量 | 大多数 | 少量 | 个别 |
| Models | ✅ | ❌ | 可能有 |
| Services | ✅ | ❌ | 可能有 |
| ViewModels | ✅ | ❌ | 可能有 |
| Views | ✅ | ✅ | 可能有 |
| Middleware | 按需（有任意中间件类型时放在此目录） | 若有中间件则应放入 | 可能有 |
| 其他目录 | ❌ | ❌ | Core/, Drivers/ 等 |

### B. 检查清单

创建新插件时，确保：

- [ ] 目录名使用 `PascalCase`
- [ ] 包含 `<PluginName>Plugin.swift` 主入口
- [ ] 包含 `<PluginName>.xcstrings` 本地化文件
- [ ] 按功能将代码放入对应子目录（含各类中间件 → `Middleware/`）
- [ ] 遵循命名规范
- [ ] 添加 README.md 说明文档（推荐）