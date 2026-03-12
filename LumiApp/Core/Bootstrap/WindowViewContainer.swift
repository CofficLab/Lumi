import SwiftData
import SwiftUI

/// 窗口级视图容器
/// 为每个窗口提供独立的 ViewModel 实例，实现多窗口状态隔离
///
/// 每个窗口创建时都会实例化一个 `WindowViewContainer`，包含：
/// - 独立的 `AgentProvider` - 管理对话状态和消息处理
/// - 独立的 `MessageViewModel` - 管理消息列表
/// - 独立的 `ConversationViewModel` - 管理会话列表
/// - 独立的 `ChatHistoryService` - 管理当前窗口的数据库上下文
///
/// 共享的服务（如 LLMService、ModelContainer）通过 `RootViewContainer.Services` 传入
@MainActor
final class WindowViewContainer: ObservableObject {
    let chatHistoryService: ChatHistoryService

    let messageViewModel: MessagePendingViewModel
    let conversationViewModel: ConversationViewModel
    let messageSenderViewModel: MessageSenderViewModel
    let agentProvider: AgentProvider
    let commandSuggestionViewModel: CommandSuggestionViewModel

    let depthWarningViewModel: DepthWarningViewModel
    let processingStateViewModel: ProcessingStateViewModel
    let errorStateViewModel: ErrorStateViewModel
    let permissionRequestViewModel: PermissionRequestViewModel
    let thinkingStateViewModel: ThinkingStateViewModel
    let titleGenerationViewModel: TitleGenerationViewModel

    init(services: RootViewContainer.Services) {
        self.chatHistoryService = ChatHistoryService(
            llmService: services.llmService,
            modelContainer: services.modelContainer,
            reason: "WindowViewContainer"
        )

        self.depthWarningViewModel = DepthWarningViewModel()
        self.processingStateViewModel = ProcessingStateViewModel()
        self.errorStateViewModel = ErrorStateViewModel()
        self.permissionRequestViewModel = PermissionRequestViewModel()
        self.thinkingStateViewModel = ThinkingStateViewModel()
        self.titleGenerationViewModel = TitleGenerationViewModel()

        self.messageViewModel = MessagePendingViewModel(chatHistoryService: chatHistoryService)

        self.conversationViewModel = ConversationViewModel(
            chatHistoryService: chatHistoryService,
            llmService: services.llmService,
            promptService: services.promptService
        )

        self.messageSenderViewModel = MessageSenderViewModel()

        self.commandSuggestionViewModel = CommandSuggestionViewModel(slashCommandService: services.slashCommandService)

        let toolExecutionService = ToolExecutionService(toolService: services.toolService)

        let conversationTurnViewModel = ConversationTurnViewModel(
            llmService: services.llmService,
            toolExecutionService: toolExecutionService,
            promptService: services.promptService
        )

        self.agentProvider = AgentProvider(
            promptService: services.promptService,
            registry: services.providerRegistry,
            toolService: services.toolService,
            toolsViewModel: services.toolsViewModel,
            chatHistoryService: chatHistoryService,
            messageViewModel: messageViewModel,
            conversationViewModel: conversationViewModel,
            messageSenderViewModel: messageSenderViewModel,
            projectViewModel: services.projectViewModel,
            conversationTurnViewModel: conversationTurnViewModel,
            slashCommandService: services.slashCommandService,
            depthWarningViewModel: depthWarningViewModel,
            processingStateViewModel: processingStateViewModel,
            errorStateViewModel: errorStateViewModel,
            permissionRequestViewModel: permissionRequestViewModel,
            thinkingStateViewModel: thinkingStateViewModel,
            titleGenerationViewModel: titleGenerationViewModel
        )
    }
}
