# Lumi 插件 Capabilities 目录（能力目录）设计与迁移计划

> 状态：设计定稿，试点已落地（PluginProjects / PluginProjectFiles / PluginEditorPreview）
> 参考：Cisum `Packages/Plugin*/Sources/Capabilities/` 模式

## 1. Purpose

把 Cisum 插件的「能力目录（Capabilities）」设计引入 Lumi：每个插件在自己的
`Sources/<Target>/Capabilities/` 目录中声明**它需要的最小能力边界**，用 Adapter
把内核 Provider 收窄后注入 ViewModel / View / Service；业务层只依赖插件自己的
能力协议，不再直接依赖整个 Provider 协议类型。

> 外部能力进入插件的唯一入口是**能力协议 + Adapter**（依赖收窄），
> 外部状态进入插件的唯一入口是**Observer**（状态收窄）。两者互补、不冲突：
> Observer 负责「状态怎么进来」，Capabilities 负责「接口怎么收窄」。

本计划只描述迁移方案与规范，不重写 UI、不改变产品行为、不删除 Provider 能力。

## 2. Cisum 参考基线

Cisum 的能力目录由两部分组成，位于每个插件 `Sources/Capabilities/` 下：

- **能力协议**：插件需要的最小能力边界，例如：

  ```swift
  // Cisum/Packages/PluginOpenButton/Sources/Capabilities/OpenButtonPlaybackCapability.swift
  @MainActor
  protocol OpenButtonPlaybackCapability: AnyObject {
      var currentURL: URL? { get }
  }
  ```

- **适配器（Adapter）**：包装内核 Provider 并实现该协议，例如：

  ```swift
  @MainActor
  final class OpenButtonPlaybackCapabilityAdapter: OpenButtonPlaybackCapability {
      private let playback: any PlaybackProviding
      init(playback: any PlaybackProviding) { self.playback = playback }
      var currentURL: URL? { playback.currentURL }
  }
  ```

- **装配**：插件入口解析内核 Provider，创建 Adapter 注入 ViewModel：

  ```swift
  // 插件入口 onReady
  let viewModel = OpenButtonViewModel(
      playbackCapability: OpenButtonPlaybackCapabilityAdapter(playback: playback)
  )
  ```

Cisum 中已存在能力目录的插件（示例）：`PluginLikeButton`、`PluginOpenButton`、
`PluginControlButtons`、`PluginAudioDownload`、`PluginAudioControl`、
`PluginAudioDBView`、`PluginAudioLike`、`PluginAudioPlayMode`、`PluginAudioProgress`、
`PluginAudioWidgetControl`、`PluginBookControl`、`PluginBookDBView`、`PluginBookLike`、
`PluginBookPlayMode`、`PluginBookProgress`、`PluginPlaybackHero`、
`PluginPlaybackProgress`、`PluginPluginManager`、`PluginScene`、`PluginStorage`、
`PluginThemeSettings` 等。

Lumi 迁移以 Cisum 上述实现为行为参考，但**不按名称复制**：能力协议按 Lumi
Provider 的语义重新设计，只收窄插件实际使用的成员。

## 3. 当前 Lumi 状态与问题

### 3.1 已有基础

Lumi 已完成 / 正在进行两项相关基建：

- **Observer 化**（`docs/plans/2026-09-03-plugin-observer-only.md`、
  `docs/plans/2026-09-03-provider-observer-only-migration.md`）：
  Provider 状态变化通过类型化 `addObserver` + `ObserverHandle` 发布，
  插件入口持有 Observer，Observer 更新插件 ViewModel。
- **Provider 协议边界**：Lumi 插件通过 `kernel.resolveProvider((any XProviding).self)`
  在插件生命周期方法中解析 Provider（131 个插件文件），符合「入口装配」原则。

### 3.2 主要问题

插件业务层（ViewModel / View / Service）对 Provider 协议的依赖没有收窄：

