# PluginToolActivity

在会话中展示当前对话的 Agent 工具调用记录（调用名称、参数与结果摘要）。

## 结构

```
Sources/PluginToolActivity/
├── ToolActivityPlugin.swift
├── ToolActivityToolbarView.swift
├── PluginLocalization.swift
└── ...
```

数据来源为 `ToolManagerProviding` 的工具调用记录，入口处解析并向会话区注册展示位。
