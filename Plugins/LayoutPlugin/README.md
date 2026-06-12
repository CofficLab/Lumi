# 📐 LayoutPlugin

布局持久化插件，负责观察 `WindowLayoutVM` 中的布局状态变化并持久化到磁盘，以及在应用启动时自动恢复上次的布局状态。

## 功能

- **状态恢复** — 应用启动时从本地存储读取已保存的布局状态
- **自动保存** — 监听 `WindowLayoutVM` 属性变化，自动持久化到 plist 文件
- **布局菜单** — 在编辑器和聊天模式下提供布局调整工具栏按钮

## 持久化的状态

| 状态 | plist key |
|------|-----------|
| ActivityBar 选中图标 | `activeViewContainerIcon` |
| 侧边栏 Tab ID | `selectedAgentSidebarTabId` |
| Detail 视图 ID | `selectedAgentDetailId` |
| 分栏宽度比例 | `layoutRatios` |
| 底部面板可见性 | `bottomPanelVisible` |
| 内容面板可见性 | `contentPanelVisible` |
| 编辑器区域可见性 | `editorVisible` |
| Rail 区域可见性 | `railVisible` |
| 右侧栏可见性 | `rightSidebarVisible` |

## 存储位置

`AppConfig.getDBFolderURL()/LayoutPlugin/settings.plist`

## Policy

`.alwaysOn` — 核心布局基础设施插件，不允许用户禁用。
