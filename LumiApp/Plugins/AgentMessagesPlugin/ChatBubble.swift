import SwiftUI
import Combine

/// 消息展开状态管理器
@MainActor
final class MessageExpansionState: ObservableObject {
    static let shared = MessageExpansionState()
    
    @Published private var expandedStates: [UUID: Bool] = [:]
    
    init() {}
    
    /// 获取消息的展开状态
    func isExpanded(id: UUID) -> Bool {
        expandedStates[id] ?? true  // 默认展开
    }
    
    /// 设置消息的展开状态
    func setExpanded(id: UUID, expanded: Bool) {
        expandedStates[id] = expanded
    }
    
    /// 切换消息的展开状态
    func toggleExpansion(id: UUID) {
        let current = isExpanded(id: id)
        expandedStates[id] = !current
    }
}

/// 聊天气泡组件，用于显示用户消息、助手回复和工具输出
struct ChatBubble: View {
    let message: ChatMessage
    /// 是否是最后一条消息
    let isLastMessage: Bool
    @ObservedObject private var expansionState = MessageExpansionState.shared
    @State private var showRawMessage: Bool = false
    /// 智能体提供者（用于获取思考状态）
    @EnvironmentObject var agentProvider: AgentProvider

    // 判断是否是长消息
    private var isLongMessage: Bool {
        let charCount = message.content.count
        let lineCount = message.content.components(separatedBy: "\n").count
        return charCount > 1000 || lineCount > 50
    }

    // 当前消息的展开状态
    private var isExpanded: Bool {
        expansionState.isExpanded(id: message.id)
    }

    // 是否是当前正在流式传输的消息
    private var isCurrentStreamingMessage: Bool {
        agentProvider.currentStreamingMessageId == message.id
    }

    // 是否应该显示思考过程
    private var shouldShowThinkingProcess: Bool {
        // 必须是助手消息
        guard message.role == .assistant else { return false }
        // 如果有存储的思考内容，显示它
        if let storedThinking = message.thinkingContent, !storedThinking.isEmpty {
            return true
        }
        // 如果是最后一条消息且正在流式传输，显示实时思考
        if isLastMessage {
            return agentProvider.isThinking || !agentProvider.thinkingText.isEmpty
        }
        return false
    }

    // 获取思考过程文本（优先使用存储的，否则使用实时的）
    private var thinkingText: String {
        // 如果有存储的思考内容，使用它
        if let storedThinking = message.thinkingContent, !storedThinking.isEmpty {
            return storedThinking
        }
        // 否则使用实时的思考文本
        return agentProvider.thinkingText
    }

    // 是否正在思考（用于动画）
    private var isThinking: Bool {
        // 如果有存储的思考内容，说明思考已完成
        if message.thinkingContent != nil {
            return false
        }
        // 否则使用实时的思考状态
        return agentProvider.isThinking
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // MARK: - Avatar

            AvatarChatView(role: message.role, isToolOutput: message.toolCallID != nil)

            // MARK: - Content

            VStack(alignment: .leading, spacing: 4) {
                if message.role == .assistant {
                    // 助手消息：显示 Header（包含供应商、模型信息和响应时间）
                    VStack(alignment: .leading, spacing: 4) {
                        AssistantMessageHeader(
                            message: message,
                            showRawMessage: $showRawMessage,
                            isExpanded: isExpanded,
                            onToggleExpand: {
                                Task { @MainActor in
                                    expansionState.toggleExpansion(id: message.id)
                                }
                            },
                            isLongMessage: isLongMessage
                        )

                        // 思考过程展示（对最后一条助手消息显示）
                        if shouldShowThinkingProcess {
                            ThinkingProcessView(
                                thinkingText: thinkingText,
                                isThinking: isThinking
                            )
                        }

                        if hasToolCalls {
                            AssistantMessageWithToolCallsView(message: message)
                        } else {
                            MarkdownMessageView(
                                message: message,
                                showRawMessage: showRawMessage,
                                isCollapsible: isLongMessage,
                                isExpanded: isExpanded,
                                onToggleExpand: {
                                    Task { @MainActor in
                                        expansionState.toggleExpansion(id: message.id)
                                    }
                                }
                            )
                            .messageBubbleStyle(role: message.role, isError: message.isError)
                        }
                    }
                } else if message.toolCallID != nil {
                    // 工具输出
                    RoleLabel.tool
                    ToolOutputView(
                        message: message,
                        toolType: inferToolType(from: message)
                    )
                } else {
                    // 用户消息
                    MarkdownMessageView(
                        message: message,
                        showRawMessage: showRawMessage,
                        isCollapsible: false,
                        isExpanded: true,
                        onToggleExpand: {}
                    )
                    .messageBubbleStyle(role: message.role, isError: message.isError)
                }
            }

            Spacer()
        }
    }

    // MARK: - Helper Properties

    /// 检查消息是否包含工具调用
    private var hasToolCalls: Bool {
        message.toolCalls != nil && !message.toolCalls!.isEmpty
    }

    // MARK: - Infer Tool Type from Tool Call ID

    private func inferToolType(from message: ChatMessage) -> ToolOutputView.ToolType? {
        // 根据 toolCallID 查找对应的工具调用
        // 由于消息之间没有直接关联，我们通过工具名称前缀来推断
        // 这是一个简化实现，更好的方式是在消息间建立关联
        return .unknown
    }
}

