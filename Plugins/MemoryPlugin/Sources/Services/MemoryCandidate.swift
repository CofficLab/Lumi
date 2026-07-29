import Foundation

/// 一个准备写入持久化记忆的高置信度候选。
public struct MemoryCandidate: Sendable, Equatable {
    public let id: String
    public let type: MemoryType
    public let name: String
    public let description: String
    public let content: String
    public let scope: MemoryScope

    public init(
        id: String,
        type: MemoryType,
        name: String,
        description: String,
        content: String,
        scope: MemoryScope
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.content = content
        self.scope = scope
    }
}
