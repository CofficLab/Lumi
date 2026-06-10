# EditorRailSymbolsPlugin

Editor Panel 子插件：Editor Rail 符号（薄封装）。

## 职责

在 Rail 中提供 Symbols 入口，复用 `EditorBottomSymbolsPlugin`。

## 挂载位置

- **类型**：`LumiEditorRailTabItem`
- **Slot**：`editorRail`
- **Order**：5
- **Activation**：optOut

## 依赖

- `EditorBottomSymbolsPlugin`
- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorRailSymbolsPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorRailSymbolsPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorRailSymbolsPanelPlugin.self`。

## 相关插件

- 核心实现：`EditorBottomSymbolsPlugin`
