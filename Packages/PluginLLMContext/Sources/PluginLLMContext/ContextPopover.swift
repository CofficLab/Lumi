import LumiUI
import ProviderMessage
import SwiftUI

/// 统一上下文详情弹窗：窗口大小、用量、使用趋势 + 压缩历史时间线。
struct ContextPopover: View {
    @LumiTheme private var theme

    let usage: ContextWindowUsageSnapshot?
    let history: ContextUsageHistory
    let events: [Message]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            windowSection
            if !events.isEmpty {
                Divider()
                compactionSection
            }
        }
        .background(theme.background)
    }

    // MARK: - Window Section

    private var windowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            usageRow

            if usage?.usesFallbackWindow == true, let usage {
                Text(String(
                    format: String(
                        localized: "Model window unknown; using a %@ fallback.",
                        defaultValue: "模型窗口未知，使用 %@ 作为估算值。",
                        bundle: .module
                    ),
                    usage.effectiveContextWindowTokens.formattedContextSize
                ))
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            }

            Divider()

            ContextUsageTrendView(history: history)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Compaction Section

    private var compactionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.warning)
                Text(String(localized: "Context compaction", defaultValue: "上下文压缩"))
                    .font(.headline)
                Spacer(minLength: 0)
                Text(String(format: String(localized: "%lld compactions", defaultValue: "%lld 次压缩"), events.count))
                    .font(.appCaption)
                    .foregroundStyle(theme.warning)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        CompactionTimelineRow(
                            message: event,
                            isLast: index == events.count - 1
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Usage Row

    /// 第一行：左侧是输入估算、输入预算与请求次数，右侧是上下文窗口圆环。
    private var usageRow: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs + 2) {
                if let usage, let estimated = usage.estimatedInputTokens, estimated > 0 {
                    usageLine(
                        label: String(localized: "Estimated input", defaultValue: "估算输入", bundle: .module),
                        value: estimated.formattedTokensShort
                    )
                    usageLine(
                        label: String(
                            localized: "LLMContext input budget",
                            defaultValue: "LLMContext 输入预算",
                            bundle: .module
                        ),
                        value: usage.inputTokenLimit.formattedTokensShort
                    )
                } else {
                    Text(String(localized: "No token usage data yet", defaultValue: "暂无令牌使用数据", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                usageLine(
                    label: String(localized: "Requests", defaultValue: "请求次数", bundle: .module),
                    value: "\(history.samples.count)"
                )
            }

            Spacer(minLength: 0)

            VStack(spacing: DesignTokens.Spacing.xs) {
                ContextUsageRing(
                    usedTokens: usage?.estimatedInputTokens,
                    limitTokens: usage?.inputTokenLimit ?? 0,
                    centerText: ringCenterText
                )
                Text(String(localized: "Context Window", defaultValue: "上下文窗口", bundle: .module))
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func usageLine(label: String, value: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .font(.appMonoCaption)
                .foregroundStyle(theme.textPrimary)
        }
    }

    /// 圆环中心显示的当前模型上下文窗口大小。
    private var ringCenterText: String {
        guard let contextWindowSize else {
            return String(localized: "Unknown", defaultValue: "未知", bundle: .module)
        }
        return contextWindowSize.formattedContextSize + (usage?.usesFallbackWindow == true ? "*" : "")
    }

    private var contextWindowSize: Int? {
        guard let usage else { return nil }
        return usage.contextWindowTokens
            ?? (usage.usesFallbackWindow ? usage.effectiveContextWindowTokens : nil)
    }
}

// MARK: - Compaction Timeline Row

private struct CompactionTimelineRow: View {
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

// MARK: - Preview

#if DEBUG && os(macOS)
#Preview("Context Popover - Usage And History") {
    ContextPopover(
        usage: ContextWindowUsageSnapshot(
            contextWindowTokens: 128_000,
            effectiveContextWindowTokens: 128_000,
            inputTokenLimit: 112_000,
            estimatedInputTokens: 41_500,
            usesFallbackWindow: false
        ),
        history: .preview,
        events: []
    )
}

#Preview("Context Popover - With Compactions") {
    ContextPopover(
        usage: ContextWindowUsageSnapshot(
            contextWindowTokens: 128_000,
            effectiveContextWindowTokens: 128_000,
            inputTokenLimit: 112_000,
            estimatedInputTokens: 104_000,
            usesFallbackWindow: false
        ),
        history: .preview,
        events: [.previewContextCompaction(), .previewContextCompaction()]
    )
}

#Preview("Context Popover - Fallback Window") {
    ContextPopover(
        usage: ContextWindowUsageSnapshot(
            contextWindowTokens: nil,
            effectiveContextWindowTokens: 32_000,
            inputTokenLimit: 22_000,
            estimatedInputTokens: nil,
            usesFallbackWindow: true
        ),
        history: .empty,
        events: []
    )
}
#endif
