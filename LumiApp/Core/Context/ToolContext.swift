import Foundation
import AgentToolKit

/// 工具构建上下文
///
/// 在插件工具工厂构建工具时提供的依赖上下文，承载工具所需的全部服务引用。
/// 在主线程构建，避免并发隔离问题。
///
/// 实现 AgentToolKit 包的 `ToolContextProviding` 协议。
@MainActor
struct ToolContext: ToolContextProviding {
    let toolService: ToolService
    let llmService: LLMService?
    let llmVM: AppLLMVM?
    let conversationVM: WindowConversationVM?
    let recentProjectsVM: AppProjectsVM?

    var languagePreference: LanguagePreference {
        toolService.languagePreference
    }
}
