import Foundation

public struct LumiStreamChunk: Sendable, Equatable {
    public let content: String?
    public let isDone: Bool
    public let isThinking: Bool
    public let eventTitle: String
    public let stopReason: String?

    public init(
        content: String? = nil,
        isDone: Bool = false,
        isThinking: Bool = false,
        eventTitle: String = "生成中",
        stopReason: String? = nil
    ) {
        self.content = content
        self.isDone = isDone
        self.isThinking = isThinking
        self.eventTitle = eventTitle
        self.stopReason = stopReason
    }
}
