import LumiUI
import ProviderProjectRAG
import SwiftUI

/// 项目详情中的 RAG 索引状态。
///
/// Provider 在视图加载时通过 Kernel 动态解析，避免 ProjectsPlugin 依赖
/// ProjectRAGPlugin 的启动顺序或具体实现。
@MainActor
struct ProjectRAGStatusSection: View {
    let projectPath: String
    let providerResolver: @MainActor () -> (any ProjectRAGProviding)?

    @LumiTheme private var theme
    @State private var state: LoadState = .loading

    enum LoadState {
        case loading
        case unavailable
        case notIndexed
        case indexed(ProjectRAGIndexStatus)
        case failed
    }

    var body: some View {
        AppSettingsSection(title: "RAG Index") {
            VStack(alignment: .leading, spacing: 10) {
                switch state {
                case .loading:
                    statusRow(icon: "hourglass", title: "Checking index status…", color: theme.textSecondary)
                case .unavailable:
                    statusRow(icon: "minus.circle", title: "RAG unavailable", color: theme.textSecondary)
                case .notIndexed:
                    statusRow(icon: "circle.dashed", title: "Not indexed", color: .orange)
                case .indexed(let status):
                    indexedContent(status)
                case .failed:
                    statusRow(icon: "exclamationmark.triangle", title: "Unable to read index status", color: .orange)
                }

                if !isLoading {
                    HStack {
                        Spacer()
                        Button("Refresh") {
                            Task { await loadStatus() }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .task(id: projectPath) {
            await loadStatus()
        }
    }

    private var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    @ViewBuilder
    private func indexedContent(_ status: ProjectRAGIndexStatus) -> some View {
        statusRow(
            icon: status.isStale ? "clock.badge.exclamationmark" : "checkmark.circle.fill",
            title: status.isStale ? "Index is stale" : "Indexed",
            color: status.isStale ? .orange : .green
        )

        VStack(spacing: 0) {
            detailRow(title: "Files", value: "\(status.fileCount)")
            Divider().padding(.vertical, 7)
            detailRow(title: "Chunks", value: "\(status.chunkCount)")
            Divider().padding(.vertical, 7)
            detailRow(title: "Last Indexed", value: status.lastIndexedAt.formatted(date: .abbreviated, time: .shortened))
        }
    }

    private func statusRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(theme.textPrimary)
            Spacer()
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.callout)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.callout)
                .foregroundStyle(theme.textPrimary)
        }
    }

    private func loadStatus() async {
        state = .loading
        guard let provider = providerResolver() else {
            state = .unavailable
            return
        }

        do {
            state = try await provider.indexStatus(projectPath: projectPath).map(LoadState.indexed) ?? .notIndexed
        } catch {
            state = .failed
        }
    }
}
