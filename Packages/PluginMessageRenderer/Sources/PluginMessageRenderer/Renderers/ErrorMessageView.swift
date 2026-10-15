import KitAgentTool
import KernelCore
import LumiLocalizationKit
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import LumiUI
import SwiftUI

struct ErrorMessageView: View {
    @LumiTheme private var theme

    let capability: (any MessageRendererCapability)?
    let message: Message
    let verbosity: ResponseVerbosity

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
        return pluginLocalization.string("Request failed.")
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
            capability: capability,
            message: message,
            showsRetryButton: true,
            errorTransportDetails: details,
            verbosity: verbosity
        ) {
            Group {
                if isBrief {
                    Text(summary)
                        .font(.appCaption)
                        .foregroundColor(theme.error)
                        .textSelection(.enabled)
                        .accessibilityIdentifier(Self.contentAccessibilityIdentifier)
                } else {
                    BorderedUtilityContent(tint: theme.error, role: .error) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let httpStatusCode = message.httpStatusCode {
                                Text("HTTP Status Code: \(httpStatusCode)")
                            }

                            Text(summary)
                            .accessibilityIdentifier(Self.contentAccessibilityIdentifier)

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

    /// 错误摘要文本的无障碍标识。
    ///
    /// UI 测试用它确认错误消息确实渲染出来了。
    /// 不用「统计错误行数量」来判定重试是否生效：重跑之后的回合结局不确定
    /// （可能成功、可能再次失败），行数不是可靠信号；重试判定见
    /// `ErrorRetryUITestingSupport.retryMarkerContent`。
    static let contentAccessibilityIdentifier = "lumi.message.error.content"
}
