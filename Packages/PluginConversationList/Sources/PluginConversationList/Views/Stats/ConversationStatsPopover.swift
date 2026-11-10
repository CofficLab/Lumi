import LumiUI
import ProviderConversation
import SwiftUI

/// 对话条数徽标弹出的统计面板。
///
/// 内容：
/// - 顶部一行概览（区间内对话总数、单日峰值）；
/// - 每日对话数量折线图；
/// - 两个批量清理入口：「删除 7 天前的对话」「删除 30 天前的对话」。
///
/// View 只依赖 `ConversationStatsViewModel`，不直接访问存储层。
struct ConversationStatsPopover: View {
    @LumiTheme private var theme: any LumiUITheme

    /// 统计面板的数据源与交互入口。
    ///
    /// 由本视图自己持有（`@StateObject`），而不是从父视图传入：
    /// Popover 的内容闭包会在每次父视图重绘时被重新求值，
    /// 若把 ViewModel 写在闭包里创建，就会被反复重建，
    /// 导致统计每次重绘都重新加载、清理中的状态也会丢失。
    @StateObject private var viewModel: ConversationStatsViewModel

    /// 待确认的清理窗口。
    @State private var pendingCleanup: ConversationStatsViewModel.RetentionWindow?
    /// 清理结果提示文案。
    @State private var resultMessage: String?

    init(capability: any ConversationStatsCapability, projectPath: String?) {
        _viewModel = StateObject(
            wrappedValue: ConversationStatsViewModel(capability: capability, projectPath: projectPath)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            AppDivider()

            chartSection

            AppDivider()

            cleanupSection
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
        .task {
            await viewModel.loadSeriesIfNeeded()
        }
        .alert(
            L("Delete conversations older than %lld days", pendingCleanup?.dayCount ?? 0),
            isPresented: cleanupConfirmationBinding,
            presenting: pendingCleanup
        ) { window in
            Button(role: .destructive, action: {
                Task { await performCleanup(window) }
            }) {
                Text(L("Delete"))
            }
            Button(role: .cancel) {
                pendingCleanup = nil
            } label: {
                Text(L("Cancel"))
            }
        } message: { window in
            Text(L("Conversations older than %lld days will be permanently deleted. This cannot be undone.", window.dayCount))
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("Conversation statistics"))
                .font(.appBodyEmphasized)
                .foregroundStyle(theme.textPrimary)

            HStack(spacing: 10) {
                metric(
                    title: L("Last %lld days", ConversationStatsViewModel.chartDays),
                    value: viewModel.totalInRange
                )
                metric(title: L("Daily peak"), value: viewModel.peakCount)
            }
        }
    }

    private func metric(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)
            Text(value.formatted(.number.grouping(.automatic)))
                .font(.appCaptionEmphasized)
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartSection: some View {
        if viewModel.isLoading && viewModel.dailyCountSeries.points.isEmpty {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            ConversationStatsChart(series: viewModel.dailyCountSeries)
                .frame(height: 120)
        }
    }

    // MARK: - Cleanup

    private var cleanupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Clean up old conversations"))
                .font(.appMicroEmphasized)
                .foregroundStyle(theme.textSecondary)

            ForEach(ConversationStatsViewModel.RetentionWindow.allCases) { window in
                HStack(spacing: 8) {
                    AppButton(
                        L("Delete conversations older than %lld days", window.dayCount),
                        systemImage: "trash",
                        style: .secondary,
                        size: .small,
                        fillsWidth: true
                    ) {
                        pendingCleanup = window
                    }
                    .disabled(viewModel.isCleaning)

                    // 破坏性操作前先告知会删掉多少条。
                    if let count = viewModel.deletableCounts[window.dayCount] {
                        Text(L("%lld conversations", count))
                            .font(.appMicro)
                            .monospacedDigit()
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }

            if viewModel.isCleaning {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L("Cleaning…"))
                        .font(.appMicro)
                        .foregroundStyle(theme.textTertiary)
                }
            }

            if let resultMessage {
                Text(resultMessage)
                    .font(.appMicro)
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    // MARK: - Actions

    /// 确认对话框的显示状态由 `pendingCleanup` 驱动。
    private var cleanupConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingCleanup != nil },
            set: { isPresented in
                if !isPresented { pendingCleanup = nil }
            }
        )
    }

    private func performCleanup(_ window: ConversationStatsViewModel.RetentionWindow) async {
        pendingCleanup = nil
        let deleted = await viewModel.cleanUp(olderThan: window)
        resultMessage = deleted == 0
            ? L("No conversations to clean up")
            : L("Cleaned up %lld conversations", deleted)
    }

    // MARK: - 文案

    /// 本地化文案。
    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    /// 带一个整型占位符的本地化文案。
    private func L(_ key: String, _ argument: Int) -> String {
        String(format: pluginLocalization.string(key), argument)
    }
}
