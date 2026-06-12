# EditorStickySymbolBarPlugin

Editor Panel 子插件：Panel Header 粘性符号栏（当前禁用）。

## 职责

在编辑器顶部展示当前光标所在符号上下文；目前处于 disabled 状态。

## 挂载位置

- **类型**：`LumiPanelHeaderItem`
- **Slot**：`panelHeader`
- **Order**：90
- **Activation**：disabled

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorStickySymbolBarPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorStickySymbolBarPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorStickySymbolBarHeaderPlugin.self`。

## 相关插件

- 被 `EditorPanelPlugin` 依赖
