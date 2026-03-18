import SwiftData
import SwiftUI

/// 窗口级视图容器
/// 为每个窗口提供独立的 ViewModel 实例，实现多窗口状态隔离
///
/// 每个窗口创建时都会实例化一个 `WindowViewContainer`，包含：
/// - 独立的 `AgentVM` - 管理对话状态和消息处理
/// - 独立的 `MessageViewModel` - 管理消息列表
/// - 独立的 `ConversationVM` - 管理会话列表
/// - 独立的 `ChatHistoryService` - 管理当前窗口的数据库上下文
///
/// 共享的服务（如 LLMService、ModelContainer）通过 `RootViewContainer.Services` 传入
@MainActor
final class WindowViewContainer: ObservableObject {
    let chatHistoryService: ChatHistoryService

    let messageViewModel: MessagePendingVM
    let ConversationVM: ConversationVM
    let MessageSenderVM: MessageSenderVM
    let agentProvider: AgentVM
    let commandSuggestionViewModel: CommandSuggestionVM
    let chatTimelineViewModel: ChatTimelineViewModel

    let depthWarningViewModel: DepthWarningVM
    let processingStateViewModel: ProcessingStateVM
    let errorStateViewModel: ErrorStateVM
    let permissionRequestViewModel: PermissionRequestVM
    let thinkingStateViewModel: ThinkingStateVM
    let titleGenerationViewModel: TitleGenerationVM

    init(services: RootViewContainer.Services) {
        self.chatHistoryService = ChatHistoryService(
            llmService: services.llmService,
            modelContainer: services.modelContainer,
            reason: "WindowViewContainer"
        )

        self.depthWarningViewModel = DepthWarningVM()
        self.processingStateViewModel = ProcessingStateVM()
        self.errorStateViewModel = ErrorStateVM()
        self.permissionRequestViewModel = PermissionRequestVM()
        self.thinkingStateViewModel = ThinkingStateVM()
        self.titleGenerationViewModel = TitleGenerationVM()

        self.messageViewModel = MessagePendingVM(chatHistoryService: chatHistoryService)

        self.ConversationVM = Lumi.ConversationVM(
            chatHistoryService: chatHistoryService,
            llmService: services.llmService,
            promptService: services.promptService
        )

        self.MessageSenderVM = Lumi.MessageSenderVM()

        self.commandSuggestionViewModel = CommandSuggestionVM(slashCommandService: services.slashCommandService)

        let toolExecutionService = ToolExecutionService(toolService: services.toolService)

        let conversationTurnViewModel = ConversationTurnVM(
            llmService: services.llmService,
            toolExecutionService: toolExecutionService,
            promptService: services.promptService
        )

        self.agentProvider = AgentVM(
            promptService: services.promptService,
            registry: services.providerRegistry,
            toolService: services.toolService,
            chatHistoryService: chatHistoryService,
            messageViewModel: messageViewModel,
            ConversationVM: ConversationVM,
            MessageSenderVM: MessageSenderVM,
            ProjectVM: services.ProjectVM,
            conversationTurnViewModel: conversationTurnViewModel,
            slashCommandService: services.slashCommandService,
            depthWarningViewModel: depthWarningViewModel,
            processingStateViewModel: processingStateViewModel,
            errorStateViewModel: errorStateViewModel,
            permissionRequestViewModel: permissionRequestViewModel,
            thinkingStateViewModel: thinkingStateViewModel,
            titleGenerationViewModel: titleGenerationViewModel
        )

        self.chatTimelineViewModel = ChatTimelineViewModel(
            agentProvider: agentProvider,
            conversationVM: ConversationVM
        )
    }
}
