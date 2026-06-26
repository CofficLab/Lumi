import Foundation

/// Structured LLM failure information for callers to format per surface.
public struct LumiLLMFailureDetail: Equatable, Sendable {
    public let summary: String
    public let httpStatusCode: Int?
    /// Raw transport diagnostics such as HttpKit URL/response blocks.
    public let transportDetails: String?

    public init(
        summary: String,
        httpStatusCode: Int? = nil,
        transportDetails: String? = nil
    ) {
        self.summary = summary
        self.httpStatusCode = httpStatusCode
        self.transportDetails = transportDetails
    }

    public static func message(_ summary: String) -> LumiLLMFailureDetail {
        LumiLLMFailureDetail(summary: summary)
    }

    /// Primary text for compact availability rows.
    public var availabilityDisplayText: String {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSummary.isEmpty {
            return trimmedSummary
        }
        return transportDetails?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Text for logs and legacy string-based APIs.
    public var logSummary: String {
        availabilityDisplayText
    }
}
