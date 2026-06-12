# EditorOutlineRailPlugin

Editor Panel 子插件：Editor Rail 大纲。

## 职责

在 Editor Rail 展示当前文件符号大纲（Outline）。

## 挂载位置

- **类型**：`LumiPanelRailTabItem`
- **Slot**：`editorRail`
- **Order**：1
- **Activation**：alwaysOn

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorOutlineRailPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorOutlineRailPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorRailOutlinePanelPlugin.self`。

## 相关插件

- App 级布局：`LumiApp/Views/Layout/RailView.swift`
