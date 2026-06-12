# MessageRendererPlugin

Lumi 核心消息渲染插件，基于 `LumiChatMessage` + `LumiMessageRendererItem` 插件体系。

## 架构

```
ChatCoreService
  └─ registerMessageRenderers(PluginService.messageRenderers)
       └─ MessageRendererPlugin (+ ZhipuPlugin 等)
            └─ LumiMessageRendererItem { order, canRender, render }
                 └─ ChatPanelPlugin → ChatMessageBubble → renderer.render(...)
```

- **消息模型**：`LumiCoreKit.LumiChatMessage`
- **渲染注册**：`LumiCoreKit.LumiMessageRendererItem`
- **UI 组件**：`LumiUI`（头像、气泡、按钮）
- **Markdown**：`MarkdownKit.MarkdownBlockRenderer`
- **ToolCall 扩展**：`AgentToolKit.ToolCallRowRendererRegistry`（AskUser 等行级渲染）

## 目录

```
Sources/
├── MessageRendererPlugin.swift   # 注册 8 个核心 renderer
└── Views/
    ├── CoreMessageViews.swift    # CoreMessageView、工具调用行、状态消息
    ├── MessageInfoButton.swift   # Header info popover
    └── LumiToolCallAgentBridge.swift
```

## 核心 Renderer 优先级

| order | id | 匹配 |
|------:|----|------|
| 330 | core-turn-completed | 轮次结束 |
| 320 | core-status-message | status 角色 |
| 300 | core-error-message | error（不含 zhipu-* renderKind） |
| 250 | core-tool-message | tool |
| 200 | core-user-message | user |
| 190 | core-assistant-message | assistant |
| 160 | core-system-message | system |
| 0 | core-default-markdown | 兜底 |

Provider 专用错误 UI（如 Zhipu `zhipu-*`）由各自插件以更高或更精确的 `canRender` 注册。