// MARK: - Assistant Message Header

/// 助手消息头部组件
struct AssistantMessageHeader: View {
    let message: ChatMessage
    @Binding var showRawMessage: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let isLongMessage: Bool
    /// 智能体提供者（用于获取心跳状态）
    @EnvironmentObject var agentProvider: AgentProvider
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // 供应商和模型信息
            HStack(alignment: .center, spacing: 4) {
                Text("Lumi")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                // 心跳动画指示器（当正在处理时显示）
                if agentProvider.isProcessing {
                    HeartbeatIndicator()
                }

                // 思考状态指示器
                if agentProvider.isThinking {
                    ThinkingIndicator()
                }

                // 供应商名称（如果有）
                if let providerId = message.providerId {
                    Text("·")
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text(formatProviderName(providerId))
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                // 模型名称（如果有）
                if let modelName = message.modelName {
                    Text("·")
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text(formatModelName(modelName))
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }
            
            Spacer()
            
            HStack(alignment: .center, spacing: 12) {
                // 响应时间（如果有）
                if let latency = message.latency {
                    HStack(alignment: .center, spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9, weight: .medium))
                        Text(formatLatency(latency))
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                
                // 折叠/展开按钮（仅当内容是长消息时显示）
                if isLongMessage {
                    if isExpanded {
                        // 已展开，显示折叠按钮
                        CollapseButton(action: onToggleExpand)
                    } else {
                        // 已折叠，显示提示
                        Text("已折叠")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.6))
                    }
                }
                
                // 切换源码/渲染按钮
                RawMessageToggleButton(showRawMessage: $showRawMessage)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    /// 格式化供应商名称（显示友好名称）
    private func formatProviderName(_ providerId: String) -> String {
        let providerNames: [String: String] = [
            "anthropic": "Anthropic",
            "openai": "OpenAI",
            "zhipu": "智谱 AI",
            "deepseek": "深度求索",
            "aliyun": "阿里云",
            "azure": "Azure",
            "google": "Google",
            "mistral": "Mistral",
            "groq": "Groq",
            "ollama": "Ollama"
        ]
        return providerNames[providerId] ?? providerId.capitalized
    }
    
    /// 格式化模型名称（简化显示）
    private func formatModelName(_ name: String) -> String {
        // 移除日期后缀，例如：claude-sonnet-4-20250514 → claude-sonnet-4
        // gpt-4o-2024-11-20 → gpt-4o
        let parts = name.split(separator: "-")
        if parts.count > 2, let lastPart = parts.last, lastPart.allSatisfy({ $0.isNumber }) {
            return parts.dropLast().joined(separator: "-")
        }
        return name
    }
    
    /// 格式化响应时间
    private func formatLatency(_ latency: Double) -> String {
        if latency < 1000 {
            return String(format: "%.0fms", latency)
        } else {
            return String(format: "%.1fs", latency / 1000.0)
        }
    }
}

// MARK: - Heartbeat Indicator

/// 心跳动画指示器
struct HeartbeatIndicator: View {
    @EnvironmentObject var agentProvider: AgentProvider
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
            .scaleEffect(pulseScale)
            .opacity(isAnimating ? 1.0 : 0.4)
            .onAppear {
                startAnimation()
            }
            .onChange(of: agentProvider.lastHeartbeatTime) { _, _ in
                // 收到心跳时触发脉冲动画
                triggerPulse()
            }
            .onChange(of: agentProvider.isProcessing) { _, isProcessing in
                if isProcessing {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
    }

    private func startAnimation() {
        guard agentProvider.isProcessing else { return }

        // 基础呼吸动画
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
    }

    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            isAnimating = false
            pulseScale = 1.0
        }
    }

    private func triggerPulse() {
        // 心跳脉冲效果
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.8
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.3)) {
                pulseScale = 1.0
            }
        }
    }
}

// MARK: - Thinking Indicator

/// 思考状态指示器
struct ThinkingIndicator: View {
    @State private var isAnimating = false
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 10))
                .foregroundColor(.orange)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text("思考中")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(.orange)
        }
    }
}

// MARK: - Thinking Process View

