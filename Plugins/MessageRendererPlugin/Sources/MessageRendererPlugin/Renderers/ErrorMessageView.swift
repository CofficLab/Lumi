import KernelLumi
import KernelLumi
import LumiUI
import SwiftUI

struct ErrorMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let verbosity: LumiResponseVerbosity

    private var isBrief: Bool { verbosity == .brief }

    /// 单次计算复用:resolver 会对 rawErrorDetail/content 做全串 trimming 与
    /// 分隔符扫描(HTTP body 可达 MB 级),历史实现每次 body 求值跑 2 次
    /// (transportDetails + summaryText),滚动重物化时被高频触发。
    private var resolvedDetails: ResolvedErrorTransportDetails {
        ErrorTransportDetailsResolver.resolve(for: message)
    }

    private func summaryText(for details: ResolvedErrorTransportDetails) -> String {
        let summary = details.displaySummary
        if !summary.isEmpty {
            return summary
        }
        return LumiPluginLocalization.string("Request failed.", bundle: .module)
    }

    private var httpBodyText: String? {
        guard let body = message.httpBody?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else {
            return nil
        }
        return body
    }

    var body: some View {
        // 局部 let:transportDetails/summary 在本次求值内只算一次
        let details = resolvedDetails
        let summary = summaryText(for: details)
        MessageViewChrome(
            message: message,
            errorTransportDetails: details,
            verbosity: verbosity
        ) {
            Group {
                if isBrief {
                    Text(summary)
                        .font(.appCaption)
                        .foregroundColor(theme.error)
                        .textSelection(.enabled)
                } else {
                    BorderedUtilityContent(tint: theme.error, role: .error) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let httpStatusCode = message.httpStatusCode {
                                Text("HTTP Status Code: \(httpStatusCode)")
                            }

                            Text(summary)

                            if let httpBodyText {
                                Text("HTTP Body:\n\(httpBodyText)")
                            }
                        }
                        .font(.appBody)
                        .foregroundColor(theme.error)
                        .textSelection(.enabled)
                    }
                }
            }
        }
    }
}
