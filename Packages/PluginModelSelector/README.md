# PluginModelSelector

Model Selector 插件（KernelCore 体系），由旧版 `Plugins/ModelSelectorPlugin`
（KernelLumi / LumiPlugin 架构）完美复刻而来。

## Features

- **Composer toolbar button** — Action Bar leading 位置的模型选择按钮，实时显示
  「供应商 · 模型」
- **Model browser** — popover 内左右分栏：左侧供应商列表（云端/本地 + API 格式
  筛选 + 搜索），右侧模型列表（搜索 + 能力标签 + 上下文窗口）
- **Persistence** — 选中通过 `LLMProviderManagerProviding` 持久化
  （UserDefaults，key 与旧版一致），发送链路即时生效

## Architecture

| 旧版（LumiPlugin） | 新版（SuperPlugin） |
|--------------------|---------------------|
| `chatSectionActionBarItems(.leading)` | `ChatSectionProviding.addBarItems(.actionLeading)` |
| `kernel.resolveService((any LLMProviderManaging).self)` | `kernel.resolveProvider((any LLMProviderManagerProviding).self)` |
| `.onLumiSelectedRemoteProviderIDDidChange` 等通知 | `ObservableLLMProviderManagerBox`（桥接 `objectWillChange`） |
| `LumiLLMProviderInfo` / `LumiModelInfo` | `LLMProviderInfo` / `LLMModelInfo` |

插件 ID 保持旧值 `com.coffic.lumi.plugin.model-selector`，启用状态与自动化不失效。

## Dependencies

| Package | Description |
|---------|-------------|
| `KernelCore` | SuperPlugin 协议与内核容器 |
| `ProviderChatSection` | Chat 分区 Action Bar 贡献 |
| `ProviderLLMManager` | LLM 供应商注册表 / 选中 / 路由 |
| `LumiUI` | 共享 UI 组件（AppListRow / AppSearchBar / AppTag …） |
| `LocalizationKit` | 运行时本地化 |
