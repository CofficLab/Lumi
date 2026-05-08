# EditorService → Swift Package（`Packages/`）迁移 Todo

## 目标

将 `LumiApp/Core/Services/EditorService/` 抽成位于 `Packages/` 下的 Swift Package（建议模块名 **`EditorService`** 或 **`LumiEditorService`**，与 Xcode target 命名对齐后再定），使编辑器核心可在应用外单独 `swift build` / 测试，并复用现有 `EditorKernelCore` 包。

## 现状摘要（便于排期）

| 维度 | 说明 |
|------|------|
| 规模 | 约 **80+** Swift 源文件，分 `Editor/`、`Kernel/`、`Store/`、`Utilities/`、`Workbench/` 及根目录 `EditorService.swift` |
| 已有包 | `Packages/EditorKernelCore`（`EditorService` 内多处 `import EditorKernelCore`） |
| 主要第三方 | `CodeEditSourceEditor`、`CodeEditTextView`、`CodeEditLanguages`、`LanguageServerProtocol`、`SwiftTreeSitter`；`MagicKit` / `MagicAlert`（与应用/工具链绑定） |
| 应用耦合 | **`EditorExtensionRegistry`** 在 `LumiApp/Core/Registries/EditorExtensionRegistry.swift`，被 `EditorService` / `EditorState` 强依赖；大量 `Super*` 协议在 `LumiApp/Core/Proto/` 等 |
| 消费方 | `EditorVM`、`RootViewContainer`、多类 `Editor*Plugin` 与面板视图（通过 `EditorService` 或 `editorVM.service`） |
| 测试 | `Tests/EditorServiceTests/`（5 个文件） |

## 前置决策（必须先拍板）

- [ ] **包的内容边界**：仅移动 `EditorService` 目录，还是连同 **`EditorExtensionRegistry` + 其依赖的协议/`ExtensionResolver` 子集**一并迁入同一包（或拆成第二个包如 `EditorExtensionAPI`）。
- [ ] **可见性**：包内类型哪些 `public`、哪些保持 `internal`；`EditorService` 门面是否保持与现在一致的 API。
- [ ] **模块命名**：SPM `product` / 模块名与 Xcode 中现有 target 名称是否合并或保留双模块过渡期。
- [ ] **`MagicKit` / `MagicAlert`**：作为 SPM 依赖、本地 path package，还是保留为**宿主 app 注入协议**（减少包对内部框架的硬依赖）。

建议：若一次迁移风险大，采用 **「先边界、后搬家」**——先把「仅 EditorService 目录 + 明确 public API」列出，再决定 registry 是否同包。

## Phase A — 依赖与耦合清单

- [ ] 扫描 `EditorService` 内所有 `import`，分类为：标准库 / Apple SDK / 已有 `EditorKernelCore` / CodeEdit 系 / LSP / Magic 系 / **LumiApp 内模块**（无 `import` 的全局类型也算）。
- [ ] 列出所有引用 `LumiApp` 其他目录类型的文件（例如 `EditorExtensionRegistry`、`Super*` 协议、日志 `SuperLog` 等），画一张 **最小依赖闭包**（哪些文件必须跟包走）。
- [ ] 对照 `Tests/EditorServiceTests`，标注每个测试文件的 target 依赖是否能在包内自给自足。

## Phase B — 新建 Package 骨架

- [ ] 在 `Packages/` 下新建目录（例如 `Packages/EditorService/`）。
- [ ] 编写 `Package.swift`：`platforms` 至少 `.macOS(.v14)`（与 `EditorKernelCore` 对齐并符合应用部署目标）。
- [ ] 声明 `dependencies`：
  - [ ] 本地 `.package(path: "../EditorKernelCore")`（或 monorepo 内相对路径以仓库布局为准）。
  - [ ] `LanguageServerProtocol`（版本与 `EditorKernelCore` / 主工程 `Package.resolved` 对齐）。
  - [ ] CodeEdit 相关包：URL / 版本与 **根工程** `Lumi.xcodeproj/.../Package.resolved` 一致，避免重复解析冲突。
  - [ ] `SwiftTreeSitter`（若保留 `JumpToDefinitionDelegate` 等实现于包内）。
  - [ ] `MagicKit` / `MagicAlert`：按 Phase 0 决策添加 path 或远程依赖，或改写为协议注入。
