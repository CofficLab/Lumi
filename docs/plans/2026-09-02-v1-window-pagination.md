# V1/brief 消息窗口分页实施记录

## 目标

保证 brief 模式下“发送并回车 → 消息列表立即出现”的主路径不因历史消息数量增长而退化。

## 实现范围

修改 `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/ListV1ViewModel.swift`：

- 首次激活使用 `MessageListPaginationService.loadFirstPage`，只读取最新消息窗口；
- 尾部刷新使用 `refreshTail`，只合并最新页，同时保留用户已经加载的更早窗口；
- 加载更早内容使用消息 ID 游标，不再读取全量消息后过滤 turn；
- `AgentTurnRecordBuilder` 和 `AgentTurnSummaryBuilder` 只处理当前窗口；
- 新消息通过 `MessageChange.inserted` 直接加入窗口并立即重建展示；
- 编辑、删除等暂未携带完整 payload 的变化，继续由 `objectWillChange` 触发兜底刷新；
- 插入事件对应的 `objectWillChange` 会被消费，避免同一条消息再次触发数据库刷新。

## 关键行为

```text
回车
  -> MessageManager 写入内存 pending buffer
  -> MessageChange.inserted(message) 同步通知
  -> V1 合并 messageWindow
  -> 重建当前可见 AgentTurn
  -> 消息列表立即出现
```

数据库持久化和 AgentLoop 后续处理不再阻塞这条可见性路径。首次打开或历史加载仍然是异步分页读取。

## 验收标准

- V1 激活、刷新、加载更早内容不调用 `messagesSnapshot(in:)`；
- 当前会话插入消息后，`pendingUserMessages` 和 `agentTurns` 立即包含该消息；
- 编辑消息仍能通过 `objectWillChange` 最终更新列表；
- 消息列表测试全部通过；
- 代码中没有因 V1 刷新重新物化整个会话历史的路径。

## 验证

在 `Packages/PluginMessageList` 执行：

```bash
swift test
```

本次实现新增了 V1 插入事件回归覆盖，并与现有 V2/V3、分页、刷新门禁测试一起通过。

## 后续工作

当前窗口按消息分页，不按 turn 分页。若后续发现最早可见 turn 因用户消息落在窗口外而缺少关联消息，再增加“窗口前置一条消息”或按 turn 边界补读策略；该优化不应回退到全量扫描。
