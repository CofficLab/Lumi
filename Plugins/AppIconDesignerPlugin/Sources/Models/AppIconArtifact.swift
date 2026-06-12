import Foundation

public struct AppIconArtifact: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let sourcePath: String
    public let createdAt: Date
    public let prompt: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        sourcePath: String,
        createdAt: Date = Date(),
        prompt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourcePath = sourcePath
        self.createdAt = createdAt
        self.prompt = prompt
    }
}