1. **ViewModel 直接持有 Provider 协议类型**：
   - `PluginProjects/ViewModels/ProjectsViewModel.swift` — `private let projectProvider: any ProjectProviding`
   - `PluginProjectFiles/Sources/PluginProjectFiles/ProjectFilesTabViewModel.swift` — `private let project: any ProjectProviding`
   - `PluginEditorPreview/ViewModels/EditorPreviewViewModel.swift` — `init(project: any ProjectProviding)`
2. **View 直接持有 Provider 协议类型**：
   - `PluginTerminal/Views/TerminalMainView.swift` — `let projectProvider: (any ProjectProviding)?`
   - `PluginMessageList/Models/MessageListServices.swift` — 聚合持有 8 个 Provider 协议
   - `PluginGit/Tools/*.swift`（8 个工具）— `private let project: (any ProjectProviding)?`
3. **View 直接解析 Kernel**（5 个文件）：`PluginMessageRenderer/Views/*`、
   `PluginConversationNew/Views/NewChatButton.swift`、`PluginChatFileAttachment/Views/*`。

结果是：业务层 import 了整个 Provider 包、依赖 Provider 协议的完整面
（即使只用其中 1～2 个成员）、难以单独测试、Provider 协议变更会波及所有
消费插件。能力目录把「接口依赖」从 Provider 包移动到插件自己的
`Capabilities/`，Provider 包只被 Adapter 和 Observer 引用。

### 3.3 与 Observer 化的分工

| 层 | 职责 | 是否允许持有 Provider 协议 |
| --- | --- | --- |
| 插件入口（`*SuperPlugin.swift` / `*Plugin.swift`） | 解析 Provider、装配 Adapter/Observer/ViewModel | 允许 |
| `Capabilities/`（能力协议 + Adapter） | 声明最小能力边界；Adapter 收窄 Provider | 允许（Adapter 必须 import Provider 包） |
| `Observers/` | 订阅 Provider 事件 → 更新 ViewModel | 允许（Observer 需要完整事件面） |
| ViewModel / View / Service / Tool | 只依赖能力协议 | **禁止直接持有 Provider 协议** |

## 4. 目标架构

```text
Kernel Provider (any ProjectProviding)
        │
        ├── resolveProvider @ 插件入口
        │
        ├──► Capabilities/XXXCapabilityAdapter   （唯一 import Provider 包的业务侧文件）
        │         │  收窄为最小能力协议
        │         ▼
        │   ViewModel / View / Service / Tool    （只依赖能力协议）
        │
        └──► Observers/XXXObserver               （订阅 Provider 事件 → 更新 ViewModel）
```

目录结构模板：

```text
PluginFoo/
└── Sources/PluginFoo/
    ├── FooSuperPlugin.swift            # 唯一装配入口：resolve → makeCapability → inject
    ├── Capabilities/
    │   └── FooProjectCapability.swift  # 能力协议 + Adapter（同文件）
    ├── Observers/
    │   └── FooProviderObserver.swift   # 状态入口（已有模式，保持）
    ├── ViewModels/
    │   └── FooViewModel.swift          # 只依赖能力协议
    └── Views/
        └── ...                         # 只依赖 ViewModel / 能力协议
```

## 5. 命名与目录规范

1. **目录**：`Sources/<Target>/Capabilities/`（与 `Observers/`、`ViewModels/`、`Views/` 平级）。
2. **文件**：一个能力边界一个文件，命名 `<用途>Capability.swift`，例如
   `ProjectsProjectCapability.swift`。
3. **能力协议**：命名 `<插件>XxxCapability`（如 `ProjectsProjectCapability`），
   默认 `@MainActor`，继承 `AnyObject`。
4. **Adapter**：命名 `<插件>XxxCapabilityAdapter`，与协议同文件；持有内核
   Provider（`private let`，可选 weak），逐成员透传 / 转换。
5. **协议只声明插件实际使用的成员**：不复制整个 Provider 协议。
6. **类型策略**：
   - 能力协议优先使用无 Provider 依赖的类型（`URL`、`String`、`Bool`、插件自身模型）。
   - 当 Provider 的领域模型（如 `ProjectInfo`）是跨包共享值类型时，允许 Adapter
     文件 import Provider 包并透传该模型；ViewModel 可 import Provider 包但**只引用
     模型类型，不引用 Provider 协议**。