- [ ] 定义 target `EditorService`（library），必要时增加 `EditorServiceTests` testTarget。

## Phase C — 代码迁移与 API 整理

- [ ] 将 `LumiApp/Core/Services/EditorService/**` 移入 `Packages/EditorService/Sources/EditorService/`，**保持子目录结构**（`Editor`、`Kernel`、`Store`…）以降低 diff 噪声。
- [ ] 若 `EditorExtensionRegistry`（及相关类型）迁入包内：
  - [ ] 处理 `SuperPlugin`、`SuperLog` 等对应用层的依赖：上移协议、改为 `public`、或抽 **小颗粒「宿主适配」协议** 由 `LumiApp` 实现。
- [ ] 若 registry **不**迁入：则 `EditorService` 包只保留纯编辑器逻辑，registry 通过 **泛型/构造注入协议** 与 app 连接（改动面较大，需单独设计）。
- [ ] 统一访问控制：对外只暴露 `EditorService` 及插件/宿主必需的 `public` 类型；其余 `internal`。
- [ ] 消除或隔离 **仅 App 使用的** 符号（例如硬编码 `subsystem` 日志、App 专属通知名等），避免包内残留产品字符串耦合（可按需参数化）。

## Phase D — Xcode 工程接入

- [ ] 在 Xcode 中将本地 package 加入工程（或通过 workspace 解析），使 `LumiApp` target **依赖** `EditorService` product。
- [ ] 从 `LumiApp` target **移除**（或中空化）原 `EditorService` 编译源文件引用，避免重复符号。
- [ ] 校验 `Lumi.xcodeproj` / SPM 的 **单一路径**：根 `Package.resolved` 中无版本打架；本地 path package 不需要重复 checkout。
- [ ] `RootViewContainer` / `EditorVM` 等：仅更新 `import` 与初始化路径（若模块名变化）。

## Phase E — 测试与 CI

- [ ] 将 `Tests/EditorServiceTests` 迁入 `Packages/EditorService/Tests/EditorServiceTests`（或保留根目录测试但改 depend on package product——二选一，优先与 `EditorKernelCore` 惯例一致）。
- [ ] 在包目录执行 `swift test`，修复 `#if`、资源.bundle、或 `@testable` 可见性问题。
- [ ] 确认现有 Xcode scheme / CI 仍运行应用测试；必要时增加 **仅包测试** 的 CI job。

## Phase F — 回归与收尾

- [ ] 手工跑通：打开文件、LSP、多标签、查找替换、保存流程、插件注册的命令/面板。
- [ ] 关注 **冷启动与 @MainActor**：迁移后编译器可见性变化是否暴露数据竞争警告。
- [ ] 更新团队内文档：模块边界、`import` 规范、谁可以依赖 `EditorService`。

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| `EditorExtensionRegistry` 与 hundreds of `Super*` 类型形成「大泥球」 | 分阶段：先迁 `EditorService` 子树中能独立编译的部分，或新建 `EditorExtensionAPI` 小包只放协议 |
| CodeEdit / Magic 非公开或 path 依赖在 SPM 中难表达 | 与主工程共用同一 Package 引用方式；必要时保留 **binaryTarget** 或 xcframework 文档化步骤 |
| 插件 target 与包模块循环依赖 | 插件继续只依赖 **`EditorService` public API**；registry 回调用协议定义在包内、实现在 app |

## 完成定义（Definition of Done）

- [ ] `Packages/EditorService` 可独立 `swift build` / `swift test`。
- [ ] `LumiApp` 通过 SPM 依赖使用该包，功能与迁移前一致。
- [ ] 无重复编译同一源码；`Package.resolved` 依赖图干净可复现。

---

*文档位置：`docs/plugins/AgentEditorPlugin/editor-service-package-todo.md`。若与 `xcode-package-dependencies-plan.md` 中的文件树能力交叉，以编辑器「模块化拆包」为主；文件树计划不必在此重复执行。*
