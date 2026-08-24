import Foundation

struct ToolApprovalPayload: Codable, Equatable, Sendable {
    let toolCallId: String
    let question: String
    let options: [String]
    let mode: String
    let conversationId: String
    let verbosity: String

    static func parse(from content: String?) -> Self? {
        guard let content, let data = content.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    var isToolApproval: Bool {
        toolCallId.hasPrefix("approval:")
    }
}
