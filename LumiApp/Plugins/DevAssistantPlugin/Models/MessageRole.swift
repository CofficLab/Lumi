import Foundation

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}
