# PluginWebSearch

`PluginWebSearch` 是 Lumi 中基于 Package 架构的网页搜索插件。

本 Package 暴露了插件适配器和工具注册层：

- `WebSearchPlugin`：Lumi 插件入口点
- `WebSearchTool`：Agent 工具适配器，用于 `web_search`
- `Resources/WebSearch.xcstrings`：插件专属的本地化资源目录

该工具主要存在的目的是满足 Function Calling 的需求——部分模型（如 Qwen）
要求 `web_search` 必须与 `web_fetch` 同时存在。

## Does & Doesn't

### ✅ Does
- 声明 `web_search` 工具元数据
- 提供 Function Calling 的工具适配层
- 管理插件自身本地化资源

### ❌ Doesn't
- 不管理 Agent 对话状态或 Turn 生命周期（内核职责）
- 不直接执行底层网络请求（工具执行层职责）
- 不提供聊天界面或消息渲染（界面层职责）
- 不管理用户偏好和设置（内核/设置层职责）

## 目录结构

```text
PluginWebSearch
  Package.swift
  Sources/PluginWebSearch
    Resources/WebSearch.xcstrings
    WebSearchPlugin.swift
    WebSearchTool.swift
  Tests/PluginWebSearchTests
    WebSearchPluginTests.swift
```

## 测试

```bash
swift test
```

## 本地化

Package 专属的翻译文件位于 `Sources/PluginWebSearch/Resources/WebSearch.xcstrings`。

本 Package 中的代码应使用 `Bundle.module` 进行本地化，而非使用 App 主 Bundle。插件元数据的本地化请使用 `PluginWebSearchLocalization.string(_:)`，以确保 Package 测试和 App 集成时读取的是同一份资源 Bundle。
