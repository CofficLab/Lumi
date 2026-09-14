import LumiUI
import SwiftUI

/// 上下文窗口详情弹窗：窗口大小、当前估算与输入预算，以及历史使用趋势。
struct ContextWindowPopover: View {
    @LumiTheme private var theme

    let usage: ContextWindowUsageSnapshot?
    let history: ContextUsageHistory

    private var contextWindowSize: Int? {
        guard let usage else { return nil }
        return usage.contextWindowTokens
            ?? (usage.usesFallbackWindow ? usage.effectiveContextWindowTokens : nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            windowSize

            if let usage, let estimated = usage.estimatedInputTokens, estimated > 0 {
                currentUsage(usage: usage, estimated: estimated)
            } else {
                Text(String(localized: "No token usage data yet", defaultValue: "暂无令牌使用数据", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

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
            } else {
                Text(String(localized: "Input estimate and budget use the same LLMContext rules as compaction.", defaultValue: "输入估算和预算使用与 LLMContext 压缩相同的口径。", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            Divider()

            ContextUsageTrendView(history: history)

            Divider()

            Text("上下文窗口是模型单次请求可处理的最大 token 数。输入估算使用 LLMContext 同一套规则；输入预算会为输出、工具 schema 和安全余量预留空间。")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(12)
        .frame(width: 300)
    }
}

// MARK: - View

extension ContextWindowPopover {
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text(String(localized: "Context Window", defaultValue: "上下文窗口", bundle: .module))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private var windowSize: some View {
        Group {
            if let contextWindowSize {
                Text(contextWindowSize.formattedContextSize + (usage?.usesFallbackWindow == true ? "*" : ""))
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
            } else {
                Text(String(localized: "Unknown", defaultValue: "未知", bundle: .module))
                    .font(.system(size: 28, weight: .bold))
            }
        }
    }

    private func currentUsage(usage: ContextWindowUsageSnapshot, estimated: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(
                format: String(
                    localized: "Estimated input: %@ tokens",
                    defaultValue: "估算输入：%@ tokens",
                    bundle: .module
                ),
                estimated.formattedTokensShort
            ))
            .font(.caption)
            .foregroundStyle(theme.textSecondary)

            Text(String(
                format: String(
                    localized: "LLMContext input budget: %@ tokens",
                    defaultValue: "LLMContext 输入预算：%@ tokens",
                    bundle: .module
                ),
                usage.inputTokenLimit.formattedTokensShort
            ))
            .font(.caption)
            .foregroundStyle(theme.textSecondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.divider)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForUsage(estimated: estimated, limit: usage.inputTokenLimit))
                        .frame(width: geo.size.width * min(
                            Double(estimated) / Double(max(usage.inputTokenLimit, 1)),
                            1.0
                        ))
                }
            }
            .frame(height: 6)
        }
    }

    private func colorForUsage(estimated: Int, limit: Int) -> Color {
        guard limit > 0 else { return theme.textSecondary }
        let ratio = Double(estimated) / Double(limit)
        if ratio >= 0.9 { return .red }
        if ratio >= 0.75 { return theme.warning }
        return theme.textSecondary
    }
}
