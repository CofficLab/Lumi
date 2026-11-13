import ProviderToolManager
import SwiftUI

/// ChatToolbar 上的子代理运行指示器：胶囊按钮 + 弹层（#1313 / #1328）。
///
/// 视觉风格对齐 `GitChatToolbarButton`：图标 + 计数徽标。颜色表达注意力：
/// 失败红色、等待用户橙色、运行中 accent；不额外加文字。
struct SubagentActivityToolbarButton: View {
    @ObservedObject var viewModel: SubagentActivityViewModel
    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            label
        }
        .buttonStyle(.plain)
        .help(pluginLocalization.string("Subagents"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            SubagentActivityPopoverView(viewModel: viewModel)
        }
        .onChange(of: viewModel.selectedConversationID) { _, newValue in
            // 会话切换：关闭弹层避免显示旧会话的子代理状态。
            if newValue == nil {
                isPopoverPresented = false
            }
        }
    }

    // MARK: - Label

    private var statusColor: Color {
        switch viewModel.status {
        case .failure:
            return .red
        case .waiting:
            return .orange
        case .running, .idle:
            return .accentColor
        }
    }

    private var label: some View {
        HStack(spacing: 3) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10, weight: .medium))

            Text("\(viewModel.capsuleCount)")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            statusColor.opacity(0.22),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
    }
}

/// ChatToolbar 弹层：当前会话的子代理活动列表。
///
/// 排序是注意力优先：需要用户处理（等待/失败）→ 运行中 → 已结束。
/// 每行展示名字、当前工具、工具数、耗时与待读取的代理消息数。
struct SubagentActivityPopoverView: View {
    @ObservedObject var viewModel: SubagentActivityViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(pluginLocalization.string("Subagents"))
                        .font(.headline)
                    Spacer()
                    Text("\(viewModel.capsuleCount)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline.monospacedDigit())
                }

                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    if !viewModel.attentionItems.isEmpty {
                        section(
                            title: pluginLocalization.string("Needs attention"),
                            tint: .orange
                        ) {
                            ForEach(viewModel.attentionItems) { item in
                                SubagentActivityRow(item: item, viewModel: viewModel)
                            }
                        }
                    }

                    if !viewModel.runningItems.isEmpty {
                        section(title: pluginLocalization.string("Running")) {
                            ForEach(viewModel.runningItems) { item in
                                SubagentActivityRow(item: item, viewModel: viewModel)
                            }
                        }
                    }

                    if !viewModel.finishedItems.isEmpty {
                        section(title: pluginLocalization.string("Finished"), secondary: true) {
                            ForEach(viewModel.finishedItems) { item in
                                SubagentActivityRow(item: item, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 360)
        .frame(minHeight: 160, maxHeight: 420)
        .background(.background)
        .onAppear { viewModel.refresh() }
    }

    private var emptyState: some View {
        Text(pluginLocalization.string("No subagents in this conversation"))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    private func section<Content: View>(
        title: String,
        secondary: Bool = false,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint ?? (secondary ? Color.secondary : Color.accentColor))
                .textCase(.uppercase)
            VStack(spacing: 1) {
                content()
            }
        }
    }
}

private struct SubagentActivityRow: View {
    let item: SubagentActivityItem
    @ObservedObject var viewModel: SubagentActivityViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            statusIcon
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(viewModel.name(for: item))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if item.pendingMessageCount > 0 {
                        pendingBadge
                    }
                }

                HStack(spacing: 5) {
                    Text(statusTitle)
                    if let tool = item.currentToolName, !tool.isEmpty {
                        Text("·")
                        Text(tool)
                            .lineLimit(1)
                    }
                    if let duration = viewModel.elapsedDuration(for: item.job) {
                        Text("·")
                        Text(viewModel.formatDuration(duration))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if !detailText.isEmpty {
                    Text(detailText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let progress = item.job.latestProgress?.message,
                   !progress.isEmpty,
                   !item.job.status.isTerminal {
                    Text(progress)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private var statusTitle: String {
        viewModel.statusTitle(for: item.job)
    }

    private var pendingBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 8, weight: .semibold))
            Text("\(item.pendingMessageCount)")
                .font(.system(size: 9, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(Color.accentColor, in: Capsule())
        .help(pluginLocalization.string("%lld messages"))
    }

    /// 已完成的工具数与待读取消息数；两者都为零时不占行。
    private var detailText: String {
        var parts: [String] = []
        if item.completedToolCount > 0 {
            parts.append(String(
                format: pluginLocalization.string("%lld tool calls"),
                item.completedToolCount
            ))
        }
        if item.pendingMessageCount > 0 {
            parts.append(String(
                format: pluginLocalization.string("%lld messages"),
                item.pendingMessageCount
            ))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var statusIcon: some View {
        if item.job.status == .running || item.job.status == .queued {
            ProgressView()
                .controlSize(.mini)
        } else {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(iconColor)
        }
    }

    private var iconName: String {
        if viewModel.isFailed(item.job) { return "exclamationmark.triangle.fill" }
        switch item.job.status {
        case .waitingForUser: return "hand.raised.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled, .cancelling: return "xmark.circle.fill"
        case .queued, .running, .failed, .timedOut: return "circle"
        }
    }

    private var iconColor: Color {
        if viewModel.isFailed(item.job) { return .red }
        switch item.job.status {
        case .waitingForUser: return .orange
        case .completed: return .green
        case .cancelled, .cancelling: return .secondary
        case .queued, .running, .failed, .timedOut: return .accentColor
        }
    }
}
