# AgentAvailableToolsPlugin

## 功能简介

在聊天工具栏右侧提供可用工具按钮，点击后弹出 Sheet 展示当前会话可用的所有 Agent 工具列表，支持搜索过滤。

## 目录结构

```
AgentAvailableToolsPlugin/
├── AgentAvailableToolsPlugin.swift                # 插件主入口
├── AgentAvailableToolsPlugin.xcstrings             # 国际化字符串
└── Views/
    ├── AvailableToolsButton.swift                  # 工具栏按钮
    └── AvailableToolsListSheetView.swift           # 工具列表 Sheet
```

## 数据流

1. `AvailableToolsButton` — 从 `ConversationTurnServices.toolService.tools` 获取工具列表
2. 点击按钮 → 弹出 `AvailableToolsListSheetView`
3. Sheet 支持按工具名 / 描述搜索，实时过滤
