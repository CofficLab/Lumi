# EditorTabStripPlugin

Editor Panel 子插件：Panel Header 标签栏。

## 职责

管理已打开文件的 Tab 列表、切换与关闭；并导出 Agent 工具供 EditorPanelPlugin 使用。

## 挂载位置

- **类型**：`LumiPanelHeaderItem`
- **Slot**：`panelHeader`
- **Order**：80
- **Activation**：alwaysOn

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorTabStripPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorTabStripPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorTabStripHeaderPlugin.self`。

## 相关插件

- 被 `EditorPanelPlugin` 依赖（Agent 工具）
