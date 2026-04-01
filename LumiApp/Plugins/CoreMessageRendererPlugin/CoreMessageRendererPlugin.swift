import SwiftUI

// MARK: - 核心消息渲染插件

/// 核心消息渲染插件
///
/// 负责注册所有内置消息渲染器，包括：
/// - 用户消息渲染器
/// - 助手消息渲染器
/// - 系统消息渲染器（含工具输出、本地模型加载）
/// - 状态消息渲染器（含轮次结束分隔线）
/// - 错误消息渲染器
///
/// 这个插件将原本硬编码在 AgentMessagesPlugin 中的渲染逻辑集中管理，
/// 使 AgentMessagesPlugin 只负责消息列表的展示，而不关心具体的消息类型和渲染方式。
actor CoreMessageRendererPlugin: SuperPlugin {
    static let id = "CoreMessageRenderer"
    static let displayName = String(localized: "核心消息渲染器", table: "CoreMessageRenderer")
    static let description = String(localized: "提供内置消息类型的渲染支持", table: "CoreMessageRenderer")
    static let iconName = "paintbrush.fill"
    static var order: Int { 10 }  // 最先加载，确保内置渲染器先注册
    static let enable: Bool = true
    static var isConfigurable: Bool { false }  // 核心插件，不可禁用
    
    nonisolated func onRegister() {
        // 注册所有内置渲染器
        Task { @MainActor in
            MessageRendererVM.shared.register([
                // 系统消息渲染器（优先级最高）
                TurnCompletedRenderer(),
                LoadingLocalModelRenderer(),
                ToolOutputRenderer(),
                
                // 角色消息渲染器
                UserMessageRenderer(),
                AssistantMessageRenderer(),
                SystemMessageRenderer(),
                StatusMessageRenderer(),
                ErrorMessageRenderer(),
                
                // 兜底渲染器（优先级最低）
                DefaultMarkdownRenderer()
            ])
        }
    }
    
    nonisolated func onEnable() {
        // 核心插件始终启用
    }
    
    nonisolated func onDisable() {
        // 核心插件不可禁用，此方法不会被调用
    }
}

// MARK: - 内置渲染器实现

/// 对话轮次结束分隔线渲染器
private struct TurnCompletedRenderer: SuperMessageRenderer {
    static let id = "turn-completed"
    static let priority = 200  // 最高优先级
    
    func canRender(message: ChatMessage) -> Bool {
        message.content == ChatMessage.turnCompletedSystemContentKey
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(TurnCompletedDivider(message: message))
    }
}

/// 本地模型加载状态渲染器
private struct LoadingLocalModelRenderer: SuperMessageRenderer {
    static let id = "loading-local-model"
    static let priority = 190
    
    func canRender(message: ChatMessage) -> Bool {
        message.content == ChatMessage.loadingLocalModelSystemContentKey
            || message.content == ChatMessage.loadingLocalModelDoneSystemContentKey
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 4) {
                MessageHeaderView {
                    AppIdentityRow(
                        title: "System",
                        titleColor: AppUI.Color.semantic.textSecondary
                    )
                } trailing: {
                    Text(formatTimestamp(message.timestamp))
                        .font(AppUI.Typography.caption2)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                }
                
                LoadingLocalModelSystemMessageView(message: message)
                    .messageBubbleStyle(role: message.role, isError: false)
            }
        )
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }
}

/// 工具输出渲染器
private struct ToolOutputRenderer: SuperMessageRenderer {
    static let id = "tool-output"
    static let priority = 180
    
    func canRender(message: ChatMessage) -> Bool {
        message.role == .system && message.isToolOutput
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 4) {
                RoleLabel.tool
                ToolOutputView(message: message)
            }
        )
    }
}

/// 用户消息渲染器
private struct UserMessageRenderer: SuperMessageRenderer {
    static let id = "user-message"
    static let priority = 150
    
    func canRender(message: ChatMessage) -> Bool {
        message.role == .user
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(UserMessage(message: message, showRawMessage: showRawMessage))
    }
}

/// 助手消息渲染器
private struct AssistantMessageRenderer: SuperMessageRenderer {
    static let id = "assistant-message"
    static let priority = 150
    
    func canRender(message: ChatMessage) -> Bool {
        message.role == .assistant
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        // 注意：这里简化处理，实际应用中需要处理流式消息和工具调用
        // 使用 AssistantMessage 组件来处理复杂的逻辑
        AnyView(
            AssistantMessage(
                message: message,
                isLastMessage: false,
                relatedToolOutputs: [],  // 渲染器无法获取关联的工具输出，由列表层处理
                showRawMessage: showRawMessage
            )
        )
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }
}

/// 系统消息渲染器
private struct SystemMessageRenderer: SuperMessageRenderer {
    static let id = "system-message"
    static let priority = 150
    
    func canRender(message: ChatMessage) -> Bool {
        message.role == .system && !message.isToolOutput
            && message.content != ChatMessage.loadingLocalModelSystemContentKey
            && message.content != ChatMessage.loadingLocalModelDoneSystemContentKey
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(SystemMessage(message: message, showRawMessage: showRawMessage))
    }
}

/// 状态消息渲染器
private struct StatusMessageRenderer: SuperMessageRenderer {
    static let id = "status-message"
    static let priority = 150
    
    func canRender(message: ChatMessage) -> Bool {
        message.role == .status && message.content != ChatMessage.turnCompletedSystemContentKey
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(StatusMessage(message: message))
    }
}

/// 错误消息渲染器
private struct ErrorMessageRenderer: SuperMessageRenderer {
    static let id = "error-message"
    static let priority = 160  // 错误消息优先级稍高
    
    func canRender(message: ChatMessage) -> Bool {
        message.role == .error || message.isError
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(ErrorMessage(message: message, showRawMessage: showRawMessage))
    }
}

/// 默认 Markdown 渲染器（兜底）
private struct DefaultMarkdownRenderer: SuperMessageRenderer {
    static let id = "default-markdown"
    static let priority = 0  // 最低优先级，兜底渲染
    
    func canRender(message: ChatMessage) -> Bool {
        // 总是返回 true，作为兜底渲染器
        true
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(
            MarkdownView(message: message, showRawMessage: showRawMessage.wrappedValue)
                .messageBubbleStyle(role: message.role, isError: message.isError)
        )
    }
}

// MARK: - Preview

#Preview("Plugin Info") {
    VStack(spacing: 20) {
        Image(systemName: "paintbrush.fill")
            .font(.system(size: 60))
            .foregroundColor(.blue)
        
        Text("核心消息渲染插件")
            .font(.headline)
        
        Text("提供内置消息类型的渲染支持")
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        Divider()
        
        Text("注册的渲染器：")
            .font(.caption)
        
        VStack(alignment: .leading, spacing: 4) {
            Text("• TurnCompletedRenderer (200)")
            Text("• LoadingLocalModelRenderer (190)")
            Text("• ToolOutputRenderer (180)")
            Text("• ErrorMessageRenderer (160)")
            Text("• UserMessageRenderer (150)")
            Text("• AssistantMessageRenderer (150)")
            Text("• SystemMessageRenderer (150)")
            Text("• StatusMessageRenderer (150)")
            Text("• DefaultMarkdownRenderer (0)")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding()
}