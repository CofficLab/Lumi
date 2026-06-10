# EditorBottomTerminalPlugin

Editor Panel 子插件：Panel Bottom 终端。

## 职责

在 Editor Panel 底部嵌入集成终端（基于 TerminalCoreKit）。

## 挂载位置

- **类型**：`LumiPanelBottomTabItem`
- **Slot**：`panelBottom`
- **Order**：100
- **Activation**：alwaysOn

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `TerminalCoreKit`

## 目录结构

```
EditorBottomTerminalPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorBottomTerminalPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorBottomTerminalPanelPlugin.self`。

## 相关插件

- 被 `EditorPanelPlugin` 依赖
