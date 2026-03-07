import Foundation
import SwiftData
import MagicKit
import SwiftUI
import OSLog

/// 会话管理 ViewModel
///
/// 负责处理所有会话相关的业务逻辑：
/// - 创建、加载、删除会话
/// - 会话选择和状态管理
///
/// ## 设计说明
///
/// 此类只维护 `selectedConversationId`，不持有 `Conversation` 对象引用。
/// 需要会话数据的视图应使用 `@Query` 根据 ID 自行查询。
///
/// ## 架构模式
///
/// ```
/// ConversationViewModel
/// ├── ChatHistoryService
/// │   └── 持久化操作
/// ├── LLMService
/// │   └── 标题生成
/// └── PromptService
///     └── 欢迎消息
/// ```
@MainActor
final class ConversationViewModel: ObservableObject, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "💬"
    
    /// 是否启用详细日志
    nonisolated static let verbose = false

    // MARK: - 服务依赖

    /// 聊天历史服务
    ///
    /// 负责会话和消息的持久化操作。
    private let chatHistoryService: ChatHistoryService

    /// LLM 服务（用于生成会话标题）
    ///
    /// 当用户发送第一条消息时，使用 AI 生成会话标题。
    private let llmService: LLMService

    /// 提示词服务（用于获取欢迎消息）
    ///
    /// 获取新会话的欢迎消息内容。
    private let promptService: PromptService

    /// 消息发送队列 ViewModel
    ///
    /// 用于会话切换时同步待发送消息队列。
    /// 使用 weak 避免循环引用。
    weak var messageSenderViewModel: MessageSenderViewModel?

    // MARK: - 会话状态

    /// 选中的会话 ID
    ///
    /// 此类只维护此 ID，不持有 Conversation 对象引用。
    /// 需要会话数据的视图应使用 @Query 根据 ID 自行查询：
    ///
    /// ```swift
    /// @Query(filter: #Predicate<Conversation> { $0.id == viewModel.selectedConversationId })
    /// var selectedConversation: [Conversation]
    /// ```
    ///
    /// ID 变化时会自动持久化到 UserDefaults。
    @Published public fileprivate(set) var selectedConversationId: UUID? {
        didSet {
            if let id = selectedConversationId {
                UserDefaults.standard.set(id.uuidString, forKey: "Conversation_SelectedId")
            } else {
                UserDefaults.standard.removeObject(forKey: "Conversation_SelectedId")
            }
        }
    }

    // MARK: - 初始化

    /// 使用依赖服务初始化
    ///
    /// - Parameters:
    ///   - chatHistoryService: 聊天历史服务
    ///   - llmService: LLM 服务
    ///   - promptService: 提示词服务
    ///   - messageSenderViewModel: 消息发送队列视图模型（可选）
    init(
        chatHistoryService: ChatHistoryService,
        llmService: LLMService,
        promptService: PromptService,
        messageSenderViewModel: MessageSenderViewModel? = nil
    ) {
        self.chatHistoryService = chatHistoryService
        self.llmService = llmService
        self.promptService = promptService
        self.messageSenderViewModel = messageSenderViewModel
    }

    // MARK: - 会话管理

    /// 创建新对话
    ///
    /// 在数据库中创建新的会话记录。
    /// 标题格式："新会话 MM-dd HH:mm"
    ///
    /// - Parameters:
    ///   - projectId: 关联的项目 ID（可选，nil 表示全局对话）
    ///   - title: 对话标题（默认为"新会话"）
    /// - Returns: 新创建的对话
    func createConversation(projectId: String? = nil, title: String = "新会话") -> Conversation {
        if Self.verbose {
            os_log("\(Self.t)🚀 开始创建新会话")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let newConversation = chatHistoryService.createConversation(
            projectId: projectId,
            title: title + " " + formatter.string(from: Date())
        )

        // 切换到新会话的队列
        messageSenderViewModel?.switchToConversation(newConversation.id)

        if Self.verbose {
            os_log("\(Self.t)✅ [\(newConversation.id)] 新会话创建完成")
        }

        return newConversation
    }

    /// 创建新对话（异步版本，支持设置当前会话）
    ///
    /// 完整的新会话创建流程：
    /// 1. 创建会话记录
    /// 2. 选中该会话
    /// 3. 切换消息队列
    /// 4. 获取并保存欢迎消息
    ///
    /// - Parameters:
    ///   - projectId: 关联的项目 ID（可选）
    ///   - projectName: 项目名称（可选，用于生成欢迎消息）
    ///   - projectPath: 项目路径（可选，用于生成欢迎消息）
    ///   - language: 语言偏好（默认为中文）
    func createNewConversation(
        projectId: String? = nil,
        projectName: String? = nil,
        projectPath: String? = nil,
        language: LanguagePreference = .chinese
    ) async {
        // 1. 创建会话
        let newConversation = createConversation(projectId: projectId)
        
        // 2. 选中该会话
        selectedConversationId = newConversation.id

        // 3. 切换消息发送队列到新会话
        messageSenderViewModel?.switchToConversation(newConversation.id)

        // 4. 获取欢迎消息并保存到数据库
        let welcomeMessage = await promptService.getEmptySessionWelcomeMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: language,
            conversationId: newConversation.id
        )

        if !welcomeMessage.isEmpty {
            let welcomeMsg = ChatMessage(role: .assistant, content: welcomeMessage)
            chatHistoryService.saveMessage(welcomeMsg, to: newConversation)
        }
    }

    /// 保存消息到当前对话
    ///
    /// - Parameter message: 要保存的消息
    func saveMessage(_ message: ChatMessage) {
        guard let conversationId = selectedConversationId else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 当前没有选中会话，跳过保存")
            }
            return
        }

        // 从数据库获取对话
        guard let conversation = chatHistoryService.fetchConversation(id: conversationId) else {
            os_log(.error, "\(Self.t)❌ [\(conversationId)] 对话不存在")
            return
        }

        chatHistoryService.saveMessage(message, to: conversation)

        if Self.verbose {
            os_log("\(Self.t)💾 [\(conversation.id)] 消息已保存：\(message.content.max(50))")
        }
    }

    /// 删除指定对话
    ///
    /// 删除流程：
    /// 1. 如果是选中的对话，清理状态
    /// 2. 清理待发送队列
    /// 3. 从数据库删除
    ///
    /// - Parameter conversation: 要删除的对话
    func deleteConversation(_ conversation: Conversation) {
        os_log("\(Self.t)🗑️ 开始删除对话：\(conversation.title)")

        // 如果删除的是选中的对话，清理状态
        if selectedConversationId == conversation.id {
            selectedConversationId = nil
            // 清理该会话的待发送队列
            messageSenderViewModel?.clearCurrentConversationQueue()
        }

        // 清理该会话的待发送队列（即使不是当前对话）
        messageSenderViewModel?.removeConversationQueue(conversation.id)

        chatHistoryService.deleteConversation(conversation)

        os_log("\(Self.t)✅ 对话已删除：\(conversation.title)")
    }

    /// 更新对话标题
    ///
    /// - Parameters:
    ///   - conversation: 要更新的对话
    ///   - newTitle: 新标题
    func updateConversationTitle(_ conversation: Conversation, newTitle: String) {
        chatHistoryService.updateConversationTitle(conversation, newTitle: newTitle)

        if Self.verbose {
            os_log("\(Self.t)✏️ 对话标题已更新：\(newTitle)")
        }
    }

    /// 基于第一条消息生成会话标题
    ///
    /// 使用 LLM 根据用户的第一条消息自动生成会话标题。
    ///
    /// - Parameters:
    ///   - userMessage: 用户的第一条消息
    ///   - config: LLM 配置
    /// - Returns: 生成的标题
    func generateConversationTitle(from userMessage: String, config: LLMConfig) async -> String {
        await chatHistoryService.generateConversationTitle(from: userMessage, config: config)
    }

    // MARK: - 会话选择

    /// 选择指定会话
    /// - Parameter id: 会话 ID
    func selectConversation(_ id: UUID) {
        // 避免重复设置相同的 ID
        guard selectedConversationId != id else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 会话已选中，跳过重复设置: \(id)")
            }
            return
        }

        selectedConversationId = id
    }

    /// 清除会话选择
    ///
    /// 清理选中状态。
    func clearConversationSelection() {
        selectedConversationId = nil
    }

    /// 恢复上次选择的会话
    ///
    /// 应用启动时恢复上次选中的会话。
    /// 会验证会话是否存在，如果不存在则清除保存的状态。
    ///
    /// - Parameter modelContext: 数据上下文（用于验证会话是否存在）
    func restoreSelectedConversation(modelContext: ModelContext?) {
        guard let savedId = UserDefaults.standard.string(forKey: "Conversation_SelectedId"),
              let uuid = UUID(uuidString: savedId) else {
            return
        }

        // 如果有 modelContext，验证会话是否存在
        if let context = modelContext {
            let descriptor = FetchDescriptor<Conversation>(
                predicate: #Predicate { $0.id == uuid }
            )

            do {
                let conversations = try context.fetch(descriptor)
                if conversations.isEmpty {
                    // 会话已不存在，清除保存的 ID
                    if Self.verbose {
                        os_log("\(Self.t)⚠️ 上次选择的会话已不存在，清除保存状态")
                    }
                    UserDefaults.standard.removeObject(forKey: "Conversation_SelectedId")
                    return
                }
                // 会话存在，恢复选择
                selectedConversationId = uuid
                if Self.verbose {
                    os_log("\(Self.t)✅ [\(uuid)] 已恢复会话")
                }
            } catch {
                os_log(.error, "\(Self.t)❌ 验证会话失败：\(error.localizedDescription)")
            }
        } else {
            // 没有 modelContext，直接恢复（可能在初始化阶段）
            selectedConversationId = uuid
            if Self.verbose {
                os_log("\(Self.t)ℹ️ 已恢复会话选择（未验证）: \(uuid)")
            }
        }
    }

    // MARK: - 获取会话列表

    /// 获取所有对话
    ///
    /// - Returns: 按时间倒序排列的会话列表
    func fetchAllConversations() -> [Conversation] {
        chatHistoryService.fetchAllConversations()
    }

    /// 获取项目相关的对话
    ///
    /// - Parameter projectId: 项目路径
    /// - Returns: 项目相关的对话列表
    func fetchConversations(forProject projectId: String) -> [Conversation] {
        chatHistoryService.fetchConversations(forProject: projectId)
    }
}
