import Foundation

/// 从错误消息中解析出的请求/响应传输详情,供 `ErrorTransportDetailsButton` 展示。
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
