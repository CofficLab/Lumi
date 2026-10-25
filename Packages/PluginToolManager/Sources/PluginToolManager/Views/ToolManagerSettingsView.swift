import LumiUI
import SwiftUI

/// 工具设置页：与「外观」页一致的主从（左侧列表 + 右侧详情）贴边布局。
///
/// 头部行右侧放模式分段控件（工具 / 执行日志 / 调用统计）——与「外观」页
/// 头部行右侧放外观筛选控件是同一个位置。切换模式时左侧列表与右侧详情
/// 一起更换，三块内容都保持「列表 + 详情」的形态。
///
/// 布局基准见 `.lumi/rules/settings-ui.md`：列表栏 300、详情栏内容内边距 22、
/// 主体贴边（无外框描边 / 圆角 / 底部留白）、主从容器不写死 `minHeight`。
struct ToolManagerSettingsView: View {
    @ObservedObject var viewModel: ToolManagerViewModel
    @LumiTheme private var theme

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                    // 主体内容贴边后，用一条顶部分隔线把标题行与主从容器分开。
                    AppDivider()
                    masterDetail
                }
                // 共享 scaffold 给内容留了左右 24，这里把整列加宽 48 并左移 24，
                // 使主从容器正好贴到窗口左右边缘；标题行再自行补回 24 留白。
                .frame(width: proxy.size.width + 48, alignment: .topLeading)
                .offset(x: -24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .task {
            await loadContent(for: viewModel.selectedMode)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Label(headerTitle, systemImage: headerIcon)
            if let current = currentItemName {
                Text(String(format: L("Current: %@"), current))
                    .lineLimit(1)
            }
            Spacer()
            refreshButton
            modeSwitcher
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    /// 头部标题随模式变化：分别是工具数、已加载记录数与总调用数。
    private var headerTitle: String {
        switch viewModel.selectedMode {
        case .tools:
            return String(format: L("%lld tools"), viewModel.totalToolCount)
        case .executionLog:
            return String(format: L("%lld records loaded"), viewModel.records.count)
        case .toolStats:
            return String(format: L("%lld total calls"), viewModel.totalCallCount)
        }
    }

    private var headerIcon: String {
        switch viewModel.selectedMode {
        case .tools: "wrench.and.screwdriver"
        case .executionLog: "list.bullet.rectangle.portrait"
        case .toolStats: "chart.bar.xaxis"
        }
    }

    /// 头部右侧显示当前选中的条目名，与「外观」页的「Current: …」同义。
    private var currentItemName: String? {
        switch viewModel.selectedMode {
        case .tools:
            return viewModel.selectedTool?.tool.name
        case .executionLog:
            guard let record = viewModel.selectedRecord else { return nil }
            return record.toolDisplayName.isEmpty ? record.toolName : record.toolDisplayName
        case .toolStats:
            return viewModel.selectedStat?.toolName
        }
    }

    /// 刷新当前模式的数据。
    private var refreshButton: some View {
        AppButton("", systemImage: "arrow.clockwise", size: .small) {
            viewModel.refreshCurrentModeRequested()
        }
        .help(L("Refresh"))
    }

    /// 模式分段控件：与「外观」页的外观筛选控件同一个位置（头部行右侧）。
    private var modeSwitcher: some View {
        AppSegmentedControl(
            ToolManagerViewModel.Mode.allCases.map { modeTitle($0) },
            selection: Binding(
                get: { ToolManagerViewModel.Mode.allCases.firstIndex(of: viewModel.selectedMode) ?? 0 },
                set: { viewModel.selectMode(ToolManagerViewModel.Mode.allCases[$0]) }
            ),
            maxWidth: .infinity
        )
        .frame(width: 260, height: 27)
    }

    private func modeTitle(_ mode: ToolManagerViewModel.Mode) -> String {
        switch mode {
        case .tools: L("Tools")
        case .executionLog: L("Execution Log")
        case .toolStats: L("Usage Statistics")
        }
    }

    // MARK: - Master–Detail

    /// 主从容器整体贴边：不再有外框描边与圆角裁剪，
    /// 只保留列表栏与详情栏之间的竖向分隔线。
    @ViewBuilder
    private var masterDetail: some View {
        if viewModel.selectedMode.requiresLogStore, !viewModel.hasLogStore {
            unavailableState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 0) {
                listPane
                    .frame(width: 300)
                    .frame(maxHeight: .infinity)
                AppDivider(.vertical)
                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Panes

    @ViewBuilder
    private var listPane: some View {
        switch viewModel.selectedMode {
        case .tools:
            ToolManagerToolListView(viewModel: viewModel)
        case .executionLog:
            ToolCallLogListView(viewModel: viewModel)
        case .toolStats:
            ToolCallStatsListView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        switch viewModel.selectedMode {
        case .tools:
            ToolManagerToolDetailView(viewModel: viewModel)
        case .executionLog:
            ToolCallRecordDetailView(viewModel: viewModel)
        case .toolStats:
            ToolCallStatDetailView(viewModel: viewModel)
        }
    }

    /// 未配置调用记录存储时的空状态（日志 / 统计模式不可用）。
    private var unavailableState: some View {
        AppEmptyState(
            icon: viewModel.selectedMode == .executionLog
                ? "list.bullet.rectangle.portrait"
                : "chart.bar.xaxis",
            title: viewModel.selectedMode == .executionLog
                ? L("Execution Log unavailable")
                : L("Usage Statistics unavailable"),
            description: viewModel.selectedMode == .executionLog
                ? L("Lumi storage is not configured, so tool call records cannot be persisted.")
                : L("Lumi storage is not configured.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    private func loadContent(for mode: ToolManagerViewModel.Mode) async {
        switch mode {
        case .tools:
            await viewModel.reloadTools()
        case .executionLog:
            await viewModel.refreshLog()
        case .toolStats:
            await viewModel.reloadStats()
        }
    }
}
