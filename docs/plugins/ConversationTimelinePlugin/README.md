# ConversationTimelinePlugin

## 功能描述

在状态栏显示一个对话时间线图标，点击后弹出 Popover 显示当前对话的消息历史时间线。

## 主要特性

- ✅ **状态栏图标**: 在底部状态栏右侧显示时间线图标和消息数量
- ✅ **时间线展示**: 以时间线的形式展示所有消息，包括用户、助手、系统、工具等所有类型的消息
- ✅ **消息预览**: 每条消息显示前 50 个字符的预览
- ✅ **角色标识**: 不同角色使用不同的颜色和图标标识
- ✅ **时间戳**: 显示每条消息的发送时间
- ✅ **模型信息**: 显示使用的 LLM 提供商和模型名称
- ✅ **工具调用标记**: 标识包含工具调用的消息
- ✅ **错误标记**: 标识错误消息

## 文件结构

```
ConversationTimelinePlugin/
├── ConversationTimelinePlugin.swift          # 插件主类
├── ConversationTimeline.xcstrings           # 本地化字符串
├── Views/
│   ├── ConversationTimelineView.swift       # 状态栏视图
│   └── ConversationTimelineDetailView.swift  # Popover 详情视图
└── README.md                                # 说明文档
```

## UI 设计

### 状态栏显示
- 图标: `timeline.selection`
- 文本: "X 条消息"
- 样式: 与其他状态栏插件保持一致

### Popover 时间线
- 最大高度: 400pt
- 标题栏: 显示对话标题和消息数量，包含刷新按钮
- 时间线样式:
  - 左侧时间轴: 彩色圆点 + 连接线
  - 右侧消息卡片: 包含角色、时间、内容预览、模型信息等

### 角色配色
- 用户: 蓝色 (`.blue`)
- 助手: 绿色 (`.green`)
- 系统: 橙色 (`.orange`)
- 工具: 紫色 (`.purple`)
- 状态: 青色 (`.cyan`)
- 错误: 红色 (`.red`)
- 未知: 灰色 (`.gray`)

## 技术实现

- 使用 `StatusBarHoverContainer` 实现 hover 效果和 Popover
- 通过 `ConversationVM.selectedConversationId` 获取当前对话
- 使用 SwiftData `@Query` 和 `FetchDescriptor` 查询对话数据
- 使用 `LazyVStack` 优化长列表性能

## 依赖

- `MagicKit`: 提供基础插件协议和 UI 组件
- `SwiftUI`: UI 框架
- `SwiftData`: 数据持久化

## 配置

- 插件 ID: `ConversationTimeline`
- 显示名称: `对话时间线`
- 图标: `timeline.selection`
- Order: `97`
- 可配置: `false` (始终启用)
