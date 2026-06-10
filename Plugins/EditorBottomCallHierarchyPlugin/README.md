# EditorBottomCallHierarchyPlugin

Editor Panel 子插件：Panel Bottom 调用层次面板。

## 职责

展示当前符号的 Call Hierarchy（调用方/被调用方）。

## 挂载位置

- **类型**：`LumiPanelBottomTabItem`
- **Slot**：`panelBottom`
- **Order**：4
- **Activation**：optOut

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorBottomCallHierarchyPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorBottomCallHierarchyPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorBottomCallHierarchyPanelPlugin.self`。

## 相关插件

- Rail 薄封装：`EditorRailCallHierarchyPlugin`
