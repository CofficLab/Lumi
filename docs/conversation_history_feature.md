# 对话历史功能实现说明

## 功能描述
点击侧边栏的对话历史列表中的某个对话 item，将该对话对应的消息显示到聊天界面。

## 修改文件

### 1. AgentProvider.swift
**路径**: `/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Core/Providers/AgentProvider.swift`

**修改内容**:
- 在 `selectedConversationId` 的 `didSet` 中添加通知发送，当选择对话时广播事件
- 添加 `Notification.Name` 扩展，定义 `conversationSelected` 通知

```swift
@Published var selectedConversationId: UUID? {
    didSet {
        if let id = selectedConversationId {
            UserDefaults.standard.set(id.uuidString, forKey: "Agent_SelectedConversationId")
            // 通知加载对话
            NotificationCenter.default.post(name: .conversationSelected, object: id)
        } else {
            UserDefaults.standard.removeObject(forKey: "Agent_SelectedConversationId")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let conversationSelected = Notification.Name("conversationSelected")
}
```

### 2. AssistantViewModel.swift
**路径**: `/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/DevAssistantPlugin/ViewModels/AssistantViewModel.swift`

**修改内容**:
- 将 `chatHistoryService` 从 `private` 改为内部可访问（移除 `private` 关键字）
- 添加 `loadConversation(_:)` 方法，用于加载指定对话的消息

```swift
// 修改访问级别
let chatHistoryService = ChatHistoryService.shared

// 添加新方法
/// 加载指定对话的消息
func loadConversation(_ conversation: Conversation) async {
    if Self.verbose {
        os_log("\(self.t)📥 开始加载对话：\(conversation.title)")
    }
    
    await MainActor.run {
        // 重置状态
        withAnimation {
            depthWarning = nil
            errorMessage = nil
            isProcessing = false
            currentInput = ""
            pendingAttachments.removeAll()
        }
    }
    
    // 设置当前对话
    currentConversation = conversation
    
    // 加载消息
    let loadedMessages = chatHistoryService.loadMessages(for: conversation)
    
    if Self.verbose {
        os_log("\(self.t)📥 加载到 \(loadedMessages.count) 条消息")
    }
    
    // 获取系统提示
    let fullSystemPrompt = await promptService.buildSystemPrompt(
        languagePreference: languagePreference,
        includeContext: isProjectSelected
    )
    
    await MainActor.run {
        // 保留系统消息，添加历史消息
        var newMessages: [ChatMessage] = [ChatMessage(role: .system, content: fullSystemPrompt)]
        newMessages.append(contentsOf: loadedMessages.filter { $0.role != .system })
        
        withAnimation {
            messages = newMessages
        }
    }
    
    if Self.verbose {
        os_log("\(self.t)✅ 对话加载完成：\(conversation.title)")
    }
}
```

### 3. DevAssistantView.swift
**路径**: `/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/DevAssistantPlugin/Views/DevAssistantView.swift`

**修改内容**:
- 添加 `.onReceive` 监听器，接收 `conversationSelected` 通知
- 添加 `loadConversation(_:)` 私有方法，从数据库获取对话并调用 viewModel 加载

```swift
.onReceive(NotificationCenter.default.publisher(for: .conversationSelected)) { notification in
    // 当选择对话时，加载对话消息
    if let conversationId = notification.object as? UUID {
        loadConversation(conversationId)
    }
}

// MARK: - Methods

/// 加载指定对话
private func loadConversation(_ conversationId: UUID) {
    Task { @MainActor in
        // 从数据库获取对话
        if let conversation = viewModel.chatHistoryService.fetchConversation(id: conversationId) {
            await viewModel.loadConversation(conversation)
        }
    }
}
```

### 4. ConversationListView.swift (无需修改)
**路径**: `/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/ConversationListPlugin/Views/ConversationListView.swift`

**说明**: 该文件已经通过 `AgentProvider.shared.selectConversation(conversation.id)` 触发选择事件，无需修改。

## 工作流程

1. **用户点击**：用户在侧边栏点击 `ConversationItemView`
2. **触发选择**：`ConversationItemView` 调用 `agentProvider.selectConversation(conversation.id)`
3. **发布通知**：`AgentProvider` 的 `selectedConversationId` didSet 触发，发送 `.conversationSelected` 通知
4. **监听通知**：`DevAssistantView` 的 `.onReceive` 监听到通知
5. **加载对话**：调用 `loadConversation(_:)` 从数据库获取对话
6. **更新界面**：`AssistantViewModel.loadConversation(_:)` 加载消息并更新 `messages` 数组
7. **显示消息**：`ChatMessagesView` 自动刷新显示历史消息

## 测试步骤

1. 运行应用
2. 确保已选择项目
3. 发送几条消息创建对话历史
4. 点击"新会话"创建新对话
5. 点击侧边栏的历史对话 item
6. 验证聊天界面是否显示对应历史消息

## 注意事项

- 确保 `ChatHistoryService` 已正确初始化（通过 `App.swift` 中的 `modelContainer`）
- 消息加载时会保留系统提示消息，确保对话上下文完整
- 加载对话时会重置输入状态和附件列表
