# Conversation Context Size Extraction Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将上下文大小 Chat Toolbar 能力从 `PluginConversationStats` 提取为独立的 `PluginConversationContextSize` Swift Package。

**Architecture:** 保留现有插件 ID `com.coffic.conversation-context-size`、Toolbar placement、排序和 UI 行为，仅迁移上下文插件及其专属视图/格式化工具。`FactoryLumi` 改为依赖并注册新包，`PluginConversationStats` 只保留消息计数、缓存命中率和其它统计能力。

**Tech Stack:** Swift 6 SwiftPM、SwiftUI、KernelCore SuperPlugin、ProviderChatSection、ProviderConversation、ProviderMessage、ProviderLLMManager、ProviderLLMVendors、Swift Testing。

---

### Task 1: 创建独立包

**Files:**
- Create: `Packages/PluginConversationContextSize/Package.swift`
- Create: `Packages/PluginConversationContextSize/Sources/PluginConversationContextSize/*`
- Create: `Packages/PluginConversationContextSize/Tests/PluginConversationContextSizeTests/*`

迁移 `ConversationContextSizePlugin`、`ContextSizeToolbarView`、`TokenFormatting` 和本地化支持，保持原 import/module 兼容逻辑，并为格式化与插件元数据增加测试。

### Task 2: 移除旧包中的上下文能力

**Files:**
- Delete: `Packages/PluginConversationStats/Sources/PluginConversationStats/ConversationContextSizePlugin.swift`
- Delete: `Packages/PluginConversationStats/Sources/PluginConversationStats/ContextSizeToolbarView.swift`
- Delete: `Packages/PluginConversationStats/Sources/PluginConversationStats/TokenFormatting.swift`

从 `PluginConversationStats/Package.swift` 删除不再需要的 LLM/provider 依赖，并保留其他统计插件所需依赖。

### Task 3: 接入 Factory

**Files:**
- Modify: `Packages/FactoryLumi/Package.swift`
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift`

将依赖与 import 从 `PluginConversationStats` 的上下文实现迁移到 `PluginConversationContextSize`，Factory 继续注册同一插件 ID。

### Task 4: 验证

运行：

```bash
swift test --package-path Packages/PluginConversationContextSize
swift test --package-path Packages/PluginConversationStats
swift test --package-path Packages/FactoryLumi
```

检查新旧包都能通过构建，Factory 的插件列表中只出现一个上下文大小插件，并确认工作区现有未提交改动不被覆盖。
