# 发送快速提交实施记录

## 目标

让用户按下 Return 后，用户消息先进入内存时间线并立即触发消息列表更新；AgentLoop 的完整回合不参与首帧等待。

## 实现范围

新增 `MessageSendingProviding` 的快速提交能力：

- `commitUserMessage(...)`：同步完成会话解析、附件快照编码、用户消息写入 pending buffer 和插入事件发布；
- `startTurn(for:)`：在提交完成后异步跟踪对应回合；
- `sendMessage(...)` 保留原有 async 接口，并改为组合上述两个阶段，因此既兼容现有调用方，又不改变原有“等待回合结束”的语义；
- `MessageSendCommit` 携带会话 ID 和用户消息 ID，发送中排队时通过 `wasQueued` 表示没有立即创建消息；
- 增加 `pendingTurnStarts` 标记，避免提交完成到回合 Task 调度之间的极短窗口破坏连续发送的串行队列。

涉及文件：

- `Packages/ProviderMessageSender/Sources/ProviderMessageSender/MessageSendingProviding.swift`
- `Packages/ProviderMessageSender/Sources/ProviderMessageSender/DefaultMessageSender.swift`
- `Packages/PluginMessageSender/Sources/PluginMessageSender/MessageSender.swift`
- `Packages/PluginConversationInput/Sources/PluginConversationInput/Views/ConversationInputView.swift`
- `Packages/PluginConversationInput/Sources/PluginConversationInput/ViewModels/SendActionBarViewModel.swift`

## 数据流

```text
Return
  -> 同步捕获文本和附件
  -> commitUserMessage
  -> MessageManager.insertMessage
  -> MessageChange.inserted
  -> 消息列表直接显示用户消息
  -> Task { @MainActor in startTurn(...) }
  -> AgentLoop 已由消息插入观察者触发，发送器异步等待回合状态
```

## 保持的行为

- 同一会话已有回合时，新消息仍进入 pending 队列；
- 空文本且无附件仍然直接忽略；
- 数据库落盘失败、回合失败和取消处理沿用现有路径；
- 旧的 `sendMessage` 调用仍等待完整 AgentLoop 回合。

## 验收结果

- 快速提交测试验证：`commitUserMessage` 返回后即可从消息管理器读取用户消息；
- 连续提交测试验证：回合尚未调度时，第二条消息仍进入 pending 队列；
- ProviderMessageSender：8 个测试通过；
- PluginMessageSender：3 个测试通过；
- PluginConversationInput：9 个测试通过。

## 后续边界

当前提交阶段仍会同步执行附件 metadata 编码。下一项 P2-2 应将图片 base64 和文件 metadata 编码移出 Return 关键路径，同时继续保证附件快照与消息提交的一致性。
