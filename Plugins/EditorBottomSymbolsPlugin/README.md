# EditorBottomSymbolsPlugin

Editor Panel 子插件：Panel Bottom 符号面板。

## 职责

展示工作区符号搜索（Workspace Symbol）结果。

## 挂载位置

- **类型**：`LumiPanelBottomTabItem`
- **Slot**：`panelBottom`
- **Order**：3
- **Activation**：optOut

## 依赖

- `LSPWorkspaceSymbolEditorPlugin`
- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorBottomSymbolsPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorBottomSymbolsPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorBottomSymbolsPanelPlugin.self`。

## 相关插件

- Rail 薄封装：`EditorRailSymbolsPlugin`
