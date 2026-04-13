import Foundation
import MagicKit

/// 会话控制器
///
/// 负责会话级别的用户操作，是 UI 层操作会话的唯一入口。
///
/// ## 当前功能
///
/// | 功能 | 方法 | 说明 |
/// |------|------|------|
/// | 创建会话 | `handleCreationRequest(requestId:)` | 落库、选中、注入 system/welcome 消息 |
///
/// ## 设计原则
///
/// - **Controller 只编排**：不直接操作数据库，而是委托给 `ChatHistoryService` / `ConversationVM` 等服务
/// - **可扩展**：后续会话删除、重命名、复制等操作都可以加在这里
@MainActor
final class ConversationController: ObservableObject, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose: Bool = true

    private let container: RootViewContainer

    init(container: RootViewContainer) {
        self.container = container
    }

    // MARK: - 创建会话

    /// 执行创建会话流程（调用方需已 `consumePendingRequest`）。
    ///
    /// 流程：
    /// 1. 在数据库中创建会话
    /// 2. 选中该会话
    /// 3. 发送 `agentConversationCreated` 通知
    /// 4. 注入 system 上下文消息（项目信息、工具列表等）
    /// 5. 注入 welcome 消息（引导语）
    func handleCreationRequest(requestId: UUID) async {
        let projectId = container.projectVM.isProjectSelected ? container.projectVM.currentProjectPath : nil
        let projectName = container.projectVM.isProjectSelected ? container.projectVM.currentProjectName : nil
        let projectPath = container.projectVM.isProjectSelected ? container.projectVM.currentProjectPath : nil
        let languagePreference = container.projectVM.languagePreference

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"

        let conversation = container.chatHistoryService.createConversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date())
        )

        container.conversationVM.setSelectedConversation(conversation.id)
        NotificationCenter.postAgentConversationCreated(conversationId: conversation.id)
        container.conversationCreationVM.completeRequest(id: requestId)

        let systemMessage = await container.promptService.getSystemContextMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: languagePreference
        )
        if !systemMessage.isEmpty {
            container.conversationVM.saveMessage(
                ChatMessage(role: .system, conversationId: conversation.id, content: systemMessage),
                to: conversation.id
            )
        }

        let welcomeMessage = await container.promptService.getEmptySessionWelcomeMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: languagePreference
        )
        if !welcomeMessage.isEmpty {
            container.conversationVM.saveMessage(
                ChatMessage(role: .assistant, conversationId: conversation.id, content: welcomeMessage),
                to: conversation.id
            )
        }
    }
}
