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

实现位于 `Sources/StateMonitorPlugin/Hooks/OnConversationSelectedHook.swift`。
从 `ConversationListPlugin` 迁出,实现保持不变。

## Policy

`.alwaysOn` — 核心联动层,不允许用户禁用。
