import Foundation
import LLMKit
import LLMKit

public enum CodeReviewRuntime {
    public typealias MessageSender = @Sendable ([ChatMessage], LLMConfig) async throws -> ChatMessage

    nonisolated(unsafe) public static var currentConfigProvider: () -> LLMConfig? = { nil }
    nonisolated(unsafe) public static var sendMessage: MessageSender?
}
