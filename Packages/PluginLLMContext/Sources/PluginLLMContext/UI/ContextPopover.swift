import LumiUI
import ProviderLLMContext
import ProviderMessage
import SwiftUI

/// 统一上下文详情弹窗：窗口大小、用量、使用趋势 + 压缩历史时间线。
struct ContextPopover: View {
    @LumiTheme private var theme

    let usage: ContextWindowUsageSnapshot?
    let history: ContextUsageHistory
    let events: [Message]
    /// 幕后调用（压缩摘要 / 标题）用量；独立于上下文曲线展示开销。
    var auxiliaryEntries: [LLMAuxiliaryUsageEntry] = []

    @State private var isExporting = false

    private var auxiliaryOverheads: [LLMAuxiliaryOverhead] {
        LLMAuxiliaryOverhead.summarize(auxiliaryEntries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView(showsExportButton: true)

            ScrollView {
                sectionsContent
            }
        }
        .background(theme.background)
        .frame(width: 360)
        .frame(maxHeight: 520)
    }

    // MARK: - Header

    /// 标题行：图标 + 标题（+ 导出按钮）。
    ///
    /// 导出图片复用同一份标题，但不带按钮——导出的图里不该再有一个「下载」入口。
    private func headerView(showsExportButton: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.primary)
            Text(String(localized: "Context", defaultValue: "上下文", bundle: .module))
                .font(.headline)
                .fixedSize()
            Spacer(minLength: 8)
            #if os(macOS)
            if showsExportButton {
                exportButton
            }
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    #if os(macOS)
    /// 导出当前弹窗内容为 PNG。
    @ViewBuilder
    private var exportButton: some View {
        Button(action: exportAsImage) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .opacity(isExporting ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .help(String(localized: "Save as image", defaultValue: "保存为图片", bundle: .module))
    }

    /// 把弹窗内容导出为 PNG 文件。
    ///
    /// 导出的内容与弹窗一致，但不受弹窗最大高度约束，
    /// 保证压缩历史被完整渲染，而不是只截到可视区域。
    @MainActor
    private func exportAsImage() {
        isExporting = true
        defer { isExporting = false }
        ContextPopoverImageExporter.export(
            content: exportContent,
            suggestedFileName: "llm-context.png"
        )
    }
    #endif

    // MARK: - Export Content

    #if os(macOS)
    /// 导出用的完整内容：宽度与弹窗一致，高度由内容撑开。
    ///
    /// 刻意不套最大高度约束——弹窗的 `maxHeight: 520` 会把超出的内容裁掉，
    /// 导出的图就会丢掉视口外的压缩时间线。
    var exportContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView(showsExportButton: false)
            sectionsContent
        }
        .frame(width: 360, alignment: .leading)
        .background(theme.background)
        .background(Color(.windowBackgroundColor))
    }
    #endif

    // MARK: - Sections

    /// 弹窗正文：窗口信息 + 幕后开销 + 压缩历史。
    private var sectionsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            windowSection
            if !auxiliaryOverheads.isEmpty {
                Divider()
                auxiliarySection
            }
            if !events.isEmpty {
                Divider()
                compactionSection
            }
        }
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

    // MARK: - Auxiliary Overhead Section

    /// 幕后调用开销：压缩摘要与标题各自消耗了多少额度。
    ///
    /// 这些调用不属于对话回合，因此不进入上方的上下文曲线；这里单独列出，
    /// 让「省了多少 / 花了多少」可被核算。供应商未上报用量时标注估算或不可用，
    /// 绝不显示零。
    private var auxiliarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Text(String(localized: "Background usage", defaultValue: "幕后调用开销", bundle: .module))
                    .font(.headline)
            }

            ForEach(auxiliaryOverheads, id: \.purpose) { overhead in
                auxiliaryRow(overhead)
            }

            Text(String(
                localized: "Summaries and titles run outside the conversation turn, so they are not part of the context curve above.",
                defaultValue: "摘要与标题在对话回合之外运行，不计入上方的上下文曲线。",
                bundle: .module
            ))
            .font(.appCaption)
            .foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func auxiliaryRow(_ overhead: LLMAuxiliaryOverhead) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(auxiliaryPurposeLabel(overhead.purpose))
                .font(.appCaption)
                .foregroundStyle(theme.textPrimary)
            Text(String(
                format: String(localized: "%lld calls", defaultValue: "%lld 次", bundle: .module),
                overhead.callCount
            ))
            .font(.appMicro)
            .foregroundStyle(theme.textSecondary)
            Spacer(minLength: 0)
            Text(auxiliarySpentText(overhead))
                .font(.appMonoCaption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func auxiliaryPurposeLabel(_ purpose: LLMAuxiliaryPurpose) -> String {
        switch purpose {
        case .compaction:
            return String(localized: "Compaction summaries", defaultValue: "压缩摘要", bundle: .module)
        case .title:
            return String(localized: "Conversation titles", defaultValue: "对话标题", bundle: .module)
        }
    }

    private func auxiliarySpentText(_ overhead: LLMAuxiliaryOverhead) -> String {
        guard let spent = overhead.spentTokens else {
            return String(localized: "Usage unavailable", defaultValue: "用量不可用", bundle: .module)
        }
        let value = spent.formattedTokensShort
        if overhead.hasEstimatedUsage {
            return String(
                format: String(localized: "~%@ (estimated)", defaultValue: "~%@（估算）", bundle: .module),
                value
            )
        }
        return value
    }

    // MARK: - Compaction Section

    /// 压缩历史时间线。
    private var compactionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.warning)
                Text(String(localized: "Context compaction", defaultValue: "上下文压缩", bundle: .module))
                    .font(.headline)
                Spacer(minLength: 0)
                Text(String(format: String(localized: "%lld compactions", defaultValue: "%lld 次压缩", bundle: .module), events.count))
                    .font(.appCaption)
                    .foregroundStyle(theme.warning)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

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
                    if let summaryAuthorText {
                        Text(summaryAuthorText)
                            .font(.appCaption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let savingsText {
                        Text(savingsText)
                            .font(.appCaption)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
        let model = message.modelName ?? String(localized: "Unknown model", defaultValue: "未知模型", bundle: .module)
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
            return "\(String(localized: "Context window", defaultValue: "上下文窗口", bundle: .module)) \(formatTokens(contextWindow)) · \(String(localized: "input budget", defaultValue: "输入预算", bundle: .module)) \(formatTokens(inputLimit))"
        }
        let effective = MessageTimelineEvent.integerMetadata(
            MessageTimelineEvent.contextCompactionEffectiveWindowTokensKey,
            from: message
        )
        let fallback = effective.map { "\(formatTokens($0)) fallback" }
            ?? String(localized: "Unknown context window", defaultValue: "上下文窗口未知", bundle: .module)
        if let inputLimit {
            return "\(fallback) · \(String(localized: "input budget", defaultValue: "输入预算", bundle: .module)) \(formatTokens(inputLimit))"
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

    /// 实际产出摘要的模型（可能与对话主模型不同）；未记录时不显示。
    private var summaryAuthorText: String? {
        let provider = message.metadata[MessageTimelineEvent.contextCompactionSummaryProviderIDKey]
        let model = message.metadata[MessageTimelineEvent.contextCompactionSummaryModelNameKey]
        guard provider != nil || model != nil else { return nil }
        let label = String(localized: "Summary model", defaultValue: "摘要模型", bundle: .module)
        let unknown = String(localized: "Unknown model", defaultValue: "未知模型", bundle: .module)
        if let provider, !provider.isEmpty {
            return "\(label): \(provider) · \(model ?? unknown)"
        }
        return "\(label): \(model ?? unknown)"
    }

    /// 节省（估算）/ 摘要消耗（真实或标注估算）/ 净收益；缺失端标注不可用，不显示零。
    private var savingsText: String? {
        let saved = MessageTimelineEvent.compactionSavedTokens(for: message)
        let spent = MessageTimelineEvent.compactionSpentTokens(for: message)
        guard saved != nil || spent != nil else { return nil }

        let savedLabel = String(localized: "Saved", defaultValue: "节省", bundle: .module)
        let spentLabel = String(localized: "summary cost", defaultValue: "摘要消耗", bundle: .module)
        let netLabel = String(localized: "net", defaultValue: "净收益", bundle: .module)
        let unavailable = String(localized: "unavailable", defaultValue: "不可用", bundle: .module)

        let savedText = saved.map { "~\(formatTokens($0))" } ?? unavailable
        let spentText: String
        if let spent {
            spentText = MessageTimelineEvent.compactionSpentIsEstimated(for: message)
                ? "~\(formatTokens(spent)) (\(String(localized: "estimated", defaultValue: "估算", bundle: .module)))"
                : formatTokens(spent)
        } else {
            spentText = unavailable
        }
        let netText = MessageTimelineEvent.compactionNetTokens(for: message).map(formatTokens) ?? unavailable
        return "\(savedLabel) \(savedText) · \(spentLabel) \(spentText) · \(netLabel) \(netText)"
    }

    private var reason: MessageTimelineEvent.ContextCompactionReason {
        MessageTimelineEvent.compactionReason(for: message)
    }

    private var reasonText: String {
        switch reason {
        case .hardThreshold:
            return String(localized: "Threshold", defaultValue: "达到阈值", bundle: .module)
        case .contextLimitRetry:
            return String(localized: "Retry", defaultValue: "超限重试", bundle: .module)
        case .emergency:
            return String(localized: "Emergency", defaultValue: "紧急", bundle: .module)
        case .legacy:
            return String(localized: "Legacy", defaultValue: "历史记录", bundle: .module)
        }
    }

    private var reasonExplanation: String {
        switch reason {
        case .hardThreshold:
            return String(localized: "The input budget reached the hard threshold.", defaultValue: "输入预算达到硬阈值后进行了压缩。", bundle: .module)
        case .contextLimitRetry:
            return String(localized: "The provider rejected the context size, so Lumi compacted and retried.", defaultValue: "供应商返回上下文长度超限，Lumi 压缩后重新尝试。", bundle: .module)
        case .emergency:
            return String(localized: "An emergency compaction was requested to keep the next request safe.", defaultValue: "为保证下一次请求安全，执行了紧急压缩。", bundle: .module)
        case .legacy:
            return String(localized: "This record was created before detailed compaction information was saved.", defaultValue: "这条记录创建于详细压缩信息保存之前。", bundle: .module)
        }
    }

    private var accessibilityText: String {
        var parts = [
            message.createdAt.formatted(date: .abbreviated, time: .shortened),
            modelText,
            windowText,
            estimateText,
        ]
        if let summaryAuthorText { parts.append(summaryAuthorText) }
        if let savingsText { parts.append(savingsText) }
        parts.append(reasonExplanation)
        return parts.joined(separator: ", ")
    }

    private func formatTokens(_ tokens: Int?) -> String {
        guard let tokens else {
            return String(localized: "Unknown", defaultValue: "未知", bundle: .module)
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
