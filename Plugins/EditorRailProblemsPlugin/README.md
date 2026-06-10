# EditorRailProblemsPlugin

Editor Panel 子插件：Editor Rail 问题（薄封装）。

## 职责

在 Rail 中提供 Problems 入口，复用 `EditorBottomProblemsPlugin` 的视图与逻辑。

## 挂载位置

- **类型**：`LumiEditorRailTabItem`
- **Slot**：`editorRail`
- **Order**：2
- **Activation**：optOut

## 依赖

- `EditorBottomProblemsPlugin`
- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorRailProblemsPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorRailProblemsPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorRailProblemsPanelPlugin.self`。

## 相关插件

- 核心实现：`EditorBottomProblemsPlugin`
