# ConversationTimelinePlugin

对话时间线状态栏插件。

## 功能

在状态栏显示对话图标，点击显示当前对话的消息历史时间线。

## 配置

该插件为 `alwaysOn` 模式，默认启用且不可手动关闭。

## 结构

```
Sources/
├── ConversationTimelinePlugin.swift  # 插件入口
├── Models/
│   └── MessageTimelineItem.swift
├── Views/
│   ├── ConversationHandoffSidebarSection.swift
│   ├── ConversationTimelineDetailView.swift
│   ├── ConversationTimelineEmptyState.swift
│   ├── ConversationTimelineHeader.swift
│   ├── ConversationTimelineView.swift
│   └── MessageTimelineRow.swift
├── Services/
│   ├── ConversationHandoffSummaryService.swift
│   └── ConversationTimelineService.swift
└── Resources/
    └── ConversationTimeline.xcstrings
```
