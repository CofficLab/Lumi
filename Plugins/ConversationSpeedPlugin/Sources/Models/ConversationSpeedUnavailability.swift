import Foundation
import KernelLumi

/// 流式速度不可用时的原因分类。
enum ConversationSpeedUnavailability: String, Equatable {
    case waitingForResponse
    case missingOutputTokens
    case missingDuration
    case missingOutputTokensAndDuration

    static func reason(for message: LumiChatMessage?) -> ConversationSpeedUnavailability {
        guard let message else { return .waitingForResponse }

        let outputTokens = message.outputTokenCount
            ?? Int(message.metadata["outputTokens"] ?? "")
        let duration = message.conversationSpeedDurationMs.flatMap { $0 > 0 ? $0 : nil }

        switch (outputTokens, duration) {
        case (nil, nil):
            return .missingOutputTokensAndDuration
        case (nil, _):
            return .missingOutputTokens
        case (_, nil):
            return .missingDuration
        case (.some(_), .some(_)):
            return .waitingForResponse
        }
    }

    var localizedExplanation: String {
        let key: String
        switch self {
        case .waitingForResponse:
            key = "Speed unavailable waiting for response"
        case .missingOutputTokens:
            key = "Speed unavailable missing output tokens"
        case .missingDuration:
            key = "Speed unavailable missing duration"
        case .missingOutputTokensAndDuration:
            key = "Speed unavailable missing output tokens and duration"
        }
        return LumiPluginLocalization.string(key, bundle: .module)
    }
}
