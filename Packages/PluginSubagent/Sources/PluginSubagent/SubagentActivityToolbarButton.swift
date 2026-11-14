import ProviderToolManager
import SwiftUI

/// ChatToolbar 上的子代理运行指示器：胶囊按钮 + 弹层。
///
/// 视觉风格对齐 `GitChatToolbarButton`：图标 + 计数徽标，accentColor 高亮。
/// 仅当当前会话存在未终态的 `run_subagent` Job 时占位，无活动时渲染
/// EmptyView，不占用工具栏空间。
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
        .onChange(of: viewModel.selectedConversationID) { newValue in
            // 会话切换：关闭弹层避免显示旧会话的子代理状态。
            if newValue == nil {
                isPopoverPresented = false
            }
        }
    }

    // MARK: - Label

    private var label: some View {
        HStack(spacing: 3) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10, weight: .medium))

            Text("\(viewModel.activeCount)")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundColor(Color.accentColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Color.accentColor.opacity(0.22),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
    }
}

/// ChatToolbar 弹层：当前会话的子代理委托列表。
///
/// 运行中的委托在前（状态 + 实时耗时），最近结束的紧随其后供回看。
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
                    Text("\(viewModel.activeCount)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline.monospacedDigit())
                }

                if viewModel.jobs.isEmpty {
                    emptyState
                } else {
                    if !viewModel.activeSubagents.isEmpty {
                        section(title: pluginLocalization.string("Running")) {
                            ForEach(viewModel.activeSubagents) { job in
                                SubagentActivityRow(job: job, viewModel: viewModel)
                            }
                        }
                    }

                    if !viewModel.finishedSubagents.isEmpty {
                        section(title: pluginLocalization.string("Finished"), secondary: true) {
                            ForEach(viewModel.finishedSubagents) { job in
                                SubagentActivityRow(job: job, viewModel: viewModel)
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondary ? Color.secondary : Color.accentColor)
                .textCase(.uppercase)
            VStack(spacing: 1) {
                content()
            }
        }
    }
}

private struct SubagentActivityRow: View {
    let job: ToolJob
    @ObservedObject var viewModel: SubagentActivityViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            statusIcon
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.label(for: job))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Text(viewModel.statusTitle(for: job))
                    if let duration = viewModel.elapsedDuration(for: job) {
                        Text("·")
                        Text(viewModel.formatDuration(duration))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                if let progress = job.latestProgress?.message, !progress.isEmpty, !job.status.isTerminal {
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

    @ViewBuilder
    private var statusIcon: some View {
        if job.status == .running || job.status == .queued {
            ProgressView()
                .controlSize(.mini)
        } else {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(iconColor)
        }
    }

    private var iconName: String {
        if viewModel.isFailed(job) { return "exclamationmark.triangle.fill" }
        switch job.status {
        case .waitingForUser: return "hand.raised.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled, .cancelling: return "xmark.circle.fill"
        case .queued, .running, .failed, .timedOut: return "circle"
        }
    }

    private var iconColor: Color {
        if viewModel.isFailed(job) { return .red }
        switch job.status {
        case .waitingForUser: return .orange
        case .completed: return .green
        case .cancelled, .cancelling: return .secondary
        case .queued, .running, .failed, .timedOut: return .accentColor
        }
    }
}
