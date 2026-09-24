import SwiftUI
import ProviderToolManager

struct ToolActivityToolbarView: View {
    @ObservedObject var viewModel: ToolActivityViewModel
    @State private var isPresented = false

    var body: some View {
        Button {
            viewModel.refresh()
            isPresented.toggle()
        } label: {
            Image(systemName: viewModel.activeCount > 0
                ? "wrench.and.screwdriver.fill"
                : "wrench.and.screwdriver")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(viewModel.activeCount > 0 ? Color.orange : Color.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    viewModel.activeCount > 0
                        ? Color.orange.opacity(0.18)
                        : Color.secondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.selectedConversationID == nil)
        .help(Text(LumiPluginLocalization.string("View tool calls for this conversation")))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ToolActivityPopoverView(viewModel: viewModel)
                .frame(width: 380, height: 430)
        }
        .onAppear { viewModel.refresh() }
        .onChange(of: viewModel.selectedConversationID) { _, newValue in
            if newValue == nil {
                isPresented = false
            }
        }
    }
}

private struct ToolActivityPopoverView: View {
    @ObservedObject var viewModel: ToolActivityViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(LumiPluginLocalization.string("Tool Calls"))
                        .font(.headline)
                    Spacer()
                    Text("\(viewModel.activeJobs.count + viewModel.completedJobs.count)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline.monospacedDigit())
                }

                if viewModel.selectedConversationID == nil {
                    emptyState
                } else if viewModel.activeJobs.isEmpty && viewModel.completedJobs.isEmpty {
                    emptyState
                } else {
                    if !viewModel.activeJobs.isEmpty {
                        ToolActivitySection(title: LumiPluginLocalization.string("In progress")) {
                            ForEach(viewModel.activeJobs) { job in
                                ToolActivityRow(job: job, viewModel: viewModel)
                            }
                        }
                    }

                    if !viewModel.completedJobs.isEmpty {
                        ToolActivitySection(title: LumiPluginLocalization.string("Completed"), secondary: true) {
                            ForEach(viewModel.completedJobs) { job in
                                ToolActivityRow(job: job, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(.background)
    }

    private var emptyState: some View {
        Text(LumiPluginLocalization.string("No tool calls in this conversation"))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 180)
    }
}

private struct ToolActivitySection<Content: View>: View {
    let title: String
    let secondary: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        secondary: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.secondary = secondary
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondary ? .secondary : Color.accentColor)
                .textCase(.uppercase)
            VStack(spacing: 1) {
                content
            }
        }
    }
}

private struct ToolActivityRow: View {
    let job: ToolJob
    @ObservedObject var viewModel: ToolActivityViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            statusIcon
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.displayName(for: job))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Text(viewModel.statusTitle(for: job.status))
                    if let duration = duration {
                        Text("·")
                        Text(formatDuration(duration))
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
                .foregroundStyle(color)
        }
    }

    private var iconName: String {
        switch job.status {
        case .waitingForUser: return "hand.raised.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed, .timedOut: return "exclamationmark.triangle.fill"
        case .cancelled, .cancelling: return "xmark.circle.fill"
        case .queued, .running: return "circle"
        }
    }

    private var color: Color {
        switch job.status {
        case .waitingForUser: return .orange
        case .completed: return .green
        case .failed, .timedOut: return .red
        case .cancelled, .cancelling: return .secondary
        case .queued, .running: return .accentColor
        }
    }

    private var duration: TimeInterval? {
        guard let startedAt = job.startedAt else { return nil }
        return (job.completedAt ?? Date()).timeIntervalSince(startedAt)
    }

    private func formatDuration(_ value: TimeInterval) -> String {
        if value < 1 { return "<1s" }
        if value < 60 { return String(format: "%.1fs", value) }
        return String(format: "%.1fm", value / 60)
    }
}
