# EditorRailCallHierarchyPlugin

Editor Panel 子插件：Editor Rail 调用层次（薄封装）。

## 职责

在 Rail 中提供 Call Hierarchy 入口，复用 `EditorBottomCallHierarchyPlugin`。

## 挂载位置

- **类型**：`LumiEditorRailTabItem`
- **Slot**：`editorRail`
- **Order**：6
- **Activation**：optOut

## 依赖

- `EditorBottomCallHierarchyPlugin`
- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorRailCallHierarchyPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorRailCallHierarchyPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorRailCallHierarchyPanelPlugin.self`。

## 相关插件

- 核心实现：`EditorBottomCallHierarchyPlugin`
