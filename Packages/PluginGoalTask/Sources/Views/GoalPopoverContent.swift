import KitLocalization
import LumiUI
import SwiftUI

/// 工具栏弹窗内容:列表所有 Goal 及其任务(可展开)。
///
/// 渲染由 `GoalToolbarButton` 提供 viewModel 与主题,
/// 内部按 loading / empty / hasItems 三态分发:
/// - loading + 空数据:全屏 ProgressView
/// - empty:全屏占位图标 + 提示文案
/// - 有数据:ScrollView + `GoalRowView`
struct GoalPopoverContent: View {
    @LumiTheme private var theme
    @ObservedObject var viewModel: GoalVM

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            content
        }
        .background(theme.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label(LumiPluginLocalization.string("Goals", bundle: .module), systemImage: "target")
                .font(.headline)

            Spacer()

            if !viewModel.goals.isEmpty {
                Text("\(viewModel.goals.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.goals.isEmpty {
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if viewModel.goals.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.goals) { item in
                        GoalRowView(item: item)
                    }
                }
                .padding(12)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "target")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(LumiPluginLocalization.string("No goals yet", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}