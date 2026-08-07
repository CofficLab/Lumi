# ConversationVerbosityPlugin

响应详细程度切换插件。

## 功能

在右侧栏底部工具栏注入简洁/正常/详细切换按钮。

- **有选中对话时**：显示并修改当前对话的详细程度，同时同步到全局设置。
- **无选中对话时**：显示并修改全局详细程度，将用于后续新建的对话。

Popover 标题会动态切换为「当前对话详细程度」或「全局详细程度」，并附带作用域说明。

## 配置

该插件为 `alwaysOn` 模式，默认启用且不可手动关闭。

## 结构

```
Sources/
├── ConversationVerbosityPlugin.swift   # 插件入口
├── Hooks/
│   └── WillSendToLLM.swift             # 发送前注入 verbosity 指令
├── Views/
│   ├── VerbosityToolbarView.swift      # 工具栏按钮
│   ├── VerbosityPopoverView.swift      # 弹出选择面板
│   ├── VerbosityRowView.swift          # 单行选项
│   └── VerbosityLevelColors.swift      # 颜色扩展
└── Resources/
    └── Localizable.xcstrings
```
