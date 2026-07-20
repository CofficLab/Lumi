import Foundation

/// LLM 失败详情解析
@MainActor
public enum LumiLLMFailureDetailResolver {
    public static func resolve(from error: Error, locale: Locale = .current) -> LumiLLMFailureDetail {
        let nsError = error as NSError
        let summary = nsError.localizedDescription
        return LumiLLMFailureDetail(summary: summary, suggestion: nil, code: nsError.code)
    }
}

/// LLM 失败详情
public struct LumiLLMFailureDetail: Sendable {
    public let summary: String
    public let suggestion: String?
    public let code: Int

    public init(summary: String, suggestion: String? = nil, code: Int = 0) {
        self.summary = summary
        self.suggestion = suggestion
        self.code = code
    }
}
