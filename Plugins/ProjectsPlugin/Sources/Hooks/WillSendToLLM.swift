import Foundation
import LumiKernel

/// Projects 插件 willSendToLLM 钩子
///
/// 在 AgentTurnRunner 构造 LumiLLMRequest 之前被调用,把当前项目路径
/// 作为 system 消息插入到 messages 首位。AgentTurnRunner 会把所有插件
/// 注入的 system 消息合并为单条以最大化 LLM provider 缓存命中率。
@MainActor
public struct ProjectsWillSendToLLMHook {
    public let pluginID: String

    public init(pluginID: String) {
        self.pluginID = pluginID
    }

    /// 执行 willSendToLLM 钩子
    public func execute(
        kernel: LumiKernel,
        messages: [LumiChatMessage]
    ) async -> [LumiChatMessage] {
        guard let projectPath = kernel.project?.currentProject?.path,
              !projectPath.isEmpty else {
            return messages
        }

        let hint = "Current project path: \(projectPath)"
        let systemMessage = LumiChatMessage(
            conversationID: UUID(),
            role: .system,
            content: hint
        )
        return [systemMessage] + messages
    }
}