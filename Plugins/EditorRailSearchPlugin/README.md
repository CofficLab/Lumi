# EditorRailSearchPlugin

Editor Panel 子插件：Editor Rail 搜索（薄封装）。

## 职责

在 Rail 中提供 Search 入口，复用 `EditorBottomSearchPlugin`。

## 挂载位置

- **类型**：`LumiEditorRailTabItem`
- **Slot**：`editorRail`
- **Order**：4
- **Activation**：optOut

## 依赖

- `EditorBottomSearchPlugin`
- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorRailSearchPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorRailSearchPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorRailSearchPanelPlugin.self`。

## 相关插件

- 核心实现：`EditorBottomSearchPlugin`
