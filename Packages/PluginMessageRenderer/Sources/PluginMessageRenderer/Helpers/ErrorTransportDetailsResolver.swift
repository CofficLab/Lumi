import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager

enum ErrorTransportDetailsResolver {
    private static let summarySeparator = "\n\n--- Request / Response Details ---\n"
    private static let responseSectionMarker = "Response Status:"
    private static let requestMetadataKey = "llm.transport.request"
    private static let responseMetadataKey = "llm.transport.response"

    static func resolve(for message: Message) -> ResolvedErrorTransportDetails {
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

    static func infoPopoverErrorSummary(for message: Message) -> String? {
        let hasRawErrorDetail = message.rawErrorDetail?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        guard message.isError || message.role == .error || hasRawErrorDetail else {
            return nil
        }

        let summary = resolve(for: message).displaySummary
        return summary.isEmpty ? nil : summary
    }

    private static func preferredSummary(from message: Message) -> String {
        if let rawErrorDetail = message.rawErrorDetail,
           !rawErrorDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rawErrorDetail
        }
        return message.content
    }

    private static func fullDetail(from message: Message) -> String {
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
