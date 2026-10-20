import LumiUI
import SwiftUI

/// MiniMax Token Plan 详情面板：按模型分组展示 5 小时窗口与本周配额的剩余量。
///
/// 面板只负责外壳（标题 / 刷新 / 滚动 / 更新时间），内容排版交给
/// ``TokenPlanQuotaList``，卡片本身交给 ``TokenPlanQuotaCard``。
struct TokenPlanDetailView: View {
    @LumiTheme private var theme: any LumiUITheme

    let status: TokenPlanStatus
    let onRefresh: () -> Void
    /// 最近一次刷新的时间；用于在底部标注数据新鲜度。
    let lastUpdatedAt: Date?

    // MARK: - View

    var body: some View {
        StatusBarPopoverScaffold(
            title: pluginLocalization.string("MiniMax Token Plan"),
            systemImage: "chart.bar.fill",
            subtitle: nil,
            showsHeaderDivider: true,
            headerAccessory: {
                AppIconButton(systemImage: "arrow.clockwise") {
                    onRefresh()
                }
                .help(pluginLocalization.string("Refresh"))
            },
            content: {
                content
            },
            footer: {
                footer
            }
        )
        .padding(14)
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .loading:
            loadingState
        case .success(let plans):
            quotaList(plans)
        case .authError:
            messageState(
                systemImage: "exclamationmark.triangle.fill",
                text: pluginLocalization.string("Authentication failed; please check your API Key"),
                color: theme.error
            )
        case .unavailable:
            messageState(
                systemImage: "xmark.octagon.fill",
                text: pluginLocalization.string("Unable to fetch quota info"),
                color: theme.warning
            )
        }
    }

    // MARK: - States

    private var loadingState: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(pluginLocalization.string("Loading..."))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func messageState(systemImage: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(color)
            Text(text)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    /// 底部时间戳：标注这份配额是何时拉到的。
    @ViewBuilder
    private var footer: some View {
        if let lastUpdatedAt {
            Text(
                String(
                    format: pluginLocalization.string("Updated at %@"),
                    TokenPlanData.formatTimestamp(Int64(lastUpdatedAt.timeIntervalSince1970 * 1000))
                )
            )
        }
    }

    // MARK: - Quota List

    /// 配额列表：内容超出时在面板内滚动。
    private func quotaList(_ plans: [TokenPlanData]) -> some View {
        ScrollView {
            TokenPlanQuotaList(plans: plans)
                .padding(.top, 2)
        }
        .frame(maxHeight: 440)
    }
}

// MARK: - Preview

#if DEBUG
#if os(macOS)
#Preview("Detail - Success") {
    TokenPlanDetailView(
        status: .success(TokenPlanPreviewFixtures.allPlans),
        onRefresh: {},
        lastUpdatedAt: Date()
    )
    .inRootView()
    .frame(width: 600, height: 1000)
}

#Preview("Detail - Success Compact") {
    TokenPlanDetailView(
        status: .success(TokenPlanPreviewFixtures.allPlans),
        onRefresh: {},
        lastUpdatedAt: Date()
    )
    .inRootView()
    .frame(width: 600, height: 600)
}

#Preview("Detail - Auth Error") {
    TokenPlanDetailView(status: .authError, onRefresh: {}, lastUpdatedAt: nil)
        .inRootView()
        .frame(width: 600, height: 1000)
}
#endif
#endif