/// 思考过程展示视图（可展开/折叠）
struct ThinkingProcessView: View {
    let thinkingText: String
    let isThinking: Bool
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 展开/折叠按钮
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)

                    Text(isThinking ? "思考过程..." : "思考过程")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(.orange)

                    if isThinking {
                        // 思考中的动画点
                        HStack(spacing: 2) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 4, height: 4)
                                    .opacity(isThinking ? 1.0 : 0.5)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.2),
                                        value: isThinking
                                    )
                            }
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // 思考内容（展开时显示）
            if isExpanded && !thinkingText.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text(thinkingText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.gray)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Collapse Button

/// 折叠按钮（在 Header 中显示）
struct CollapseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                Text("折叠")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.8))
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .help("折叠消息")
    }
}

// MARK: - Role Labels

/// 角色标签
enum RoleLabel {
    /// 助手标签
    static var assistant: some View {
        Text(String(localized: "Dev Assistant", table: "DevAssistant"))
            .font(DesignTokens.Typography.caption1)
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
    }

    /// 工具标签
    static var tool: some View {
        Text(String(localized: "Tool Output", table: "DevAssistant"))
            .font(DesignTokens.Typography.caption1)
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
    }
}

// MARK: - Raw Message Toggle Button

/// 原始消息切换按钮
struct RawMessageToggleButton: View {
    @Binding var showRawMessage: Bool

    var body: some View {
        Button(action: { showRawMessage.toggle() }) {
            Image(systemName: showRawMessage ? "text.bubble.fill" : "curlybraces")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.6))
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.08))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(showRawMessage ? String(localized: "Show Rendered", comment: "Toggle to show rendered markdown") : String(localized: "Show Source", comment: "Toggle to show markdown source"))
    }
}

// MARK: - View Modifiers

extension View {
    /// 应用消息气泡样式
    func messageBubbleStyle(role: MessageRole, isError: Bool) -> some View {
        self
            .font(DesignTokens.Typography.code)
            .padding(10)
            .padding(.trailing, role == .assistant ? 20 : 0)
            .background(bubbleBackgroundColor(role: role, isError: isError))
            .foregroundColor(textColor(isError: isError))
            .cornerRadius(12)
    }

    /// 气泡背景颜色
    func bubbleBackgroundColor(role: MessageRole, isError: Bool) -> Color {
        if isError {
            return DesignTokens.Color.semantic.error.opacity(0.1)
        }
        switch role {
        case .user:
            return DesignTokens.Color.semantic.info.opacity(0.1)
        case .assistant:
            return DesignTokens.Color.semantic.textTertiary.opacity(0.12)
        default:
            return DesignTokens.Color.semantic.textTertiary.opacity(0.1)
        }
    }

    /// 文本颜色
    func textColor(isError: Bool) -> Color {
        if isError {
            return DesignTokens.Color.semantic.error
        }
        return DesignTokens.Color.semantic.textPrimary
    }
}

// MARK: - Preview

#Preview("User Message") {
    ChatBubble(
        message: ChatMessage(role: .user, content: "Hello, how can you help me?"),
        isLastMessage: false
    )
    .padding()
    .background(Color.black)
}

#Preview("Assistant Message with Latency") {
    ChatBubble(
        message: ChatMessage(
            role: .assistant,
            content: "I can help you with coding tasks.",
            providerId: "anthropic",
            modelName: "claude-sonnet-4-20250514",
            latency: 1234.56
        ),
        isLastMessage: true
    )
    .padding()
    .background(Color.black)
}

#Preview("Assistant Message (OpenAI)") {
    ChatBubble(
        message: ChatMessage(
            role: .assistant,
            content: "I can help you with coding tasks.",
            providerId: "openai",
            modelName: "gpt-4o",
            latency: 456.78
        ),
        isLastMessage: true
    )
    .padding()
    .background(Color.black)
}

#Preview("Assistant Message (Long Content)") {
    let longContent = String(repeating: "这是一段测试文字，用于验证长消息的折叠功能。", count: 100)
    ChatBubble(
        message: ChatMessage(
            role: .assistant,
            content: longContent,
            providerId: "anthropic",
            modelName: "claude-sonnet-4-20250514",
            latency: 2345.67
        ),
        isLastMessage: true
    )
    .padding()
    .background(Color.black)
}

#Preview("Tool Output") {
    ChatBubble(
        message: ChatMessage(role: .system, content: "File contents: \nLine 1\nLine 2\nLine 3", toolCallID: "test"),
        isLastMessage: false
    )
    .padding()
    .background(Color.black)
}

#Preview("Error Message") {
    ChatBubble(
        message: ChatMessage(role: .assistant, content: "An error occurred", isError: true),
        isLastMessage: true
    )
    .padding()
    .background(Color.black)
}
