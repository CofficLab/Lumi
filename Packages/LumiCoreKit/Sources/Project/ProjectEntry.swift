import Foundation

/// 内核级项目条目模型，所有插件共享。
public struct ProjectEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String { path }

    public let name: String
    public let path: String
    public let lastUsed: Date

    public init(name: String, path: String, lastUsed: Date = Date()) {
        self.name = name
        self.path = path
        self.lastUsed = lastUsed
    }
}
