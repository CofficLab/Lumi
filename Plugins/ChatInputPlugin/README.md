# ChatInputPlugin

聊天输入插件。

## 功能

负责在支持 AI Chat 的右侧栏中提供输入区域。

- 文本输入编辑器
- 发送按钮
- Slash command 建议
- `addToChat` 通知接入，并按窗口 ID 过滤多窗口事件
- 本地化字符串资源

## 配置

该插件为 `alwaysOn` 模式，默认启用且不可手动关闭。

## 依赖

| Package | 说明 |
| --- | --- |
| `EditorChatInputKit` | 聊天输入编辑能力 |
| `LumiCoreKit` | 插件协议与窗口对话上下文 |
| `SuperLogKit` | 日志能力 |

## 结构

```text
Sources/
├── ChatInputPlugin.swift              # 插件入口
├── ChatInputRuntime.swift             # 运行时桥接
├── InputView.swift                    # 输入区 UI
├── CommandSuggestionView.swift        # Slash command 建议 UI
└── Resources/
    └── ChatInputPlugin.xcstrings      # 本地化字符串
Tests/
└── PluginChatInputTests.swift
```

## 测试

```bash
swift test
```

