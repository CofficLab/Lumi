import ProviderConversation
import ProviderMessage
import SwiftUI

/// 缓存命中率工具栏视图。
struct CacheHitRateToolbarView: View {
    let conversations: any ConversationManaging
    let messages: any MessageManaging

    @State private var selectedConversationID: UUID?
    @State private var stats = CacheHitRateStats.empty
    @State private var isPopoverPresented = false

    @State private var conversationObserver: (any SelectedConversationObserverHandle)?
    @State private var messageObserver: (any MessageInsertedObserverHandle)?

    var body: some View {
        Group {
            if stats.sampleCount > 0 {
                Button {
                    isPopoverPresented.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "memorychip")
                            .font(.system(size: 10, weight: .medium))
                        Text(stats.percentText)
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .foregroundColor(percentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Color.secondary.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Average cache hit rate: \(stats.percentText) (\(stats.sampleCount) requests)")
                .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                    CacheHitRatePopover(stats: stats)
                }
            }
        }
        .task {
            selectedConversationID = conversations.selectedConversationID
            conversationObserver = conversations.addSelectedConversationObserver { newID in
                selectedConversationID = newID
            }
            messageObserver = messages.addMessageInsertedObserver { _, conversationID in
                if conversationID == selectedConversationID {
                    Task(priority: .utility) { @MainActor in
                        await Task.yield()
                        guard !Task.isCancelled, conversationID == selectedConversationID else { return }
                        await refresh()
                    }
                }
            }
        }
        .task(id: selectedConversationID) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    private var percentColor: Color {
        switch stats.averageHitRate {
        case 0.7...: return .green.opacity(0.85)
        case 0.4..<0.7: return .orange.opacity(0.9)
        default: return .red.opacity(0.85)
        }
    }

    private func refresh() async {
        guard let conversationID = selectedConversationID else {
            stats = .empty
            return
        }
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        guard conversationID == selectedConversationID else { return }
        stats = CacheHitRateStats.compute(messages: snapshot)
    }
}

private struct CacheHitRatePopover: View {
    let stats: CacheHitRateStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Text(LumiPluginLocalization.string("Cache Hit Rate", bundle: .module))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(stats.precisePercentText)
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundColor(hitRateColor)

            Text("\(stats.sampleCount) requests in this conversation")
                .font(.caption)
                .foregroundColor(.secondary)

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
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 280)
    }

    private var hitRateColor: Color {
        switch stats.averageHitRate {
        case 0.7...: return .green.opacity(0.9)
        case 0.4..<0.7: return .orange.opacity(0.95)
        default: return .red.opacity(0.9)
        }
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}
