# 附件编码后台化实施记录

## 目标

避免图片 base64 和附件 JSON metadata 编码占用 Return → 用户消息可见的主线程时间。

## 实现

- `ComposerView` 在后台读取图片文件并完成 base64 编码，主线程只接收已经准备好的 `UserImageAttachment`；
- `UserFileAttachmentLoader` 已经在后台读取文件、识别文本和编码，本次保持该路径；
- `MessageSendingProviding` 增加 `commitUserMessageInBackground(...)`；
- 两个发送器使用 `.utility` detached task 编码图片/文件 metadata，再回主线程创建 `Message` 并发布插入事件；
- `sendMessage(...)` 携带附件时自动使用后台编码路径，纯文本仍直接同步提交；
- 输入框和 ActionBar 都在附件编码期间保持可响应，编码失败通过原有错误提示反馈；
- 附件快照在提交入口捕获，提交后用户新添加的附件不会被误清空。

## 数据流

```text
拖入图片
  -> 后台读取文件 + base64
  -> 主线程加入附件挂起池

按 Return（带附件）
  -> 同步捕获附件数组
  -> utility 后台 JSON 编码 metadata
  -> 主线程提交带 metadata 的用户消息
  -> 消息列表显示并启动 AgentLoop
```

## 验收

- ProviderMessageSender：8 个测试通过；
- PluginMessageSender：3 个测试通过；
- PluginConversationInput：9 个测试通过；
- 图片编码不再在 `ComposerView` 的 MainActor 任务中执行；
- 带附件的 `sendMessage` 不再在主线程同步执行 metadata JSON 编码。

## 后续边界

下一项 P2-3 是明确持久化队列 QoS 和顺序保证，继续降低后台落盘与用户交互之间的资源竞争。
