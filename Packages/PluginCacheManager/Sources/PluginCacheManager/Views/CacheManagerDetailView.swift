import LumiUI
import ProviderDiskCache
import SwiftUI

/// 缓存管理详情视图 —— 设置窗口「缓存」标签页。
///
/// 总占用卡片（刷新 / 清空全部）+ 按插件分桶明细（单桶清空）。
/// 业务状态全部由 `CacheManagerViewModel` 提供。
struct CacheManagerDetailView: View {
    @ObservedObject var viewModel: CacheManagerViewModel
    @State private var isConfirmingClearAll = false

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                overviewSection
                bucketsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            viewModel.refresh()
        }
        .confirmationDialog(
            pluginLocalization.string("Clear All Cache"),
            isPresented: $isConfirmingClearAll,
            titleVisibility: .visible
        ) {
            Button(pluginLocalization.string("Clear All Cache"), role: .destructive) {
                viewModel.clearAll()
            }
        } message: {
            Text(pluginLocalization.string("Disk cache is disposable acceleration data. Clearing it will not delete any of your projects or documents; content will be re-fetched or rebuilt when needed."))
        }
    }

    // MARK: - 总览

    private var overviewSection: some View {
        AppSettingSection(
            title: pluginLocalization.string("Disk Cache"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: pluginLocalization.string("Total Usage"),
                    description: viewModel.totalDescription,
                    icon: "shippingbox"
                ) {
                    HStack(spacing: 8) {
                        AppButton(
                            viewModel.isLoading
                                ? pluginLocalization.string("Refreshing…")
                                : pluginLocalization.string("Refresh"),
                            systemImage: viewModel.isLoading ? "hourglass" : "arrow.clockwise",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.refresh()
                        }
                        .disabled(viewModel.isLoading || viewModel.isClearing)

                        AppButton(
                            pluginLocalization.string("Clear All Cache"),
                            systemImage: "trash",
                            style: .destructive,
                            size: .small
                        ) {
                            isConfirmingClearAll = true
                        }
                        .disabled(viewModel.isLoading || viewModel.isClearing || viewModel.report.totalBytes == 0)
                    }
                }

                if let feedback = viewModel.feedback {
                    Divider()
                        .padding(.vertical, 8)
                    Text(feedback)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - 按插件明细

    private var bucketsSection: some View {
        AppSettingSection(
            title: pluginLocalization.string("By Plugin"),
            titleAlignment: .leading
        ) {
            if viewModel.report.buckets.isEmpty {
                Text(pluginLocalization.string("No disk cache yet. Plugins will populate it as they download images and files."))
                    .font(.appBody)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.report.buckets.enumerated()), id: \.element.id) { index, usage in
                        AppSettingRow(
                            title: usage.pluginID,
                            description: viewModel.description(for: usage),
                            icon: "puzzlepiece.extension"
                        ) {
                            AppButton(
                                pluginLocalization.string("Clear"),
                                systemImage: "trash",
                                style: .secondary,
                                size: .small
                            ) {
                                viewModel.clearBucket(pluginID: usage.pluginID)
                            }
                            .disabled(viewModel.isLoading || viewModel.isClearing)
                        }

                        if index < viewModel.report.buckets.count - 1 {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }
}