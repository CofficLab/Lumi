import LumiUI
import SwiftUI

/// 单个工具的调用统计详情（主从布局的右栏）。
struct ToolCallStatDetailView: View {
    @ObservedObject var viewModel: ToolManagerViewModel
    @LumiTheme private var theme

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        Group {
            if let stat = viewModel.selectedStat {
                detail(stat)
            } else {
                AppEmptyState(
                    icon: "chart.bar.xaxis",
                    title: L("Select a statistic"),
                    description: L("Choose a tool from the list to inspect its usage statistics.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Detail

    private func detail(_ stat: ToolStatEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(stat)
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 12)
            AppDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AppSettingSection(title: L("Usage"), titleAlignment: .leading) {
                        VStack(spacing: 0) {
                            AppSettingRow(title: L("Total Calls"), icon: "number") {
                                Text(String(format: L("%lld calls"), stat.totalCount))
                                    .font(.appCaption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Divider()
                                .padding(.vertical, 8)
                            AppSettingRow(title: L("Errors"), icon: "exclamationmark.triangle") {
                                Text(String(format: L("%lld errors"), stat.errorCount))
                                    .font(.appCaption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Divider()
                                .padding(.vertical, 8)
                            AppSettingRow(title: L("Error Rate"), icon: "percent") {
                                Text(String(format: "%.1f%%", stat.errorRate))
                                    .font(.appCaption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Divider()
                                .padding(.vertical, 8)
                            AppSettingRow(title: L("Average Duration"), icon: "clock") {
                                Text(String(format: L("avg %.2fs"), stat.averageDuration))
                                    .font(.appCaption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surface)
    }

    // MARK: - Header

    private func header(_ stat: ToolStatEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.appTitle)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    theme.textSecondary.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.toolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(String(format: L("%lld calls"), stat.totalCount))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
