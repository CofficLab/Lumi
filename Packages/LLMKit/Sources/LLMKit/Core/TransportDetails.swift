import Foundation

public enum LLMTransportMetadata {
    public static let requestDetails = "llm.transport.request"
    public static let responseDetails = "llm.transport.response"
}

public struct LLMTransportDetailsSplit: Equatable, Sendable {
    public let summary: String
    public let requestDetails: String?
    public let responseDetails: String?

    public init(summary: String, requestDetails: String?, responseDetails: String?) {
        self.summary = summary
        self.requestDetails = requestDetails
        self.responseDetails = responseDetails
    }

    public var hasTransportDetails: Bool {
        requestDetails != nil
    }
}

public enum LLMTransportDetails {
    public static let summarySeparator = "\n\n--- Request / Response Details ---\n"
    public static let maxBodyDisplayCharacters = 2_000
    private static let responseSectionMarker = "Response Status:"

    public static func truncatedBodyForDisplay(_ text: String) -> String {
        guard text.count > maxBodyDisplayCharacters else { return text }
        let prefix = String(text.prefix(maxBodyDisplayCharacters))
        return prefix + "\n...[truncated, \(text.count) characters total]"
    }

    public static func split(_ fullDetail: String) -> LLMTransportDetailsSplit {
        guard let separatorRange = fullDetail.range(of: summarySeparator) else {
            return LLMTransportDetailsSplit(
                summary: fullDetail,
                requestDetails: nil,
                responseDetails: nil
            )
        }

        let summary = String(fullDetail[..<separatorRange.lowerBound])
        let detailsBlock = String(fullDetail[separatorRange.upperBound...])
        let (request, response) = splitDetailsBlock(detailsBlock)

        return LLMTransportDetailsSplit(
            summary: summary,
            requestDetails: request,
            responseDetails: response
        )
    }

    public static func metadata(from split: LLMTransportDetailsSplit) -> [String: String] {
        var metadata: [String: String] = [:]
        if let request = split.requestDetails {
            metadata[LLMTransportMetadata.requestDetails] = request
        }
        if let response = split.responseDetails {
            metadata[LLMTransportMetadata.responseDetails] = response
        }
        return metadata
    }

    public static func combinedCopyText(
        summary: String?,
        requestDetails: String?,
        responseDetails: String?
    ) -> String {
        var sections: [String] = []
        if let summary, !summary.isEmpty {
            sections.append(summary)
        }
        if let requestDetails, !requestDetails.isEmpty {
            sections.append("--- Request ---\n\(requestDetails)")
        }
        if let responseDetails, !responseDetails.isEmpty {
            sections.append("--- Response ---\n\(responseDetails)")
        }
        return sections.joined(separator: "\n\n")
    }

    private static func splitDetailsBlock(_ block: String) -> (String?, String?) {
        guard let responseIndex = block.range(of: responseSectionMarker) else {
            let request = block.trimmingCharacters(in: .newlines)
            return request.isEmpty ? (nil, nil) : (request, nil)
        }

        let request = String(block[..<responseIndex.lowerBound]).trimmingCharacters(in: .newlines)
        let response = String(block[responseIndex.lowerBound...]).trimmingCharacters(in: .newlines)
        return (
            request.isEmpty ? nil : request,
            response.isEmpty ? nil : response
        )
    }
}
