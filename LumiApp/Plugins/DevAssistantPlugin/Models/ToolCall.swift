import Foundation

struct ToolCall: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let arguments: String
}
