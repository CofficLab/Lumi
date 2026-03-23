import Foundation

/// 项目
public struct Project: Codable, Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let path: String
    public let lastUsed: Date

    public enum CodingKeys: String, CodingKey {
        case name, path, lastUsed
    }

    public init(name: String, path: String, lastUsed: Date = Date()) {
        self.name = name
        self.path = path
        self.lastUsed = lastUsed
    }
}
