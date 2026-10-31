import LumiUI
import ProviderToolManager
import SwiftUI

/// 工具调用执行日志：左侧为分页列表（主从布局的左栏）。
///
/// 只依赖 `ToolManagerViewModel`；记录、分页、选中与刷新状态全部由 ViewModel 提供。
struct ToolCallLogListView: View {
    @ObservedObject var viewModel: ToolManagerViewModel
    @LumiTheme private var theme

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingLog && viewModel.records.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L("Loading..."))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.records.isEmpty {
                AppEmptyState(
                    icon: "list.bullet.rectangle.portrait",
                    title: L("No tool calls recorded"),
                    description: L("Tool executions will appear here once recorded.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.records) { record in
                            recordRow(record)
                                .onAppear {
                                    if record.id == viewModel.records.last?.id {
                                        Task { await viewModel.loadMoreLog() }
                                    }
                                }
                        }

                        if viewModel.hasMoreLog {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    // MARK: - Rows

    private func recordRow(_ record: ToolCallRecord) -> some View {
        let isSelected = viewModel.selectedRecordID == record.id
        return AppListRow(isSelected: isSelected, action: {
            viewModel.selectRecord(id: record.id)
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: record.resultIsError ? "exclamationmark.triangle" : "checkmark.circle")
                        .font(.appCaption)
                        .foregroundStyle(record.resultIsError ? theme.error : theme.success)
                    Text(record.toolDisplayName.isEmpty ? record.toolName : record.toolDisplayName)
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                }

                Text(record.resultContent.isEmpty ? record.toolName : record.resultContent)
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
    }
}
