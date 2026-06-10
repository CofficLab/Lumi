# EditorBreadcrumbNavPlugin

Editor Panel 子插件：Panel Header 面包屑导航。

## 职责

在 Editor Panel 顶部展示当前文件路径面包屑，支持点击跳转。

## 挂载位置

- **类型**：`LumiPanelHeaderItem`
- **Slot**：`panelHeader`
- **Order**：70
- **Activation**：alwaysOn

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorBreadcrumbNavPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorBreadcrumbNavPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorBreadcrumbHeaderPlugin.self`。

## 相关插件

- 父壳：`EditorPanelPlugin`
