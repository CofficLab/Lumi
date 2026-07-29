import Foundation
import LumiKernel

/// Plugin Manager willSendToLLM hook
///
/// Injects a short delegation policy when sub-agent delegate tools are available.
/// AgentTurnRunner later merges system messages before sending the request.
@MainActor
public struct PluginManagerWillSendToLLMHook {
    private static let subAgentDelegationPolicyMarker = "[Lumi Sub-Agent Delegation Policy]"

    public let pluginID: String

    public init(pluginID: String) {
        self.pluginID = pluginID
    }

    public func execute(
        kernel: LumiKernel,
        messages: [LumiChatMessage]
    ) async -> [LumiChatMessage] {
        guard !messages.contains(where: { message in
            message.role == .system && message.content.contains(Self.subAgentDelegationPolicyMarker)
        }) else {
            return messages
        }

        let subAgents = kernel.toolManager?.allSubAgents() ?? []
        let hasDelegateTaskTool = (kernel.toolManager?.allAgentTools() ?? [])
            .map(\.name)
            .contains("delegate_task")

        guard !subAgents.isEmpty || hasDelegateTaskTool else {
            return messages
        }

        guard let conversationID = messages.last?.conversationID else {
            return messages
        }

        let availableSubAgents = subAgents
            .map { "\($0.routingID) (\($0.displayName))" }
            .sorted()
            .joined(separator: ", ")

        let prompt = """
        \(Self.subAgentDelegationPolicyMarker)

        delegate_task runs isolated sub-agents through Lumi's internal router. Their internal searches, file reads, shell output, and intermediate tool results do not enter the main conversation context. Use delegation to reduce context growth.

        Available sub-agents behind delegate_task: \(availableSubAgents)

        Prefer delegate_task before low-level tools when the task requires project exploration, multi-file reading, code review, debugging, test writing, documentation, commit creation, or build verification.

        Use delegate_task with intent=explore for read-only investigation: finding relevant files, understanding implementation, tracing architecture or workflow, inspecting git state/diff, or when you expect more than two file/search/git read operations.

        Do not manually chain list/read/search/git tools for exploratory investigation unless the user asks about one specific known path, one direct tool call is enough, or no suitable delegate tool exists.

        After a delegate returns, use its findings and summarize them for the user. Do not repeat the same exploration unless the result is insufficient.
        """

        let policyMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: prompt
        )

        var result = messages
        if let lastUserIndex = result.lastIndex(where: { $0.role == .user }) {
            result.insert(policyMessage, at: lastUserIndex + 1)
        } else {
            result.append(policyMessage)
        }
        return result
    }
}
