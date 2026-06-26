import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport

/// 小米供应商共享的错误处理逻辑。
///
/// TokenPlan（`xiaomi`）与小米 API（`xiaomi-api`）都把请求异常转换成带 `renderKind`
/// 的错误 `LumiChatMessage`，由 `messageRenderers` 据此渲染配置界面或错误详情。
/// 两者逻辑完全一致，仅 providerID 不同，故抽到这里复用。
enum XiaomiErrorHandling {
    /// 将请求异常转换为可被错误渲染器识别的 `LumiChatMessage`。
    static func errorMessage(
        providerID: String,
        conversationID: UUID,
        error: Error
    ) -> LumiChatMessage {
        let fullDetail = LumiLLMProviderSupportLocalization.userFacingDescription(for: error)
        let split = LumiLLMTransportDetails.split(fullDetail)
        return LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: providerID,
            isError: true,
            rawErrorDetail: split.summary,
            renderKind: renderKind(for: error),
            metadata: LumiLLMTransportDetails.metadata(from: split)
        )
    }

    /// 把异常映射为 `XiaomiRenderKind` 中的某个渲染类型。
    private static func renderKind(for error: Error) -> String {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return XiaomiRenderKind.apiKeyMissing
        }

        if case let HTTPClientError.httpError(statusCode, _) = error {
            return XiaomiRenderKind.http(statusCode)
        }

        // 流式失败的消息体里可能携带 HTTP 状态码（如 "HTTP 错误 (401)"），尝试解析。
        if case let LumiLLMProviderSupportError.streamingFailed(message) = error,
           let statusCode = parseHTTPStatusCode(from: message) {
            return XiaomiRenderKind.http(statusCode)
        }

        return XiaomiRenderKind.requestFailed
    }

    /// 从错误消息文本中提取 HTTP 状态码。
    ///
    /// 流式请求失败时，状态码通常被拼进消息体（而非以 `HTTPClientError` 抛出），
    /// 需用一组正则兜底解析，确保 401/403 等能命中对应渲染器。
    private static func parseHTTPStatusCode(from text: String) -> Int? {
        let patterns = [
            #"HTTP 错误 \((\d+)\)"#,
            #"HTTP 错误（(\d+)）"#,
            #"HTTP error \((\d+)\)"#,
            #"HTTP (\d+)"#,
            #"\b(\d{3})\b"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text),
                  let code = Int(text[range]),
                  (100 ... 599).contains(code)
            else {
                continue
            }
            return code
        }

        return nil
    }
}
