import LumiKernel

struct ResolvedErrorTransportDetails: Equatable {
    let summary: String
    let requestDetails: String?
    let responseDetails: String?

    var hasTransportDetails: Bool {
        requestDetails != nil || responseDetails != nil
    }

    var displaySummary: String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? summary : trimmed
    }
}

enum ErrorTransportDetailsResolver {
    private static let summarySeparator = "\n\n--- Request / Response Details ---\n"
    private static let responseSectionMarker = "Response Status:"
    private static let requestMetadataKey = "llm.transport.request"
    private static let responseMetadataKey = "llm.transport.response"

    static func resolve(for message: LumiChatMessage) -> ResolvedErrorTransportDetails {
        if let requestDetails = message.metadata[requestMetadataKey] {
            return ResolvedErrorTransportDetails(
                summary: preferredSummary(from: message),
                requestDetails: requestDetails,
                responseDetails: message.metadata[responseMetadataKey]
            )
        }

        let fullDetail = fullDetail(from: message)
        guard let separatorRange = fullDetail.range(of: summarySeparator) else {
            return ResolvedErrorTransportDetails(
                summary: fullDetail,
                requestDetails: nil,
                responseDetails: nil
            )
        }

        let summary = String(fullDetail[..<separatorRange.lowerBound])
        let detailsBlock = String(fullDetail[separatorRange.upperBound...])
        let (requestDetails, responseDetails) = splitDetailsBlock(detailsBlock)

        return ResolvedErrorTransportDetails(
            summary: summary,
            requestDetails: requestDetails,
            responseDetails: responseDetails
        )
    }

    private static func preferredSummary(from message: LumiChatMessage) -> String {
        if let rawErrorDetail = message.rawErrorDetail,
           !rawErrorDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rawErrorDetail
        }
        return message.content
    }

    private static func fullDetail(from message: LumiChatMessage) -> String {
        let candidates = [message.rawErrorDetail, message.content]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return candidates.max(by: { $0.count < $1.count }) ?? ""
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
