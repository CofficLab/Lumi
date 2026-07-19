# ProjectsPlugin

项目管iving理插件，为 Lumi 应用提供完整的项目管理功能。

## 功能

### 内核服务
- **ProjectService**: 实现 `ProjectProviding` 协议，管理项目状态

### UI 组件
- **TitleToolbarItem**: 标题栏项目控制视图，显示当前项目名称

### Agent Tools
- `list_projects`: 列出已保存的项目
- `add_project`: 添加新项目
- `get_current_project`: 获取当前项目信息

### Middleware
- **ConversationHintMiddleware**: 在消息中添加当前项目路径提示

## 架构

```
ProjectsPlugin
├── ProjectsPlugin.swift          # 主插件类
├── Services/
│   ├── ProjectService.swift      # 内核服务实现
│   └── ProjectsSyncCoordinator   # 状态同步协调器
├── Store/
│   └── ProjectsStore.swift       # 数据持久化
├── ViewModels/
│   └── ProjectsViewModel.swift   # 视图状态管理
├── Models/
│   ├── ProjectEntry.swift        # 项目条目数据模型
│   └── LumiProject.swift         # 类型别名
├── Views/
│   ├── ProjectControlView.swift  # 项目控制按钮
│   ├── ProjectListView.swift     # 项目列表
│   ├── ProjectRowView.swift      # 项目行
│   └── ProjectsPopoverView.swift # 弹出视图
├── Tools/
│   ├── ListProjectsTool.swift
│   ├── AddProjectTool.swift
│   └── GetCurrentProjectTool.swift
└── Middleware/
    └── ConversationHintMiddleware.swift
```

## 依赖

- LumiKernel
- LumiUI
- LocalizationKit
- SuperLogKit

## 使用

通过 LumiFactory 自动注册：

```swift
// LumiFactory/PluginService.swift
list.append(ProjectsPlugin())
```

## License

MIT