import Foundation
import AgentToolKit

/// 工具构建上下文
///
/// 在插件工具工厂构建工具时提供的依赖上下文，承载工具所需的全部服务引用。
/// LumiCoreKit 中定义最小化版本，内核在运行时注入完整实现。
@MainActor
public struct ToolContext: AgentToolKit.ToolContextProviding {
    public let languagePreference: LanguagePreference
    public let llmService: LLMService?
    public let toolService: ToolService
    public let llmVM: AppLLMVM?
    public let conversationVM: WindowConversationVM?
    public let recentProjectsVM: AppProjectsVM?

    public init(
        languagePreference: LanguagePreference = .english,
        llmService: LLMService? = nil,
        toolService: ToolService = ToolService(),
        llmVM: AppLLMVM? = nil,
        conversationVM: WindowConversationVM? = nil,
        recentProjectsVM: AppProjectsVM? = nil
    ) {
        self.languagePreference = languagePreference
        self.llmService = llmService
        self.toolService = toolService
        self.llmVM = llmVM
        self.conversationVM = conversationVM
        self.recentProjectsVM = recentProjectsVM
    }
}
