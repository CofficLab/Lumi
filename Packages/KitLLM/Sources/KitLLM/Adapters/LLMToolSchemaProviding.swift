import Foundation

public protocol LLMToolSchemaProviding: Sendable {
    var name: String { get }
    var toolDescription: String { get }
    var inputSchema: [String: Any] { get }
}
