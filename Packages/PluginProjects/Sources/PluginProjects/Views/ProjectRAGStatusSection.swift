import LumiUI
import ProviderProjectRAG
import SwiftUI

/// 项目详情中的 RAG 索引状态。
///
/// 只依赖 `ProjectRAGStatusViewModel`；Provider 解析与状态加载由
/// ViewModel/Observer 承担，View 不再直接接触 Provider。
@MainActor
struct ProjectRAGStatusSection: View {
    let projectPath: String
    @ObservedObject private var viewModel: ProjectRAGStatusViewModel

    @LumiTheme private var theme

    init(projectPath: String, viewModel: ProjectRAGStatusViewModel) {
        self.projectPath = projectPath
        self.viewModel = viewModel
    }

    var body: some View {
        AppSettingSection(
                        title: pluginLocalization.string("RAG Index"),
                        titleAlignment: .leading
                    ) {
            VStack(alignment: .leading, spacing: 10) {
                switch viewModel.state {
                case .loading:
                    statusRow(icon: "hourglass", title: pluginLocalization.string("Checking index status…"), color: theme.textSecondary)
                case .unavailable:
                    statusRow(icon: "minus.circle", title: pluginLocalization.string("RAG unavailable"), color: theme.textSecondary)
                case .notIndexed:
                    statusRow(icon: "circle.dashed", title: pluginLocalization.string("Not indexed"), color: .orange)
                case .indexed(let status):
                    indexedContent(status)
                case .failed:
                    statusRow(icon: "exclamationmark.triangle", title: pluginLocalization.string("Unable to read index status"), color: .orange)
                }

                if !viewModel.isLoading {
                    HStack {
                        Spacer()
                        Button(pluginLocalization.string("Refresh")) {
                            Task { await viewModel.loadStatus() }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .task(id: projectPath) {
            await viewModel.loadStatus()
        }
    }

    @ViewBuilder
    private func indexedContent(_ status: ProjectRAGIndexStatus) -> some View {
        statusRow(
            icon: status.isStale ? "clock.badge.exclamationmark" : "checkmark.circle.fill",
            title: status.isStale ? pluginLocalization.string("Index is stale") : pluginLocalization.string("Indexed"),
            color: status.isStale ? .orange : .green
        )

        VStack(spacing: 0) {
            detailRow(title: pluginLocalization.string("Files"), value: "\(status.fileCount)")
            Divider().padding(.vertical, 7)
            detailRow(title: pluginLocalization.string("Chunks"), value: "\(status.chunkCount)")
            Divider().padding(.vertical, 7)
            detailRow(title: pluginLocalization.string("Last Indexed"), value: status.lastIndexedAt.formatted(date: .abbreviated, time: .shortened))
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

}