7. **装配**：插件入口在 `guard let provider = kernel.resolveProvider(...)` 后直接构造
   Adapter 注入业务层；需要可降级装配时，提供 `makeXxxCapability(from:)` 返回
   optional 的私有方法，与现有 `resolveProvider` 的降级语义一致。

## 6. 装配规则（生命周期）

```swift
@MainActor
public final class FooSuperPlugin: SuperPlugin {
    private var viewModel: FooViewModel?

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let provider = kernel.resolveProvider((any ProjectProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ProjectProviding")
            return
        }
        // 入口已 guard 到具体 Provider，直接构造 Adapter 注入业务层
        let viewModel = FooViewModel(
            projectCapability: FooProjectCapabilityAdapter(project: provider)
        )
        self.viewModel = viewModel
        // Observer 仍使用完整 Provider 类型
        let observer = FooProviderObserver(project: provider, viewModel: viewModel)
        ...
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        observer?.cancel()
        observer = nil
        viewModel = nil
    }
}
```

要点：

- **Observer 不迁移到能力协议**：Observer 需要订阅完整 Provider 事件面，保留
  Provider 类型；能力协议只服务业务层（ViewModel/View/Service/Tool）。
- **入口装配不变**：`resolveProvider` 仍在插件生命周期方法中执行；能力目录只改变
  解析结果的分发方式（Provider → Adapter → 业务层）。
- **guard 后直接构造 Adapter**：插件入口在 guard 到具体 Provider 后直接创建
  Adapter 并注入，不需要额外的 optional 装配方法。
- **先同步快照、再安装监听**：与现有 Observer 生命周期一致，能力协议不负责事件订阅。
- 插件入口至少要能表达：`private var viewModel: FooViewModel?`、能力适配器由
  入口装配（`FooXxxCapabilityAdapter(provider:)`）、Observer 由入口持有并在
  shutdown 时取消。

## 7. 试点与已迁移插件（进行中）

**试点（Phase 1，2026-09-06 完成）：**

| 插件 | 改造内容 | 能力协议成员 |
| --- | --- | --- |
| `PluginProjects` | `ProjectsViewModel` 依赖 `any ProjectProviding` → `any ProjectsProjectCapability` | `projects`、`currentProject`、`synchronizeProjects`、`openProject`、`closeProject` |
| `PluginProjectFiles` | `ProjectFilesTabViewModel` 依赖 `any ProjectProviding` → `any ProjectFilesProjectCapability` | `currentProject`、`openFileURLs`、`currentFileURL`、`activateFile`、`closeFile`、`updateCurrentFile` |
| `PluginEditorPreview` | `EditorPreviewViewModel` 依赖 `any ProjectProviding` → `any EditorPreviewProjectCapability` | `currentFileURL` |

**Phase 2（2026-09-06 完成）：**

| 插件 | 改造内容 | 能力协议成员 |
| --- | --- | --- |
| `PluginGit` | 7 个 Agent Tool 持有 `any ProjectProviding` → `any GitProjectCapability` | `currentProjectPath`（public 能力协议，工具为跨包 public API） |
| `PluginTerminal` | `TerminalMainView` 持有 `any ProjectProviding` → `any TerminalProjectCapability` | `currentProjectPath`（public 能力协议，View 为跨包 public API） |

试点验证了以下约定：

- 能力协议只声明业务层实际调用的成员（`ProjectsProjectCapability` 只收窄
  ViewModel 用到的 5 个成员，而非整个 `ProjectProviding` 的 14 个）。
- Adapter 与协议同文件，仅 Adapter import Provider 包。
- 插件入口在 `guard` 到具体 Provider 后直接构造 Adapter 注入；Observer 保持
  完整 Provider 类型。
- 共享领域模型（`ProjectInfo`）由 Adapter 透传，ViewModel 不再出现
  `ProjectProviding` 协议类型。

## 8. 分阶段迁移计划

