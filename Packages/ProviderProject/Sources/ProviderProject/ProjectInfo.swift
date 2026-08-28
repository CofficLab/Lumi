import Foundation

/// 项目信息
///
/// `ProjectProviding` 协议依赖的项目模型，随协议一起放在 ProviderProject 中，
/// 使 ProviderProject 成为 ProjectProviding 相关内容的唯一归属。
public struct ProjectInfo: Sendable, Codable, Equatable {
    public let name: String
    public let path: String
    public let language: String?

    public init(name: String, path: String, language: String? = nil) {
        self.name = name
        self.path = path
        self.language = language
    }
}
