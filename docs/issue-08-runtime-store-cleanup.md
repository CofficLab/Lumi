# Issue #8: ConversationRuntimeStore 清理不彻底

**严重程度**: 🟡 Medium  
**状态**: Open  
**文件**: `LumiApp/Core/Stores/ConversationRuntimeStore.swift`

---

## 问题描述

`cleanupConversationState` 方法清理了大部分会话状态，但遗漏了部分与特定会话相关的状态数据，可能导致内存泄漏。

## 遗漏的清理操作

1. `postProcessedMessageIdsByConversation[conversationId]` - 后处理消息 ID
2. `lastUserSendAtByConversation[conversationId]` - 最后发送时间
3. `lastUserSendContentByConversation[conversationId]` - 最后发送内容
4. `streamStartedAtByConversation[conversationId]` - 流开始时间
5. `didReceiveFirstTokenByConversation` - Set 类型需要特殊处理
6. `statusMessageIdByConversation[conversationId]` - 状态消息 ID

## 建议修复

```swift
func cleanupConversationState(_ conversationId: UUID) {
    // ... 现有清理代码 ...

    // 添加遗漏的清理
    postProcessedMessageIdsByConversation.removeValue(forKey: conversationId)
    lastUserSendAtByConversation.removeValue(forKey: conversationId)
    lastUserSendContentByConversation.removeValue(forKey: conversationId)
    streamStartedAtByConversation.removeValue(forKey: conversationId)
    didReceiveFirstTokenByConversation.remove(conversationId)
    statusMessageIdByConversation.removeValue(forKey: conversationId)
    lastHeartbeatByConversation.removeValue(forKey: conversationId)
}
```

## 修复优先级

中 - 可能导致长期使用后的内存泄漏