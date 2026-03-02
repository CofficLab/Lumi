import Foundation

struct LLMConfig: Codable, Sendable, Equatable {
    var apiKey: String
    var model: String
    var providerId: String

    static let `default` = LLMConfig(apiKey: "", model: "claude-sonnet-4-20250514", providerId: "anthropic")
}
