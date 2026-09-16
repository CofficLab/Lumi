# PluginModelSelector

Model Selector 插件（KernelCore 体系），由旧版 `Plugins/ModelSelectorPlugin`
（KernelLumi / LumiPlugin 架构）完美复刻而来。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Features

- **Composer toolbar button** — Action Bar leading 位置的模型选择按钮，实时显示
  「供应商 · 模型」（模型未显式选中时回退供应商默认模型）
- **Model browser** — popover 内左右分栏：左侧供应商列表（常用/云端/本地 + 搜索），
  右侧模型列表（搜索；模型数量不超过 8 个时隐藏搜索框，列表本身已可一览无余）
- **Persistence** — 选中完全直连内核 `LLMManaging` 读写
  （`selectedProviderID` / `selectedModel` / `select(providerID:model:)`），
  由 `DefaultLLMManager` 持久化（UserDefaults，key 与旧版一致），发送链路即时生效；
  通过插件自己的 `provider-usage.json` 持久化常用供应商统计

## Architecture

| 旧版（LumiPlugin） | 新版（SuperPlugin） |
|--------------------|---------------------|
| `chatSectionActionBarItems(.leading)` | `ChatSectionProviding.addBarItems(.actionLeading)` |
| `kernel.resolveService((any LLMProviderManaging).self)` | `kernel.resolveProvider((any LLMManaging).self)` |
| `.onLumiSelectedRemoteProviderIDDidChange` 等通知 | `LLMProviderManagerBox`（桥接 typed provider / conversation events） |
| `LumiLLMProviderInfo` / `LumiModelInfo` | `LLMProviderInfo` / `LLMModelInfo` |

插件 ID 保持旧值 `com.coffic.lumi.plugin.model-selector`，启用状态与自动化不失效。

## Dependencies

| Package | Description |
|---------|-------------|
| `KernelCore` | SuperPlugin 协议与内核容器 |
| `ProviderChatSection` | Chat 分区 Action Bar 贡献 |
| `ProviderLLMManager` | LLM 供应商注册表 / 选中 / 路由 |
| `LumiUI` | 共享 UI 组件（AppListRow / AppSearchBar / AppTag …） |
| `KitLocalization` | 运行时本地化 |

