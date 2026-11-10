import CoreGraphics
import Foundation
import KitAgentTool
import LumiLocalizationKit
import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import SwiftUI

/// V5（ChatGPT）内联错误的呈现规格。
///
/// 基准是 V5 方案第 2.6 节：
/// - 错误**内联**显示在对应 turn，而不是全局提示；
/// - 提供现有详情和**有效**重试；
/// - 失败不能自动抢焦点或强制滚到底。
enum ChatGPTErrorStyle {

    // MARK: - 几何

    /// 内容圆角。
    static let cornerRadius: CGFloat = 10

    /// 内容内边距。
    static let contentPadding: CGFloat = 10

    /// 标题与正文的间距。
    static let contentSpacing: CGFloat = 6

    // MARK: - 重试

    /// 该错误消息的回合当前是否真的可重试。
    ///
    /// - Important: 必须带有效 `turnID`，且 AgentLoop 仍停留在该失败回合上。
    ///   回合已被新回合取代时返回 nil，否则点击会触发一次注定失败的重试。
    @MainActor
    static func retryableTurnID(
        message: Message,
        capability: (any MessageRendererCapability)?
    ) -> UUID? {
        ChatGPTAssistantTextStyle.retryableTurnID(message: message, capability: capability)
    }
}

/// V5（ChatGPT）内联错误视图。
///
/// - Important: 复用真实的错误详情解析（`ErrorTransportDetailsResolver`），
///   保留现有隐私与诊断行为，不新增原文日志。
struct ChatGPTErrorMessageView: View {
    @LumiTheme private var theme

    let capability: (any MessageRendererCapability)?
    let message: Message
    let verbosity: ResponseVerbosity

    /// 单次计算复用：resolver 会对 rawErrorDetail/content 做全串 trimming 与
    /// 分隔符扫描（HTTP body 可达 MB 级），历史实现每次 body 求值跑 2 次，
    /// 滚动重物化时被高频触发。
    private var resolvedDetails: ResolvedErrorTransportDetails {
        ErrorTransportDetailsResolver.resolve(for: message)
    }

    private var summaryText: String {
        let summary = resolvedDetails.displaySummary
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

    /// 可重试的回合 ID；不可重试时为 nil。
    private var retryableTurnID: UUID? {
        ChatGPTErrorStyle.retryableTurnID(message: message, capability: capability)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ChatGPTErrorStyle.contentSpacing) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundColor(theme.error)
                Text(summaryText)
                    .font(.appBody)
                    .foregroundColor(theme.error)
                    .textSelection(.enabled)
                    .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.errorContent)
                Spacer(minLength: 0)
                retryButton
            }

            if let httpStatusCode = message.httpStatusCode {
                Text("HTTP Status Code: \(httpStatusCode)")
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textSecondary)
                    .textSelection(.enabled)
            }

            if let httpBodyText {
                Text("HTTP Body:\n\(httpBodyText)")
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textSecondary)
                    .textSelection(.enabled)
            }
        }
        .padding(ChatGPTErrorStyle.contentPadding)
        .background(
            theme.error.opacity(0.08),
            in: RoundedRectangle(
                cornerRadius: ChatGPTErrorStyle.cornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: ChatGPTErrorStyle.cornerRadius,
                style: .continuous
            )
            .strokeBorder(theme.error.opacity(0.24), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 重试

    /// 重试按钮。
    ///
    /// - Important: 只有**真实可重试**的失败回合才显示。
    ///   成功回复绝不出现重试或「重新生成」。
    @ViewBuilder
    private var retryButton: some View {
        if let turnID = retryableTurnID {
            Button {
                Task {
                    await capability?.retryTurn(
                        turnID: turnID,
                        conversationID: message.conversationID
                    )
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
                    .foregroundColor(theme.error)
                    .frame(
                        width: ChatGPTAssistantTextStyle.actionButtonSize,
                        height: ChatGPTAssistantTextStyle.actionButtonSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.errorRetryButton)
            .accessibilityLabel(pluginLocalization.string("重试"))
            .help(pluginLocalization.string("重试该回合"))
        }
    }
}
