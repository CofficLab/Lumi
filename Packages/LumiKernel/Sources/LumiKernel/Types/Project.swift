import Foundation

/// 项目信息
public struct ProjectInfo: Sendable, Codable {
    public let name: String
    public let path: String
    public let language: String?

    public init(name: String, path: String, language: String? = nil) {
        self.name = name
        self.path = path
        self.language = language
    }
}
