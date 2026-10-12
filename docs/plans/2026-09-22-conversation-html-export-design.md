# 当前对话 HTML 导出插件设计

## 目标

新增独立的 `PluginConversationExport`。插件在 ChatToolbar 贡献一个导出入口，把点击时选中的当前对话导出为可离线打开的单文件 HTML，不修改 Conversation、Message 或 ChatSection Provider 的职责。

## 架构

- `ConversationExportPlugin` 在启动时解析 `ChatSectionProviding`、`ConversationManaging` 和 `MessageManaging`，注册 `.toolbarTrailing` 项；关闭时撤回贡献并取消观察。
- `ConversationExportViewModel` 跟踪当前选中会话。点击导出后，通过 `messagesSnapshot(in:)` 异步读取完整快照，在后台生成 HTML，再交给 SwiftUI `fileExporter` 显示系统保存界面。
- `ConversationHTMLExporter` 是不依赖 UI 的纯转换层，负责排序、HTML 转义、元数据、消息、推理、工具调用以及附件的自包含输出。
- `ConversationHTMLDocument` 只负责把 UTF-8 数据交给系统文档导出器，因此 macOS 与 iOS 使用同一条保存链路。

## 输出和安全边界

HTML 不加载 CDN、脚本或远程字体，样式全部内嵌。标题、路径、消息正文、推理内容、工具参数与结果全部经过 HTML 转义。图片附件使用校验后的 `data:` URI；文件附件以下载链接和可选文本预览呈现。建议文件名由会话标题和 UTC 导出时间组成，并过滤路径分隔符、控制字符和系统不安全字符。

导出读取的是点击瞬间的会话 ID，即使用户随后切换会话，也不会把两个会话混入同一个文件。没有选中会话或正在准备文件时按钮不可用。

## 验证

1. 插件包测试验证 ChatToolbar 项的注册与撤回。
2. 纯导出测试验证消息排序、HTML 注入防护、UTF-8 文件名、推理与工具调用保留。
3. 附件测试验证用户图片、文件和工具结果图片可安全内嵌。
4. FactoryLumi 集成测试验证完整内核启动后默认目录确实注册导出按钮。
