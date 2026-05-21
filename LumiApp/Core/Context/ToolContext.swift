import Foundation

/// 工具构建上下文
///
/// 在插件工具工厂构建工具时提供的依赖上下文，承载工具所需的全部服务引用。
/// 在主线程构建，避免并发隔离问题。
@MainActor
struct ToolContext {
    let toolService: ToolService
    let llmService: LLMService?
    let llmVM: AppLLMVM?
    let conversationVM: WindowConversationVM?
}

