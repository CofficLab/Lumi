# StateMonitorPlugin

Lumi 的运行时状态联动层。

监听内核中权威状态的变化,将派生状态(如"当前项目")同步到其他内核服务。

> 命名说明:本插件不止做"监视",还做"响应监视结果派生并落库"。
> 取 `Monitor` 是因为它**不产生**新状态源,只在已有状态之间建立联动规则。

## 当前职责

- **对话选择 → 项目切换**:
  监听 `kernel.conversations?.objectWillChange`,当选中对话的 `projectPath`
  与 `kernel.project?.currentProject.path` 不一致时,自动调用
  `project.openProject(at:)` 跟随切换。

- **项目切换 → 清空当前对话**:
  监听 `kernel.project.objectWillChange`,当 `currentProject.path` 实际发生
  变化时,自动调用 `kernel.conversations?.deselectConversation()`,
  把 `selectedConversationID` 置为 `nil`,避免旧对话与新项目状态不一致。

- **对话切换 → 同步 Provider/Model**:
  监听 `kernel.conversations?.objectWillChange`,当 `selectedConversationID`
  变化且新对话绑定了 provider 时,把对话的 provider/model 写入
  `kernel.llmProviders` 的全局当前选中(`selectProvider(id:)` 与
  `selectModel(providerID:model:)`)。仅在不一致时写入,无绑定则跳过,
  避免覆盖用户刚手动选择的全局值。

实现位于 `Sources/StateMonitorPlugin/Hooks/`:

- `OnConversationSelectedHook.swift` — 从 `ConversationListPlugin` 迁出,
  实现保持不变。
- `OnProjectChangedHook.swift` — 新增,与上一条形成对称联动:

  | 触发源                     | 反应                                  |
  | -------------------------- | ------------------------------------- |
  | 对话选中(且绑定项目)     | 跟随切换到对话绑定的项目 |
  | 当前项目变化             | 清空当前选中的对话            |

  `deselectConversation()` 只重置 `selectedConversationID`,不会触发
  `kernel.project.objectWillChange`,因此不会自我循环。

- `OnConversationProviderModelSyncHook.swift` — 新增,实现单向同步:

  | 触发源                       | 反应                                       |
  | ---------------------------- | ------------------------------------------ |
  | 对话选中(且绑定 provider)    | 同步 provider/model 到内核全局当前选中     |

  不监听 `kernel.llmProviders.objectWillChange`,避免形成「内核全局变 →
  写入某个对话 → 又让本 hook 把全局再覆盖回去」的循环。

## Policy

`.alwaysOn` — 核心联动层,不允许用户禁用。
