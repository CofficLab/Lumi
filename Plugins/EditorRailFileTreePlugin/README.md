# EditorRailFileTreePlugin

Editor Panel 子插件：Editor Rail 文件树。

## 职责

在 Editor 左侧 Rail 展示项目文件树（Explorer）。

## 挂载位置

- **类型**：`LumiPanelRailTabItem`
- **Slot**：`editorRail`
- **Order**：0
- **Activation**：alwaysOn

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorRailFileTreePlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorRailFileTreePlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorRailFileTreePanelPlugin.self`。

## 相关插件

- App 级布局：`LumiApp/Views/Layout/RailView.swift`