### Phase 1：迁移 ViewModel 直接依赖 Provider 的插件（已完成）

范围：`PluginProjects`、`PluginProjectFiles`、`PluginEditorPreview`（试点，2026-09-06 完成）。

### Phase 2：迁移 View / Service / Tool 直接依赖 Provider 的插件

按依赖热度优先：

1. ✅ `PluginTerminal`（View 持有 `any ProjectProviding`）— 已收窄为
   `TerminalProjectCapability`（`currentProjectPath`）。
2. ✅ `PluginGit`（7 个 Agent Tool 持有 `any ProjectProviding`）— 已统一收窄为
   `GitProjectCapability`（`currentProjectPath`）。
3. ⏳ `PluginMessageList`（`MessageListServices` 聚合持有 12 个 Provider）— 计划按
   「会话列表 / 渲染 / 流式 / 工具 / 项目」拆分能力协议；入口 Observer 安装改用
   原始 Provider 局部变量，services 只持能力协议。**待下一批执行**（改动面最大）。
4. ⏳ `PluginActivityHeatmap`、`PluginSettingView`、`PluginProjectOverview`、
   `PluginAppUpdate`、`PluginGitWorkspace`、`PluginToolManager`、`KitLLM/VendorAPIService`
   等其余持有点。**待下一批执行**。
5. ❌ `PluginAgentLoop` — **已重新评估，从迁移清单移除**：`AgentLoopManager` 是
   `AgentLoopProviding` 的实现者（Provider 提供方），持有其他 Provider 属于
   实现层依赖，收窄会限制实现能力；不适用能力目录模式。

### Phase 3：清理 View 直接解析 Kernel 的路径

范围：`PluginMessageRenderer/Views/*`、`PluginConversationNew/Views/NewChatButton.swift`、
`PluginChatFileAttachment/Views/*`。

- View 不应 `resolveProvider`；改为插件入口解析后经 ViewModel 注入，或经
  `Capabilities/` 收窄后注入。

### Phase 4：规范检查与文档化

- 为每个已迁移插件补充 README / 架构注释，说明 Capabilities 边界。
- 将「业务层禁止持有 Provider 协议」列入仓库架构约定；
  可执行静态检查（rg 模式）防止回退：

  ```bash
  # 业务层文件（ViewModels/Views/Services/Tools/Models）中不应出现：
  rg -n 'any [A-Za-z]+Providing|resolveProvider' Packages/Plugin*/Sources/*/{ViewModels,Views,Services,Tools} --include='*.swift'
  ```

## 9. 验收标准

迁移完成必须同时满足：

- 每个有 Provider 依赖的插件在 `Sources/<Target>/Capabilities/` 下声明能力协议 + Adapter；
- 业务层（ViewModel / View / Service / Tool）不再直接持有 `any XProviding` 协议类型
  （共享领域模型类型除外）；
- 业务层不再直接调用 `kernel.resolveProvider`（View 层完全禁止）；
- Adapter 是业务层与 Provider 包之间的唯一桥梁；Observer 继续使用完整 Provider 类型；
- 插件入口负责解析、创建 Adapter、注入，并在生命周期结束时释放；
- 行为不变：迁移前后界面状态、用户操作、持久化逻辑完全一致；
- 受影响包 `swift build` / `swift test` 通过，主 App 构建通过。

## 10. 风险与缓解

| 风险 | 缓解措施 |
| --- | --- |
| 能力协议漏收窄成员导致编译失败 | Adapter 逐成员透传；收窄范围按业务层实际调用点确定 |
| 收窄后丢失 Provider 行为（默认实现） | 只迁移业务层调用；Observer / 插件入口继续使用完整 Provider |
| 跨包共享模型造成循环依赖 | 模型类型（值类型）不参与循环；Adapter 单向 import Provider 包 |
| 大规模迁移一次完成风险高 | 按 Phase 分批，每批独立 `swift build` 验证后再提交 |
| 迁移改变行为 | 黄金法则：只改依赖声明方式，不改任何逻辑表达式 |
