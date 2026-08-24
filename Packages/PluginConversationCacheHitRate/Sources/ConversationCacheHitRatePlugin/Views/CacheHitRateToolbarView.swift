import KernelLumi
import LumiUI
import SwiftUI

// MARK: - 缓存命中统计

/// 当前对话的缓存命中统计（纯计算，便于测试）。
struct CacheHitRateStats: Equatable {
    /// 有缓存用量数据的请求数（assistant 消息）。
    let sampleCount: Int
    /// 每条请求命中率的算术平均（0...1）。
    let averageHitRate: Double
    /// 所有请求缓存读取 tokens 之和。
    let totalCachedTokens: Int
    /// 所有请求输入 tokens 之和。
    let totalInputTokens: Int

    /// 按 token 加权的整体命中率（0...1）。
    var weightedHitRate: Double {
        totalInputTokens > 0 ? Double(totalCachedTokens) / Double(totalInputTokens) : 0
    }

    /// 从一批消息聚合缓存命中统计。
    ///
    /// 仅统计同时带有 `cachedInputTokens` 与 `cacheTotalInputTokens`（且总数 > 0）
    /// 的 assistant 消息；缺缓存用量的请求（如纯输出、无缓存计费的供应商）不计入样本。
    static func compute(messages: [LumiChatMessage]) -> CacheHitRateStats {
        var sampleCount = 0
        var rateSum = 0.0
        var totalCached = 0
        var totalInput = 0

        for message in messages where message.role == .assistant {
            guard let cached = intMetadata(message, MessageTokenMetadata.cachedInputKey),
                  let total = intMetadata(message, MessageTokenMetadata.cacheTotalInputKey),
                  total > 0 else { continue }
            sampleCount += 1
            rateSum += Double(cached) / Double(total)
            totalCached += cached
            totalInput += total
        }

        return CacheHitRateStats(
            sampleCount: sampleCount,
            averageHitRate: sampleCount > 0 ? rateSum / Double(sampleCount) : 0,
            totalCachedTokens: totalCached,
            totalInputTokens: totalInput
        )
    }

    private static func intMetadata(_ message: LumiChatMessage, _ key: String) -> Int? {
        message.metadata[key].flatMap { Int($0) }
    }
}

// MARK: - 工具栏视图

/// 工具栏视图：显示当前对话的平均缓存命中率。
///
/// 无缓存用量样本时隐藏（与同组件的 ContextSize / AgentTurnCount 行为一致），
/// 避免在没有缓存计费的模型/供应商下占位。变更经事件驱动重算，不挂 kernel 全局总线。
@MainActor
struct CacheHitRateToolbarView: View {
    @LumiTheme private var theme
    let kernel: KernelLumi

    @State private var selectedConversationID: UUID?
    @State private var stats = CacheHitRateStats(
        sampleCount: 0,
        averageHitRate: 0,
        totalCachedTokens: 0,
        totalInputTokens: 0
    )
    @State private var isPopoverPresented = false

    var body: some View {
        Group {
            if stats.sampleCount > 0 {
                Button {
                    isPopoverPresented.toggle()
                } label: {
                    buttonLabel
                }
                .buttonStyle(.plain)
                .help(
                    LumiPluginLocalization.string("Average cache hit rate: %@ (%lld requests)", bundle: .module)
                        .replacingOccurrences(of: "%@", with: stats.percentText)
                        .replacingOccurrences(of: "%lld", with: "\(stats.sampleCount)")
                )
                .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                    CacheHitRatePopover(stats: stats)
                }
            }
        }
        .task {
            selectedConversationID = kernel.conversations?.selectedConversationID
            refresh()
        }
        .onLumiSelectedConversationDidChange { newID in
            selectedConversationID = newID
        }
        .onLumiMessagesDidChange { eventConversationID in
            // 只关心当前会话的消息变更（nil 表示全量刷新）。
            guard eventConversationID == nil
                || eventConversationID == selectedConversationID else { return }
            refresh()
        }
        .onLumiTurnFinished { _ in
            // 回合结束时 token 用量 metadata 最终落盘，兜底刷新。
            refresh()
        }
        .onChange(of: selectedConversationID) { _, _ in
            refresh()
        }
    }

    @ViewBuilder
    private var buttonLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "memorychip")
                .font(.system(size: 11, weight: .medium))
            Text(stats.percentText)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundColor(percentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.surface.opacity(0.5))
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
    }

    /// 命中率语义色：>=70% 绿（缓存高效），40%..<70% 橙（部分命中），<40% 红（命中偏低）。
    private var percentColor: Color {
        switch stats.averageHitRate {
        case 0.7...: return Color.green.opacity(0.85)
        case 0.4..<0.7: return Color.orange.opacity(0.9)
        default: return Color.red.opacity(0.85)
        }
    }

    private func refresh() {
        guard let conversationID = selectedConversationID,
              let messageManager = kernel.messageManager else {
            stats = CacheHitRateStats(
                sampleCount: 0,
                averageHitRate: 0,
                totalCachedTokens: 0,
                totalInputTokens: 0
            )
            return
        }
        stats = CacheHitRateStats.compute(messages: messageManager.messages(for: conversationID))
    }
}

extension CacheHitRateStats {
    /// 整数百分比文案，如 "87%"。
    var percentText: String {
        String(format: "%.0f%%", averageHitRate * 100)
    }

    /// 一位小数百分比文案，如 "87.3%"。
    var precisePercentText: String {
        String(format: "%.1f%%", averageHitRate * 100)
    }
}

// MARK: - Popover Content

private struct CacheHitRatePopover: View {
    @LumiTheme private var theme
    let stats: CacheHitRateStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                Text(LumiPluginLocalization.string("Cache Hit Rate", bundle: .module))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(stats.precisePercentText)
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundColor(hitRateColor)

            Text(
                LumiPluginLocalization.string("%lld requests in this conversation", bundle: .module)
                    .replacingOccurrences(of: "%lld", with: "\(stats.sampleCount)")
            )
            .font(.caption)
            .foregroundColor(theme.textSecondary)

            Divider()

            statRow(
                icon: "arrow.down.circle",
                label: LumiPluginLocalization.string("Cached tokens", bundle: .module),
                value: stats.totalCachedTokens.formatted(.number.grouping(.automatic))
            )
            statRow(
                icon: "arrow.up.circle",
                label: LumiPluginLocalization.string("Total input tokens", bundle: .module),
                value: stats.totalInputTokens.formatted(.number.grouping(.automatic))
            )
            statRow(
                icon: "scalemass",
                label: LumiPluginLocalization.string("Token-weighted rate", bundle: .module),
                value: String(format: "%.1f%%", stats.weightedHitRate * 100)
            )

            Divider()

            Text("命中率 = 每条请求从缓存读取的 tokens ÷ 总输入 tokens 的算术平均。缓存命中越高，重复上下文计费越低、响应越快。")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .padding(12)
        .frame(width: 280)
        .background(theme.background)
    }

    private var hitRateColor: Color {
        switch stats.averageHitRate {
        case 0.7...: return Color.green.opacity(0.9)
        case 0.4..<0.7: return Color.orange.opacity(0.95)
        default: return Color.red.opacity(0.9)
        }
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textSecondary)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundColor(theme.textPrimary)
        }
    }
}
