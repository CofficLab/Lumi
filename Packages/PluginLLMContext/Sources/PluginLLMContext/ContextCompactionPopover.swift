import LumiUI
import ProviderMessage
import SwiftUI

struct ContextCompactionPopover: View {
    @LumiTheme private var theme

    let events: [Message]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if events.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            ContextCompactionTimelineRow(
                                message: event,
                                isLast: index == events.count - 1
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(theme.background)
        .frame(width: 380, height: events.isEmpty ? 230 : 430)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.warning)
            Text(String(localized: "Context compaction", defaultValue: "上下文压缩"))
                .font(.headline)
            Spacer(minLength: 0)
            Text(
                String(
                    format: String(localized: "%lld times", defaultValue: "%lld 次"),
                    events.count
                )
            )
            .font(.appCaption)
            .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(theme.textTertiary)
            Text(String(localized: "No compaction yet", defaultValue: "尚未发生上下文压缩"))
                .font(.subheadline.weight(.semibold))
            Text(
                String(
                    localized: "Background summary prewarming is not shown here.",
                    defaultValue: "后台摘要预热不会显示在这里。"
                )
            )
            .font(.appCaption)
            .foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct ContextCompactionTimelineRow: View {
    @LumiTheme private var theme

    let message: Message
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            timelineRail
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.appCaptionEmphasized)
                    Spacer(minLength: 0)
                    Text(reasonText)
                        .font(.appMicroEmphasized)
                        .foregroundStyle(theme.warning)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(modelText)
                        .font(.appCaptionEmphasized)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(windowText)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                    Text(estimateText)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }

                Text(reasonExplanation)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 18)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var timelineRail: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(theme.warning)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            if !isLast {
                Rectangle()
                    .fill(theme.divider)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 4)
            }
        }
        .frame(width: 10)
    }

    private var modelText: String {
        let provider = message.providerID
        let model = message.modelName ?? String(localized: "Unknown model", defaultValue: "未知模型")
        if let provider, !provider.isEmpty {
            return "\(provider) · \(model)"
        }
        return model
    }

    private var windowText: String {
        let inputLimit = MessageTimelineEvent.integerMetadata(
            MessageTimelineEvent.contextCompactionInputTokenLimitKey,
            from: message
        )
        if let contextWindow = MessageTimelineEvent.integerMetadata(
            MessageTimelineEvent.contextCompactionContextWindowTokensKey,
            from: message
        ) {
            return "\(String(localized: "Context window", defaultValue: "上下文窗口")) \(formatTokens(contextWindow)) · \(String(localized: "input budget", defaultValue: "输入预算")) \(formatTokens(inputLimit))"
        }
        let effective = MessageTimelineEvent.integerMetadata(
            MessageTimelineEvent.contextCompactionEffectiveWindowTokensKey,
            from: message
        )
        let fallback = effective.map { "\(formatTokens($0)) fallback" }
            ?? String(localized: "Unknown context window", defaultValue: "上下文窗口未知")
        if let inputLimit {
            return "\(fallback) · \(String(localized: "input budget", defaultValue: "输入预算")) \(formatTokens(inputLimit))"
        }
        return fallback
    }

    private var estimateText: String {
        let original = MessageTimelineEvent.integerMetadata(
            MessageTimelineEvent.contextCompactionOriginalEstimateKey,
            from: message
        )
        let compacted = MessageTimelineEvent.integerMetadata(
            MessageTimelineEvent.contextCompactionCompactedEstimateKey,
            from: message
        )
        return "\(formatTokens(original)) → \(formatTokens(compacted)) tokens"
    }

    private var reason: MessageTimelineEvent.ContextCompactionReason {
        MessageTimelineEvent.compactionReason(for: message)
    }

    private var reasonText: String {
        switch reason {
        case .hardThreshold:
            return String(localized: "Threshold", defaultValue: "达到阈值")
        case .contextLimitRetry:
            return String(localized: "Retry", defaultValue: "超限重试")
        case .emergency:
            return String(localized: "Emergency", defaultValue: "紧急")
        case .legacy:
            return String(localized: "Legacy", defaultValue: "历史记录")
        }
    }

    private var reasonExplanation: String {
        switch reason {
        case .hardThreshold:
            return String(localized: "The input budget reached the hard threshold.", defaultValue: "输入预算达到硬阈值后进行了压缩。")
        case .contextLimitRetry:
            return String(localized: "The provider rejected the context size, so Lumi compacted and retried.", defaultValue: "供应商返回上下文长度超限，Lumi 压缩后重新尝试。")
        case .emergency:
            return String(localized: "An emergency compaction was requested to keep the next request safe.", defaultValue: "为保证下一次请求安全，执行了紧急压缩。")
        case .legacy:
            return String(localized: "This record was created before detailed compaction information was saved.", defaultValue: "这条记录创建于详细压缩信息保存之前。")
        }
    }

    private var accessibilityText: String {
        "\(message.createdAt.formatted(date: .abbreviated, time: .shortened)), \(modelText), \(windowText), \(estimateText), \(reasonExplanation)"
    }

    private func formatTokens(_ tokens: Int?) -> String {
        guard let tokens else {
            return String(localized: "Unknown", defaultValue: "未知")
        }
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        }
        if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }
}
