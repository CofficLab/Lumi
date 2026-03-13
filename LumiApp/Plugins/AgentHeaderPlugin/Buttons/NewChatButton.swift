import OSLog
import MagicKit
import SwiftData
import SwiftUI

/// 新会话按钮视图组件
/// 点击时创建新会话，自治组件，直接使用环境变量完成所有操作
struct NewChatButton: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🆕"
    /// 是否启用详细日志
    nonisolated static let verbose = false

    /// 环境对象：Agent 提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 环境对象：项目 ViewModel
    @EnvironmentObject var projectViewModel: ProjectViewModel

    /// 环境对象：SwiftData 模型上下文
    @Environment(\.modelContext) private var modelContext

    /// 图标尺寸常量
    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button(action: {
            Task {
                await createNewConversation()
            }
        }) {
            Image(systemName: "plus.circle")
                .font(.system(size: iconSize))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("开启新会话")
    }
}

// MARK: - View

extension NewChatButton {
    /// 构建系统上下文消息
    /// - Parameters:
    ///   - projectName: 项目名称
    ///   - projectPath: 项目路径
    /// - Returns: 系统消息内容
    private func buildSystemContextMessage(projectName: String?, projectPath: String?) async -> String {
        await agentProvider.promptService.getSystemContextMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: projectViewModel.languagePreference
        )
    }

    /// 构建欢迎消息
    /// - Parameters:
    ///   - projectName: 项目名称
    ///   - projectPath: 项目路径
    /// - Returns: 欢迎消息内容
    private func buildWelcomeMessage(projectName: String?, projectPath: String?) async -> String {
        await agentProvider.promptService.getEmptySessionWelcomeMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: projectViewModel.languagePreference
        )
    }

    /// 保存消息到会话
    /// - Parameters:
    ///   - message: 要保存的消息
    ///   - conversation: 目标会话
    /// - Returns: 保存后的消息对象
    private func saveMessage(_ message: ChatMessage, to conversation: Conversation) -> ChatMessage? {
        let messageEntity = ChatMessageEntity.fromChatMessage(message)
        messageEntity.conversation = conversation
        conversation.messages.append(messageEntity)
        conversation.updatedAt = Date()

        do {
            try modelContext.save()
            return messageEntity.toChatMessage()
        } catch {
            os_log(.error, "\(Self.t)❌ 保存消息失败：\(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Action

extension NewChatButton {
    /// 创建新会话
    /// 1. 创建会话记录
    /// 2. 切换消息发送队列
    /// 3. 准备系统上下文和欢迎消息
    /// 4. 选中新会话
    @MainActor
    private func createNewConversation() async {
        let projectId = agentProvider.isProjectSelected ? agentProvider.currentProjectPath : nil
        let projectName = agentProvider.isProjectSelected ? agentProvider.currentProjectName : nil
        let projectPath = agentProvider.isProjectSelected ? agentProvider.currentProjectPath : nil

        if Self.verbose {
            os_log("\(Self.t)🚀 开始创建新会话")
        }

        // 1. 创建会话记录
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"

        let newConversation = Conversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date()),
            createdAt: Date(),
            updatedAt: Date()
        )

        modelContext.insert(newConversation)
        try? modelContext.save()

        // 2. 切换消息发送队列到新会话
        agentProvider.messageSenderViewModel.switchToConversation(newConversation.id)

        // 3. 准备系统上下文消息和欢迎消息
        var initialMessages: [ChatMessage] = []

        // 3.1 添加系统上下文消息（设置项目上下文）
        let systemMessage = await buildSystemContextMessage(
            projectName: projectName,
            projectPath: projectPath
        )
        if !systemMessage.isEmpty {
            let sysMsg = ChatMessage(role: .system, content: systemMessage)
            if let savedSystemMsg = saveMessage(sysMsg, to: newConversation) {
                initialMessages.append(savedSystemMsg)
            }
        }

        // 3.2 添加欢迎消息
        let welcomeMessage = await buildWelcomeMessage(
            projectName: projectName,
            projectPath: projectPath
        )

        if !welcomeMessage.isEmpty {
            let welcomeMsg = ChatMessage(role: .assistant, content: welcomeMessage)
            if let savedMessage = saveMessage(welcomeMsg, to: newConversation) {
                initialMessages.append(savedMessage)
            }
        }

        // 4. 选中该会话（这会触发 UI 更新，但消息已经准备好了）
        agentProvider.conversationViewModel.setSelectedConversation(newConversation.id)

        if Self.verbose {
            os_log("\(Self.t)✅ [\(newConversation.id)] 新会话创建完成，初始消息：\(initialMessages.count) 条")
        }
    }
}

// MARK: - Preview

#Preview("New Chat Button - Small") {
    NewChatButton()
        .padding()
        .background(Color.black)
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("New Chat Button - Large") {
    NewChatButton()
        .padding()
        .background(Color.black)
        .inRootView()
        .frame(width: 1200, height: 1200)
}
