import Foundation
import LLMKit
import LumiCoreKit

extension ZhipuProvider {
    /// 将 LLM 失败映射为智谱可自定义渲染的错误消息；未识别时返回 nil，由 App 默认处理。
    public func buildErrorChatMessage(
        error: Error,
        conversationId: UUID,
        rawDetail: String?
    ) -> ChatMessage? {
        if let llmError = error as? LLMServiceError {
            return mapLLMServiceError(llmError, conversationId: conversationId, rawDetail: rawDetail)
        }
        return nil
    }

    private func mapLLMServiceError(
        _ error: LLMServiceError,
        conversationId: UUID,
        rawDetail: String?
    ) -> ChatMessage? {
        switch error {
        case .apiKeyEmpty:
            return makeErrorMessage(
                renderKind: ZhipuRenderKind.apiKeyMissing,
                conversationId: conversationId,
                rawDetail: rawDetail
            )

        case .cancelled:
            return nil

        case let .requestFailed(message, statusCode):
            let kind: String
            if let statusCode {
                kind = ZhipuRenderKind.http(statusCode)
            } else {
                kind = ZhipuRenderKind.requestFailed
            }
            return makeErrorMessage(
                renderKind: kind,
                conversationId: conversationId,
                rawDetail: message
            )

        case .modelEmpty, .providerIdEmpty, .temperatureOutOfRange, .maxTokensInvalid,
             .providerNotFound, .invalidBaseURL:
            return nil
        }
    }

    private func makeErrorMessage(
        renderKind: String,
        conversationId: UUID,
        rawDetail: String?
    ) -> ChatMessage {
        ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: "",
            isError: true,
            providerId: Self.id,
            rawErrorDetail: rawDetail,
            renderKind: renderKind
        )
    }
}
