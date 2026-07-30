import Foundation
import LumiKernel

// MARK: - Get Conversation Count

struct GetConversationCountLumiTool: LumiAgentTool, @unchecked Sendable {
    static let info = LumiAgentToolInfo(
        id: "get_conversation_count",
        displayName: LumiPluginLocalization.string("Get Conversation Count", bundle: .module),
        description: LumiPluginLocalization.string("Get the total number of conversation histories. Returns the total count of conversations.", bundle: .module)
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        LumiPluginLocalization.string("获取对话总数", bundle: .module)
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let projectPath = kernel.currentProjectPath

        let (totalCount, projectCount, projectName) = await MainActor.run { () -> (Int, Int, String?) in
            guard let svc = kernel.conversations else {
                return (0, 0, nil)
            }
            let all = svc.conversations
            let total = all.count

            if let projectPath {
                let projectConversations = all.filter { $0.projectPath == projectPath }
                let count = projectConversations.count
                let name = URL(fileURLWithPath: projectPath).lastPathComponent
                return (total, count, name)
            } else {
                return (total, 0, nil)
            }
        }

        if let projectName {
            return """
            ## Conversation Count

            **Total Conversations**: \(totalCount)
            **Conversations for Current Project** (\(projectName)): \(projectCount)
            """
        } else {
            return """
            ## Conversation Count

            **Total Conversations**: \(totalCount)

            _No project currently selected._
            """
        }
    }
}