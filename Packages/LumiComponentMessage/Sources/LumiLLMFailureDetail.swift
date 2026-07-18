import Foundation

/// Semantic category for LLM failures surfaced in availability UI and logs.
public enum LumiLLMFailureReason: Equatable, Sendable {
    /// The provider or plan does not include this model.
    case unsupportedModel
}

/// Structured LLM failure information for callers to format per surface.
public struct LumiLLMFailureDetail: Equatable, Sendable {
    public let summary: String
    public let httpStatusCode: Int?
    /// Raw transport diagnostics such as HttpKit response bodies.
    public let transportDetails: String?
    public let reason: LumiLLMFailureReason?

    public init(
        summary: String,
        httpStatusCode: Int? = nil,
        transportDetails: String? = nil,
        reason: LumiLLMFailureReason? = nil
    ) {
        self.summary = summary
        self.httpStatusCode = httpStatusCode
        self.transportDetails = transportDetails
        self.reason = reason
    }

    public static func message(_ summary: String) -> LumiLLMFailureDetail {
        LumiLLMFailureDetail(summary: summary)
    }

    public static func unsupportedModel(_ summary: String) -> LumiLLMFailureDetail {
        LumiLLMFailureDetail(summary: summary, reason: .unsupportedModel)
    }

    /// Whether raw HTTP diagnostics are available for a details popover.
    public var hasTransportDiagnostics: Bool {
        if httpStatusCode != nil {
            return true
        }
        guard let transportDetails else { return false }
        return !transportDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Raw HTTP status and response body for debugging popovers.
    public var transportDiagnosticsText: String {
        var sections: [String] = []
        if let httpStatusCode {
            sections.append("HTTP Status: \(httpStatusCode)")
        }
        if let body = transportDetails?.trimmingCharacters(in: .whitespacesAndNewlines),
           !body.isEmpty {
            sections.append("Response Body:")
            sections.append(body)
        }
        return sections.joined(separator: "\n")
    }

    /// Replace the user-facing summary while keeping transport diagnostics.
    public func remapped(
        summary: String,
        reason: LumiLLMFailureReason? = nil
    ) -> LumiLLMFailureDetail {
        LumiLLMFailureDetail(
            summary: summary,
            httpStatusCode: httpStatusCode,
            transportDetails: transportDetails,
            reason: reason
        )
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
