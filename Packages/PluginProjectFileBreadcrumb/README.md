# ProjectFileBreadcrumbPlugin

面板顶部 Header 子插件：当前文件路径面包屑导航。

## 职责

在面板 Header 顶部展示当前文件的路径面包屑，支持点击跳转。

**它只对 `KernelLumi` 负责，对任何编辑器细节都不知情，仅关心当前文件的路径：**

- 当前文件路径取自 `kernel.project?.currentFileURL`（`ProjectProviding`，`@Published`）。
- 项目根取自 `kernel.project?.currentProject?.path`。
- 通过订阅 `kernel.project?.objectWillChange` 响应文件/项目变化。
- 点击跳转调用 `kernel.editorProvider?.openFile(at:)`。

仅显示文件路径段，符号面包屑由 `EditorStickySymbolBarPlugin` 负责。

## 挂载位置

| 属性 | 值 |
|------|-----|
| **类型** | `PanelHeaderItem` |
| **Slot** | `panelHeader` |
| **Order** | 80 |
| **Policy** | `alwaysOn` |

通过 `panelHeaderItems(kernel:)` 贡献 `ProjectFileBreadcrumbHeaderView`。

## 依赖

- `KernelLumi` — 内核契约层（`ProjectProviding`、`EditorProviding`、`PanelHeaderItem`、`LumiPlugin`）
- `LumiUI` — 主题与面板 chrome 组件（`LumiTheme`、`AppToolbarContainer`、`AppPanelChromeMetrics`）
- `LocalizationKit` — 本地化

> 不依赖 `EditorService`，也不依赖任何其他 Plugin 实现。

## 目录结构

```
ProjectFileBreadcrumbPlugin/
├── Package.swift
├── README.md
├── Resources/
│   └── Localizable.xcstrings
├── Sources/
│   ├── ProjectFileBreadcrumbPlugin.swift          # 插件入口，贡献 panelHeaderItems
│   ├── Models/
│   │   └── BreadcrumbItem.swift                   # 路径段数据模型
│   ├── Services/
│   │   ├── ProjectFileBreadcrumbObserver.swift    # 订阅 project.objectWillChange 的适配器
│   │   └── LumiPluginLocalization.swift
│   ├── Views/
│   │   ├── ProjectFileBreadcrumbHeaderView.swift  # 顶层容器（读 kernel.project）
│   │   ├── ProjectFileBreadcrumbPathView.swift    # 路径分段 + 智能截断
│   │   ├── NavComponent.swift                     # 单个路径段组件
│   │   ├── MenuContent.swift                      # 下拉菜单内容
│   │   └── MenuRow.swift                          # 菜单单行
│   └── BreadcrumbNavIconStyle.swift               # 图标命名与着色策略
└── Tests/
    ├── BreadcrumbProjectAffinityTests.swift       # 项目亲和性边界
    └── BreadcrumbNavIconContrastTests.swift       # 图标对比度回归
```

## 相关插件

- `ProjectFilesPlugin` — 同属面板 Header，展示已打开文件列表（订阅范式参考来源）。
- `EditorStickySymbolBarPlugin` — 符号面包屑（与本插件的路径面包屑互补）。
