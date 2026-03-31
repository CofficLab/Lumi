# ConversationList Plugin

## 功能简介

显示所有对话历史记录的侧边栏列表，支持分页加载、会话选择、删除等操作。

## 主要特性

- **分页加载**：使用分页方式渲染会话列表，避免一次性加载全部历史记录
- **会话选择**：支持选中特定会话，并在应用重启后恢复选择状态
- **会话删除**：右键菜单删除会话，带确认对话框
- **实时同步**：通过 `NotificationCenter` 监听会话变更，增量更新列表
- **折叠面板**：支持折叠/展开侧边栏
- **时间显示**：量化显示相对时间（刚刚、X秒前、X分钟前等）

## 目录结构

```
ConversationListPlugin/
├── ConversationListPlugin.swift         # 插件主入口
├── ConversationList.xcstrings           # 国际化资源
├── ConversationListLocalStore.swift     # 本地存储
├── ConversationListPluginREADME.md      # 插件文档
└── Views/                               # 视图文件
    ├── ConversationListView.swift       # 主列表视图
    ├── ConversationListHeader.swift     # 列表头部
    ├── ConversationItemView.swift       # 会话项视图
    └── ConversationListEmptyView.swift  # 空状态视图
```

## 数据流

```
┌─────────────────────┐
│  ConversationListPlugin (actor)        插件注册
│  └─ addSidebarView() ──────────────────► 提供 ConversationListView
└─────────────────────┘

┌─────────────────────┐
│  ConversationListView                   主视图
│  ├─ @EnvironmentObject ConversationVM  从内核获取会话数据
│  ├─ ConversationListLocalStore         持久化选中状态
│  └─ 分页加载逻辑                         每页 40 条
└─────────────────────┘
         │
         ├─► ConversationListHeader      头部（折叠控制）
         ├─ ConversationItemView         会话项（显示标题、时间、项目）
         └─ ConversationListEmptyView    空状态

┌─────────────────────┐
│  ConversationListLocalStore            配置存储
│  └─ settings/conversation_selection.plist  存储选中的会话 ID
└─────────────────────┘
```

## 存储位置

```
~/Library/Application Support/com.cofficlab.Lumi/db_{debug|production}/
└── ConversationListPlugin/
    └── settings/
        └── conversation_selection.plist  # 选中的会话 ID
```

## 国际化

支持三种语言：
- 英语 (en)
- 简体中文 (zh-Hans)
- 繁体中文 (zh-HK)

所有用户可见文本均通过 `String(localized:table:)` 实现。

## 关键组件

### ConversationListView

- **职责**：主列表视图，管理分页加载、选择状态同步
- **分页大小**：每页 40 条记录
- **状态管理**：
  - `conversations`: 当前页已加载的会话
  - `localSelectedConversationId`: 本地选择的会话 ID
  - `nextOffset`: 下一页偏移量
  - `hasMore`: 是否还有更多数据

### ConversationItemView

- **职责**：显示单个会话的信息
- **显示内容**：
  - 会话标题（最多 1 行，超出截断）
  - 项目名称（如果关联了项目）
  - 相对时间（量化显示，避免频繁跳变）
- **交互**：
  - 右键菜单：删除会话
  - 点击：选中会话

### ConversationListLocalStore

- **职责**：持久化选中的会话 ID
- **存储格式**：Binary Property List (plist)
- **线程安全**：使用 `DispatchQueue` 保证并发访问安全
- **数据迁移**：支持从旧版本 `app_settings` 迁移数据

## 事件流

### 会话创建
```
NotificationCenter (.conversationDidChange)
    ↓
handleConversationCreated()
    ↓
conversations.insert(at: 0)
    ↓
syncSelectionFromViewModel()
```

### 会话删除
```
用户右键点击 → 删除
    ↓
handleDelete() - 从本地列表移除（即时响应）
    ↓
conversationVM.deleteConversation() - 通知内核
    ↓
NotificationCenter (.conversationDidChange)
    ↓
handleConversationDeleted() - 确保同步
```

### 会话选择
```
用户点击会话
    ↓
localSelectedConversationId 改变
    ↓
handleLocalSelectionChange()
    ↓
conversationVM.setSelectedConversation()
    ↓
ConversationListLocalStore.saveSelectedConversationId() - 持久化
```

## 注意事项

1. **分页加载**：列表采用分页渲染，避免大量数据导致性能问题
2. **状态同步**：通过 `onChange` 和 `NotificationCenter` 确保本地状态与内核 `ConversationVM` 同步
3. **时间量化**：`coarseRelativeTime` 函数将时间量化显示，减少 UI 频繁跳变
4. **数据迁移**：首次运行时从旧版本 `app_settings` 迁移选中状态

## 依赖关系

- **MagicKit**: 提供内核能力（`ConversationVM`、`AppConfig` 等）
- **SwiftUI**: UI 框架
- **SwiftData**: 会话数据模型
- **Foundation**: 文件存储、并发控制

## 版本历史

### v1.0.0
- 初始版本
- 支持分页加载、会话选择、删除
- 完整国际化支持
- 符合插件规范
