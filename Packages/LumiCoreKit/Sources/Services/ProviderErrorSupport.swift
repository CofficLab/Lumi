import Foundation
import LumiCoreMessage
import LumiCoreLLMProvider

/// LLM Provider 错误消息生成工具
public enum ProviderErrorSupport {

    /// 生成用户友好的错误消息
    public static func makeErrorMessage(
        providerID: String,
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition,
        renderKind: String? = nil
    ) -> LumiChatMessage {
        let errorMessage: String

        if let providerError = error as? LumiLLMProviderSupportError {
            errorMessage = providerError.errorDescription ?? error.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: errorMessage,
            providerID: providerID,
            modelName: request.model,
            isError: true,
            rawErrorDetail: error.localizedDescription,
            renderKind: renderKind
        )
    }
}