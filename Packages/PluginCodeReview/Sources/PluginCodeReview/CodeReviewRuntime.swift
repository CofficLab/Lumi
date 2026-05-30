import Foundation
import LLMKit
import LumiCoreKit

public enum CodeReviewRuntime {
    public typealias MessageSender = @Sendable ([ChatMessage], LLMConfig) async throws -> ChatMessage

    nonisolated(unsafe) public static var currentConfigProvider: () -> LLMConfig? = { nil }
    nonisolated(unsafe) public static var sendMessage: MessageSender?
}
