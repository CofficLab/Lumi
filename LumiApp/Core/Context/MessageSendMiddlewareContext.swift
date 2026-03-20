import Foundation
import MagicKit

@MainActor
final class MessageSendMiddlewareContext {
    let runtimeStore: ConversationRuntimeStore
    let services: MessageSendMiddlewareServices
    let traceId: UUID
    let startedAt: Date

    init(
        runtimeStore: ConversationRuntimeStore,
        services: MessageSendMiddlewareServices,
        traceId: UUID = UUID(),
        startedAt: Date = Date()
    ) {
        self.runtimeStore = runtimeStore
        self.services = services
        self.traceId = traceId
        self.startedAt = startedAt
    }
}

/// `MessageSendEvent` 中间件上下文的依赖集合（通过闭包注入，避免插件直接依赖核心对象）。
@MainActor
struct MessageSendMiddlewareServices {
    // MARK: - Slash Command

    /// 判断输入是否为 Slash 命令。
    let isSlashCommand: (String) async -> Bool

    /// 执行 Slash 命令并返回结果；由调用方决定如何消费结果。
    let handleSlashCommand: (String) async -> SlashCommandResult

    // MARK: - Core Send

    /// 获取当前选中的会话 ID（用于判断投影是否仍需执行）。
    let getSelectedConversationId: () -> UUID?

    /// 向当前会话的 UI 列表追加消息（投影层）。
    let appendMessage: (ChatMessage) -> Void

    /// 落库保存消息到指定会话。
    let saveMessage: (ChatMessage, UUID) async -> Void

    /// 触发轮次处理（深度从 0 开始）。
    let enqueueTurnProcessing: (UUID, Int) -> Void

    /// 获取对话标题（用于判断是否仍是默认标题）。
    let getConversationTitle: (UUID) -> String?
    /// 获取当前用于生成标题的 LLM 配置。
    let getCurrentConfig: () -> LLMConfig
    /// 仅生成标题文本，不做触发判定与持久化更新。
    let generateConversationTitle: @Sendable (String, LLMConfig) async -> String
    /// 仅当当前标题仍等于 expectedTitle 时更新为 newTitle，返回是否更新成功。
    let updateConversationTitleIfUnchanged: @Sendable (UUID, String, String) async -> Bool

    /// 当前是否已选择项目。
    let isProjectSelected: () -> Bool
    /// 获取当前项目名称与路径。
    let getProjectInfo: () -> (name: String, path: String)

    /// 当前是否已选择文件（文件预览/树选中）。
    let isFileSelected: () -> Bool
    /// 获取当前选中文件路径与内容（若有）。
    let getSelectedFileInfo: () -> (path: String, content: String)

    /// 获取系统级"当前选中文本"（若启用文本选择能力）。
    let getSelectedText: () -> String?

    /// 获取指定对话的消息数量。
    let getMessageCount: (UUID) -> Int
}
