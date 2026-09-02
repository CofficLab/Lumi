# 持久化队列 QoS 实施记录

## 目标

让消息持久化明确使用低优先级后台资源，不和 Return、消息列表首帧及流式 UI 争抢调度，同时保持消息写入顺序和失败补偿。

## 实现

修改 `Packages/PluginMessageManager/Sources/PluginMessageManager/Managers/MessageManager.swift`：

- `persistQueue` 明确配置为串行 `.utility` 队列；
- user、assistant、tool、error 等非瞬时消息统一走后台 `persistLater`；
- pending buffer 仍在主线程同步更新并对 UI 提供 read-your-writes；
- 持久化成功后才从 pending 移除，失败时保留 pending，交给后续恢复机制；
- `deleteMessage`、`clearMessages` 继续通过 `persistQueue.sync` 排空旧写入，保证删除不会被后台 insert 复活。

## 数据流

```text
insertMessage
  -> pending buffer + UI/event 通知
  -> persistQueue(.utility, serial)
  -> MessageStore.insertMessage
  -> 成功：移除 pending / 发送 saved 通知
  -> 失败：保留 pending，等待补偿
```

## 验收

- 插入后消息仍可立即从内存读路径读取；
- error 消息也经过后台队列并最终落盘；
- 删除、清空和更新操作的顺序语义保持不变；
- PluginMessageManager：16 个测试通过。

## 后续边界

P2 阶段的代码级改动已完成。下一阶段应增加 Return → MessageRowApplied 等 signpost 和基准测试，用实际主线程耗时验证优化收益，并重点观察大附件、长历史和连续发送场景。
