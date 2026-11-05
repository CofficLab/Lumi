# PluginFinder

Finder 插件：让 LLM 通过调用工具，在聊天消息区渲染一张可交互的小卡片，
卡片上的按钮点击后在 **Finder** 中打开指定文件夹。

## 它解决什么问题

消息渲染器（`MessageRenderingProviding`）只负责「把一条消息画成什么」，
但默认渲染器画不出「带按钮、点了能打开文件夹」的交互卡片。
本插件提供了这条缺失的通路：

```
LLM 调用 show_folder_card 工具
        ↓
插件插入一条带 renderKind 的时间线消息
        ↓
消息渲染器命中 → 渲染一张 AppCard 小卡片
        ↓
用户点击卡片按钮 → NSWorkspace 在 Finder 中打开该文件夹
```

## 结构

| 路径 | 内容 |
|------|------|
| `Sources/PluginFinder/Models/` | 卡片载荷模型与时间线消息构造 |
| `Sources/PluginFinder/Tools/` | LLM 可调用的 `show_folder_card` 工具 |
| `Sources/PluginFinder/Services/` | 消息桥（工具 → 消息管理器）与 Finder 打开服务 |
| `Sources/PluginFinder/Views/` | 卡片视图与消息渲染器 |
| `Resources/Localizable.xcstrings` | 多语言文案 |

## 工具

`show_folder_card`

| 参数 | 必填 | 说明 |
|------|:----:|------|
| `path` | ✅ | 要在 Finder 中打开的文件夹绝对路径 |
| `title` | ⬚ | 卡片标题，缺省用文件夹名 |
| `description` | ⬚ | 卡片副标题，说明这个文件夹是什么 |

## 时间线消息

工具产出的消息带 `renderKind = "finder-card"`，并被
`MessageTimelineEvent.isTimelineEvent` 识别，因此**不会回流到 LLM 上下文**——
卡片只是给人看的界面产物，不是一次对话轮次。

## 依赖

- `KernelCore` — `SuperPlugin` / `PluginMetadata` / `KernelCoreContainer`
- `KitAgentTool` — `SuperAgentTool` 工具协议
- `ProviderMessage` — 消息模型与时间线事件
- `ProviderMessageRendering` — `MessageRendererItem` 渲染器协议
- `ProviderToolManager` — 工具注册能力
- `LumiUI` — `AppCard` / `AppButton` 等设计系统组件
