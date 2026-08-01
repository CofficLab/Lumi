import Foundation

public enum LumiLLMProviderAPIKeyMessage {
    public static let renderKind = "llm-provider-api-key-missing"
    public static let accessFailedRenderKind = "llm-provider-api-key-access-failed"
    public static let rawErrorPrefix = "Missing API key for:"

    public static func isMissingAPIKeyMessage(_ message: LumiChatMessage) -> Bool {
        guard message.role == .error || message.isError else { return false }
        if message.renderKind == renderKind {
            return true
        }
        if message.renderKind?.hasSuffix("api-key-missing") == true {
            return true
        }
        return message.rawErrorDetail?.hasPrefix(rawErrorPrefix) == true
    }

    public static func isAPIKeyAccessFailedMessage(_ message: LumiChatMessage) -> Bool {
        guard message.role == .error || message.isError else { return false }
        return message.renderKind == accessFailedRenderKind
    }
}
