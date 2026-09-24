# Editor Provider Migration Implementation Plan

**Goal:** 将编辑器契约收敛为 `ProviderEditor`，并逐步让编辑器 Host、工作区 UI 和语言扩展通过 Provider 协议协作。

**Architecture:** `ProviderEditor` 只承载编辑器协议、数据结构和贡献模型；`PluginCodeEditorHost` 是唯一允许持有 `EditorService`/`EditorSource` 的 Host Provider；工作区和语言插件只依赖 `ProviderEditor`，分别消费 Host 能力或提交编辑器贡献包。迁移期间保留行为不变，并通过兼容性测试逐步切换消费者。

**Tech Stack:** Swift 6, Swift Package Manager, KernelCore, Combine, SwiftUI（仅 UI 契约）, EditorService/EditorSource（仅 Host 内部）。

**Progress:** 契约 package/product/module 已命名为 `ProviderEditor`；原有的 `EditorContracts` 目录已重命名为 `Packages/ProviderEditor`。可复用实现现位于 `KitEditor*` packages；`EditorService` 已并入 `PluginCodeEditorHost` 作为内部 target。根协议、主题、扩展贡献和上下文菜单契约已补齐，并保留旧协议别名兼容。工作区编辑器、语言、数据库 SQL、Git SCM 和快速文件打开通过 Provider 契约协作。此前记录的测试与整体构建结果针对包重命名前的状态；当前验证见 `docs/plans/2026-09-20-editor-package-taxonomy.md`。

---

### Task 1: 将编辑器契约模块命名为 ProviderEditor — 已完成

**Files:**
- Modify: `Packages/ProviderEditor/Package.swift`
- Modify: all manifests and Swift imports currently referencing `EditorContracts`
- Modify: `LumiKernel/Sources/KernelCore`
- Test: `Packages/ProviderEditor/Tests/EditorContractsTests`

**Steps:**
1. 将 package、product、target 和模块引用统一改为 `ProviderEditor`，目录暂时保留以降低迁移风险。
2. 删除 Provider 包对未使用的 `LumiUI` 包依赖；保留系统框架依赖。
3. 更新 KernelCore、EditorService、Editor Host、编辑器插件及其他消费者的 package manifests/imports。
4. 运行 `swift test --package-path Packages/ProviderEditor` 和受影响包的测试。
5. 用 `rg` 验证生产代码不再导入 `EditorContracts`。

### Task 2: 稳定根 Provider 与贡献协议 — 已完成第一轮

**Files:**
- Modify: `Packages/ProviderEditor/Sources/EditorContracts/Editor/Services/EditorProvidingV2.swift`
- Modify: `Packages/ProviderEditor/Sources/EditorContracts/Editor/Services/*Providing.swift`
- Modify: `Packages/ProviderEditor/Sources/EditorContracts/Editor/Contributions/*`
- Test: `Packages/ProviderEditor/Tests/*`

**Steps:**
1. 将根能力和子能力边界固定为文档、Session、选择、导航、命令、配置、Surface、扩展宿主。
2. 将语言、grammar、LSP/编辑器功能定义为可撤回的 contribution，而不是暴露内部 registry。
3. 增加缺失 Provider、过期 revision、插件撤回和重复贡献的契约测试。
4. 保持 UI 类型只出现在明确的 Surface/Embedded Editor 契约中。

### Task 3: 让 Editor Host 成为唯一具体实现边界 — 已完成第一轮

**Files:**
- Modify: `Packages/PluginCodeEditorHost/Sources/PluginCodeEditorHost/*`
- Modify: `Packages/PluginCodeEditorHost/Sources/EditorService/V2/*`
- Test: `Packages/PluginCodeEditorHost/Tests/*`

**Steps:**
1. 保持 `EditorService`、`EditorSource` 和 `EditorLanguageRuntime` 仅由 Host 依赖。
2. 通过 `EditorProviding` 注册聚合能力，并让 Host 负责生命周期和清理。
3. 为 Host 注入 contribution bridge，保证插件撤回时清理对应注册和异步任务。

### Task 4: 迁移工作区 UI 插件 — 已迁移并通过定向测试

**Files:**
- Modify: `Packages/PluginCodeEditor/Package.swift`
- Modify: `Packages/PluginCodeEditor/Sources/PluginCodeEditor/*`
- Test: `Packages/PluginCodeEditor/Tests/*`

**Steps:**
1. 移除 UI 插件对具体 `EditorService` 的依赖。
2. `CodeEditorViewModel` 改为消费 `EditorProviding` 的文档能力。
3. 工作区通过 `EditorSurfaceProviding` 显示 Host 创建的编辑器 Surface。
4. 主题、上下文菜单和文件打开流程通过契约或贡献接口完成。

### Task 5: 迁移语言和其他编辑器扩展 — 第一轮已完成

**Files:**
- Modify: `Packages/PluginCodeEditorLanguages/*`
- Modify: `Packages/PluginDatabaseManager/*`
- Modify: `Packages/PluginGit/*`
- Modify: other editor feature plugins discovered by dependency checks

**Steps:**
1. 语言插件通过 `EditorContributionBundle` 安装 descriptor、grammar 和语言能力。
2. 禁止语言插件直接访问 `EditorExtensionRegistry` 或 `EditorService`。
3. 迁移嵌入式编辑器、Git 编辑器能力和预览能力到对应贡献协议。

### Task 6: 依赖边界与完整验证 — 已完成

**Files:**
- Create: `Scripts/check-editor-provider-boundary.sh`
- Modify: CI/workflow configuration if needed
- Test: package builds and editor contract tests

**Steps:**
1. 检查 `ProviderEditor` 不依赖 `EditorService`、`EditorSource`、插件或业务包。
2. 检查非 Host 编辑器插件不导入 `EditorService`、`EditorSource` 或 `EditorKernel`。
3. 运行 Provider、Host、语言插件和工作区插件测试。
4. 运行完整工程构建并记录迁移结果。
